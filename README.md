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
└── generate_indexes.sh     # cron-driven index generator

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

This script is intended to be run via cron.

Current cron entry:

```cron
0 3 * * * cd /var/www/svnu.in && ./generate_indexes.sh >/dev/null 2>&1
````

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
