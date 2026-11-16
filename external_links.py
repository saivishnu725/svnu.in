#!/usr/bin/env python3
"""Open external HTTP links in a new tab while leaving site links alone."""
import re
import sys
from html.parser import HTMLParser
from urllib.parse import urlsplit


class LinkParser(HTMLParser):
    def __init__(self, html):
        super().__init__(convert_charrefs=True)
        self.html = html
        self.offsets = [0]
        for line in html.splitlines(keepends=True):
            self.offsets.append(self.offsets[-1] + len(line))
        self.changes = []

    def handle_starttag(self, tag, attrs):
        if tag != "a":
            return
        attrs = dict(attrs)
        href = attrs.get("href") or ""
        url = urlsplit(href)
        if not (url.scheme.lower() in ("http", "https") or href.startswith("//")):
            return
        if (url.hostname or "").lower() in ("svnu.in", "www.svnu.in"):
            return
        original = self.get_starttag_text()
        # Replace existing attributes so the operation is safe to repeat.
        updated = re.sub(r'\s+(?:target|rel)\s*=\s*(?:"[^"]*"|\'[^\']*\'|[^\s>]+)', '', original, flags=re.I)
        rel = (attrs.get("rel") or "").split()
        for value in ("noopener", "noreferrer"):
            if value not in rel:
                rel.append(value)
        # Attribute values are escaped because they may come from source HTML.
        from html import escape
        updated = updated[:-1] + f' target="_blank" rel="{escape(" ".join(rel), quote=True)}">'
        line, column = self.getpos()
        start = self.offsets[line - 1] + column
        self.changes.append((start, start + len(original), updated))

    def result(self):
        result = self.html
        for start, end, replacement in reversed(self.changes):
            result = result[:start] + replacement + result[end:]
        return result


html = sys.stdin.read()
parser = LinkParser(html)
parser.feed(html)
sys.stdout.write(parser.result())
