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
└── pull_and_index.sh       # cron job on the server: git pull + indexes

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
