#!/usr/bin/env bash
# md_to_html.sh — convert new/modified .md files in blogs/ and notes/ to HTML
# only re-processes changed files.
#
# Dependencies: pandoc
# Cron example (every 15 min):
#   */15 * * * * /path/to/md_to_html.sh >> /var/log/md_to_html.log 2>&1

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOGS_DIR="$ROOT/blogs"
NOTES_DIR="$ROOT/notes"
STAMP_DIR="$ROOT/.md_stamps"   # tracks last-converted mtimes

mkdir -p "$STAMP_DIR"

ACCENT="#22d3ee"
BG="#0c0c0c"
FG="#eaeaea"
DIM="#6b7280"

# ── shared CSS ────────────────────────────────────────────────────────────────
PAGE_CSS="
  :root {
    --bg: $BG;
    --fg: $FG;
    --dim: $DIM;
    --accent: $ACCENT;
  }
  body {
    background: var(--bg);
    color: var(--fg);
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-size: 14px;
    line-height: 1.6;
    max-width: 720px;
    margin: 48px auto;
    padding: 0 16px;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }
  .prompt { color: var(--accent); }
  .dim    { color: var(--dim); }
  h1, h2, h3, h4 { font-weight: normal; margin-top: 2em; }
  pre, code {
    background: #111;
    border-radius: 3px;
    padding: 2px 5px;
  }
  pre {
    padding: 12px;
    overflow-x: auto;
    margin: 1.5em 0;
  }
  pre code { padding: 0; background: none; }
  blockquote {
    border-left: 2px solid var(--accent);
    margin: 0;
    padding-left: 1em;
    color: var(--dim);
  }
  img {
    max-width: 100%;
    display: block;
    margin: 1.5em 0;
  }
  ul { list-style: '- '; padding-left: 1em; }
  hr { border: none; border-top: 1px solid #222; margin: 2em 0; }
  table { border-collapse: collapse; width: 100%; }
  th, td { border: 1px solid #222; padding: 6px 10px; text-align: left; }
  th { color: var(--accent); }
"

# ── helpers ───────────────────────────────────────────────────────────────────

log() { echo "[$(date -u +"%Y-%m-%d %H:%M UTC")] $*"; }

# Stamp file path for a given .md file
stamp_for() { echo "$STAMP_DIR/$(echo "$1" | tr '/' '_').stamp"; }

# Return 0 (true) if the .md is newer than its stamp (or stamp missing)
needs_conversion() {
  local md="$1" stamp
  stamp="$(stamp_for "$md")"
  [[ ! -f "$stamp" ]] || [[ "$md" -nt "$stamp" ]]
}

touch_stamp() { touch "$(stamp_for "$1")"; }

# Derive a human-readable breadcrumb from the file path.
# blogs/2026/06/my-post.md → "blog / 2026 / 06 / my-post"
breadcrumb() {
  local rel="${1#$ROOT/}"          # strip root prefix
  rel="${rel%.md}"                 # strip .md
  rel="${rel//_/ }"               # underscores → spaces (optional cosmetic)
  echo "$rel" | sed 's|/| / |g'
}

# Derive the section label ("blog" or "notes") from the path
section_label() {
  if [[ "$1" == "$BLOGS_DIR"* ]]; then echo "blog"
  else echo "notes"
  fi
}

# ── core converter ────────────────────────────────────────────────────────────
convert_md() {
  local md="$1"
  local out="${md%.md}.html"
  local dir
  dir="$(dirname "$md")"

  # Pull the first H1 as page title, fall back to filename
  local title
  title="$(grep -m1 '^# ' "$md" | sed 's/^# //' || true)"
  [[ -z "$title" ]] && title="$(basename "${md%.md}" | tr '_-' '  ')"

  local breadcrumb_str
  breadcrumb_str="$(breadcrumb "$md")"

  local section
  section="$(section_label "$md")"

  # Pandoc converts the Markdown body; we wrap it ourselves
  local body
  body="$(pandoc --from=markdown --to=html \
    --no-highlight \
    --wrap=none \
    "$md" 2>/dev/null)"

  # Rewrite Obsidian-style embeds and wikilinks (pandoc leaves them as-is).
  # Image embeds must be handled BEFORE plain wikilinks.
  #   ![[img.png|248]]       → <img src="img.png" alt="img.png" width="248">
  #   ![[img.png]]           → <img src="img.png" alt="img.png">
  #   [[page|shown text]]    → <a href="page.html">shown text</a>
  #   [[page]]               → <a href="page.html">page</a>
  body="$(echo "$body" | sed -E \
    -e 's#!\[\[([^]|]*)\|([0-9]+)\]\]#<img src="\1" alt="\1" width="\2">#g' \
    -e 's#!\[\[([^]|]*)\]\]#<img src="\1" alt="\1">#g' \
    -e 's#\[\[([^]|]*)\|([^]]*)\]\]#<a href="\1.html">\2</a>#g' \
    -e 's#\[\[([^]]*)\]\]#<a href="\1.html">\1</a>#g')"

  cat > "$out" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>${title} | svnu.in</title>
  <style>
${PAGE_CSS}
  </style>
</head>
<body>

<div class="dim">${breadcrumb_str}</div>

<br>

<span class="prompt">sai@svnu.in</span>:<span>\$ cat $(basename "$md")</span>

${body}

<br>

<p class="dim">— auto-converted from markdown</p>

<span class="prompt">sai@svnu.in</span>:<span>\$</span>

</body>
</html>
HTML

  log "converted: $md → $out"
}

# ── main ──────────────────────────────────────────────────────────────────────
if ! command -v pandoc &>/dev/null; then
  log "ERROR: pandoc not found. Install it: sudo apt install pandoc"
  exit 1
fi

converted=0

# Process blogs/ and notes/ together
for search_dir in "$BLOGS_DIR" "$NOTES_DIR"; do
  [[ -d "$search_dir" ]] || continue
 
  while IFS= read -r -d '' md; do
    if needs_conversion "$md"; then
      convert_md "$md"
      touch_stamp "$md"
      (( converted++ )) || true
    fi
  done < <(find "$search_dir" -type f -name "*.md" \
             -not -path "$BLOGS_DIR/certs/*" \
             -not -path "$BLOGS_DIR/contris/*" -print0)
done
 
if (( converted == 0 )); then
  log "nothing to convert (all .md files up to date)"
else
  log "done — $converted file(s) converted"
  # Regenerate the blog/notes index pages if generate_indexes.sh exists
  if [[ -x "$ROOT/generate_indexes.sh" ]]; then
    log "regenerating indexes..."
    bash "$ROOT/generate_indexes.sh"
    log "indexes updated"
  fi
fi

