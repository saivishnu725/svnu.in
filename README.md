# svnu.in

Source for my personal website: **svnu.in**

This is a deliberately minimal, static site built with plain HTML, CSS, and shell scripts.
No frameworks, no JavaScript, no trackers — just text and files.

---

## Structure

```

.
├── index.html              # homepage
├── status.html             # status page
├── blogs/
│   ├── index.html          # auto-generated
│   └── 2026/
│       └── 01/
│           └── sample_blog.html
├── notes/
│   ├── index.html          # auto-generated
│   └── sample_note.html
├── generate_indexes.sh     # builds the blog/notes indexes
├── md_to_html.sh           # converts .md posts to .html (run locally)
├── pull_and_index.sh       # cron job on the server: git pull + indexes
├── cv/
│   ├── resume.pdf          # server only, not in git
│   └── upload.html         # form to replace resume.pdf
└── server/
    ├── cv_upload.py        # handles the cv upload form
    └── svnu-cv-upload.service

```

---

## Blogs vs Notes

- **Blogs**
  - Longer, more polished writing
  - Dated
  - Structured by year/month

- **Notes**
  - Scratchpad-style
  - Cheatsheets, reminders, half-formed ideas
  - Updated freely without worrying about polish

Both are plain HTML files.

---

## Auto-generated indexes

The following pages are generated automatically:

- `/blogs/index.html`
- `/notes/index.html`

They are created by:

```

generate_indexes.sh

````

The script:
- Scans blog and note files
- Extracts `<title>` tags
- Strips redundant suffixes like `| svnu.in`
- Generates clean index pages with links

---

## Deployment

The site is served by nginx from a Proxmox LXC container on my home server.
The repo is cloned at `/root/nginx/html`.

`pull_and_index.sh` keeps it up to date. Every run it:
- does a `git pull --ff-only`
- reruns `generate_indexes.sh` if the pull brought anything new (or an index is missing)
- skips the run if the previous one is still going (`flock`)

So publishing is just: write the post, run `md_to_html.sh` locally, commit, push.
The server picks it up within 5 minutes.

Current cron entry (root's crontab inside the container):

```cron
*/5 * * * * /root/nginx/html/pull_and_index.sh >> /var/log/svnu-pull.log 2>&1
```

It only logs when something changed, so `/var/log/svnu-pull.log` stays small.

---

## CV upload

`/cv/upload.html` takes a pdf and a password. If the password is right,
the current `cv/resume.pdf` is kept as `cv/resume_YYYY-MM-DD_HH-MM-SS.pdf`
and the upload becomes the new `resume.pdf`. All pdfs in `cv/` are ignored by git.

nginx can't handle uploads on its own, so `server/cv_upload.py` (python stdlib,
no packages) listens on `127.0.0.1:8725` and nginx forwards `/cv/upload` to it.

- password is stored as a salted scrypt hash in `/etc/svnu-cv/password`, outside the web root
- 5 wrong passwords from one IP locks it out for 15 minutes
- only accepts real pdfs, 10 MB max
- the systemd unit can only write to `cv/`

One-time setup inside the container:

```bash
cd /root/nginx/html
python3 server/cv_upload.py --set-password
cp server/svnu-cv-upload.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now svnu-cv-upload
```

nginx config:

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # svnu.in/cv and svnu.in/cv/ open the resume
    location = /cv  { try_files /cv/resume.pdf =404; }
    location = /cv/ { try_files /cv/resume.pdf =404; }

    # old versions stay on disk but aren't public
    location ~ ^/cv/resume_.+\.pdf$ { deny all; }

    # upload form posts here
    location = /cv/upload {
        proxy_pass http://127.0.0.1:8725;
        # cloudflare sends the visitor ip here, so the lockout is per person
        proxy_set_header X-Real-IP $http_cf_connecting_ip;
        client_max_body_size 11m;
    }

    # don't serve the backend source, .git, or other dotfiles
    location ^~ /server/ { deny all; }
    location ~ /\.(?!well-known) { deny all; }
}
```

If nginx runs in Docker, `127.0.0.1` is the nginx container itself, not the
host. In that case make the service listen on the docker bridge instead
(add `Environment=CV_HOST=172.17.0.1` to the unit) and point `proxy_pass`
at `http://172.17.0.1:8725` (run `ip -4 addr show docker0` to confirm the IP).

Then `nginx -t && systemctl reload nginx`.

Logs: `journalctl -u svnu-cv-upload`

To change the password, run `--set-password` again. No restart needed.

---

## Design philosophy

* Static files only
* Text-first
* Terminal-inspired aesthetics
* No JavaScript
* No analytics
* No build system

The site should remain readable, fast, and easy to maintain years from now.

---

## License

This project is licensed under the **GNU General Public License v2.0**.

See the `LICENSE` file for details.

---

## Author

**Sai Vishnu**

[https://svnu.in](https://svnu.in)

[root@svnu.in](mailto:root@svnu.in)
