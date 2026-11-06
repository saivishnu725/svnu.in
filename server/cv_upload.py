#!/usr/bin/env python3
"""cv_upload.py — handles POST /cv/upload for svnu.in

takes a pdf + password from cv/upload.html. if the password matches,
the current cv/resume.pdf is kept as cv/resume_YYYY-MM-DD_HH-MM-SS.pdf
and the upload becomes the new cv/resume.pdf.

stdlib only. listens on 127.0.0.1, nginx proxies /cv/upload to it.

  set / change the password:  ./cv_upload.py --set-password
  run the server:             ./cv_upload.py   (normally via systemd)

env overrides: CV_DIR, CV_HASH_FILE, CV_HOST, CV_PORT
"""

import email.parser
import email.policy
import getpass
import hashlib
import hmac
import html
import os
import secrets
import sys
import time
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer

CV_DIR = os.environ.get("CV_DIR", "/root/nginx/html/cv")
HASH_FILE = os.environ.get("CV_HASH_FILE", "/etc/svnu-cv/password")
HOST = os.environ.get("CV_HOST", "127.0.0.1")
PORT = int(os.environ.get("CV_PORT", "8725"))

MAX_PDF = 10 * 1024 * 1024        # 10 MB is plenty for a resume
MAX_BODY = MAX_PDF + 64 * 1024    # pdf + form overhead
MAX_FAILS = 5                     # wrong passwords allowed...
FAIL_WINDOW = 15 * 60             # ...per ip in this many seconds

fails = {}  # ip -> [timestamps of wrong passwords]


# ── password ─────────────────────────────────────────────────────────────────

def _scrypt(pw, salt):
    return hashlib.scrypt(pw.encode(), salt=salt, n=2**14, r=8, p=1)


def set_password():
    pw = getpass.getpass("new password: ")
    if len(pw) < 10:
        sys.exit("use at least 10 characters")
    if pw != getpass.getpass("again: "):
        sys.exit("passwords don't match")
    salt = secrets.token_bytes(16)
    os.makedirs(os.path.dirname(HASH_FILE), mode=0o700, exist_ok=True)
    fd = os.open(HASH_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(f"{salt.hex()}:{_scrypt(pw, salt).hex()}\n")
    print(f"saved to {HASH_FILE}")


def password_ok(pw):
    # read on every request so a new password works without a restart
    try:
        salt_hex, hash_hex = open(HASH_FILE).read().strip().split(":")
    except (OSError, ValueError):
        return False
    return hmac.compare_digest(_scrypt(pw, bytes.fromhex(salt_hex)),
                               bytes.fromhex(hash_hex))


def too_many_fails(ip):
    now = time.time()
    fails[ip] = [t for t in fails.get(ip, []) if now - t < FAIL_WINDOW]
    return len(fails[ip]) >= MAX_FAILS


# ── saving ───────────────────────────────────────────────────────────────────

def save_resume(data):
    current = os.path.join(CV_DIR, "resume.pdf")
    tmp = os.path.join(CV_DIR, ".resume.pdf.upload")

    with open(tmp, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.chmod(tmp, 0o644)

    try:
        old_name = None
        if os.path.exists(current):
            stamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
            old_name = f"resume_{stamp}.pdf"
            n = 1
            while os.path.exists(os.path.join(CV_DIR, old_name)):
                old_name = f"resume_{stamp}_{n}.pdf"
                n += 1
            # hard link first, then swap. resume.pdf never goes missing.
            os.link(current, os.path.join(CV_DIR, old_name))
        os.replace(tmp, current)
        return old_name
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)


# ── http ─────────────────────────────────────────────────────────────────────

PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>cv upload | svnu.in</title>
  <style>
    :root {{ --bg: #0c0c0c; --fg: #eaeaea; --dim: #6b7280; --accent: #22d3ee; --err: #f87171; }}
    body {{
      background: var(--bg); color: var(--fg);
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 14px; line-height: 1.5;
      max-width: 720px; margin: 48px auto; padding: 0 16px;
    }}
    .prompt {{ color: var(--accent); }}
    .out {{ color: var(--dim); margin: 0.3em 0 1.3em 0; }}
    .err {{ color: var(--err); }}
    a {{ color: var(--accent); text-decoration: none; }}
    a:hover {{ text-decoration: underline; }}
  </style>
</head>
<body>
<span class="prompt">sai@svnu.in</span>:<span>~/cv$ ./upload resume.pdf</span>
<div class="out">{msg}</div>
<span class="prompt">sai@svnu.in</span>:<span>~/cv$</span> <a href="{back}">{back_text}</a>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    server_version = "svnu-cv"
    sys_version = ""

    def client_ip(self):
        # only nginx talks to us, so X-Real-IP can be trusted
        return self.headers.get("X-Real-IP") or self.client_address[0]

    def reply(self, code, msg, ok=False):
        if ok:
            back, back_text = "/cv/resume.pdf", "cat resume.pdf"
        else:
            back, back_text = "/cv/upload.html", "try again"
            msg = f'<span class="err">{msg}</span>'
        body = PAGE.format(msg=msg, back=back, back_text=back_text).encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.send_response(303)
        self.send_header("Location", "/cv/upload.html")
        self.end_headers()

    def do_POST(self):
        ip = self.client_ip()

        if too_many_fails(ip):
            return self.reply(429, "too many wrong passwords. wait 15 minutes.")

        try:
            length = int(self.headers.get("Content-Length", 0))
        except ValueError:
            length = 0
        if length <= 0:
            return self.reply(400, "empty request.")
        if length > MAX_BODY:
            return self.reply(413, "file too big (10 MB max).")

        ctype = self.headers.get("Content-Type", "")
        if not ctype.startswith("multipart/form-data"):
            return self.reply(400, "expected a form upload.")

        raw = self.rfile.read(length)
        msg = email.parser.BytesParser(policy=email.policy.HTTP).parsebytes(
            b"Content-Type: " + ctype.encode() + b"\r\n\r\n" + raw)

        fields = {}
        if msg.is_multipart():
            for part in msg.iter_parts():
                name = part.get_param("name", header="content-disposition")
                if name:
                    fields[name] = part.get_payload(decode=True) or b""

        password = fields.get("password", b"").decode("utf-8", "replace")
        if not password_ok(password):
            fails.setdefault(ip, []).append(time.time())
            self.log_message("wrong password")
            return self.reply(403, "wrong password.")

        data = fields.get("resume", b"")
        if not data.startswith(b"%PDF-"):
            return self.reply(400, "that's not a pdf.")
        if len(data) > MAX_PDF:
            return self.reply(413, "file too big (10 MB max).")

        try:
            old = save_resume(data)
        except OSError as e:
            self.log_message("save failed: %s", e)
            return self.reply(500, "couldn't save the file. check the logs.")

        self.log_message("new resume.pdf (%d bytes), old one -> %s",
                         len(data), old)
        kept = f"old one kept as {html.escape(old)}" if old else "no previous version"
        self.reply(200, f"resume.pdf updated ({len(data) // 1024} KB).<br>{kept}",
                   ok=True)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"{self.client_ip()} {fmt % args}\n")


def main():
    if "--set-password" in sys.argv:
        return set_password()
    if not os.path.isfile(HASH_FILE):
        sys.exit(f"no password set. run: {sys.argv[0]} --set-password")
    print(f"listening on {HOST}:{PORT}, saving to {CV_DIR}", flush=True)
    HTTPServer((HOST, PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
