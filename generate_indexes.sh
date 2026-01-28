#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
BLOGS_DIR="$ROOT/blogs"
NOTES_DIR="$ROOT/notes"

ACCENT="#22d3ee"

html_header() {
cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>$1 | svnu.in</title>
<style>
  body {
    background:#0c0c0c;
    color:#eaeaea;
    font-family: ui-monospace, monospace;
    max-width:720px;
    margin:48px auto;
    padding:0 16px;
    font-size:14px;
  }
  a { color:$ACCENT; text-decoration:none }
  a:hover { text-decoration:underline }
  .dim { color:#6b7280 }
</style>
</head>
<body>
<h2>$2</h2>
<ul>
EOF
}

html_footer() {
cat <<EOF
</ul>
<p class="dim">auto-generated · $(date -u +"%Y-%m-%d %H:%M UTC")</p>
</body>
</html>
EOF
}

# extract_title() {
#  sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$1" | head -n1
# }
extract_title() {
  sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$1" \
    | head -n1 \
    | sed 's/ *| *svnu\.in$//'
}

# -------- BLOG INDEX --------
BLOG_INDEX="$BLOGS_DIR/index.html"
html_header "blogs" "blogs" > "$BLOG_INDEX"

find "$BLOGS_DIR" -type f -name "*.html" ! -name "index.html" | sort -r | while read -r file; do
  title="$(extract_title "$file")"
  rel="${file#$ROOT/}"
  echo "<li><a href=\"/$rel\">$title</a></li>" >> "$BLOG_INDEX"
done

html_footer >> "$BLOG_INDEX"

# -------- NOTES INDEX --------
NOTES_INDEX="$NOTES_DIR/index.html"
html_header "notes" "notes" > "$NOTES_INDEX"

find "$NOTES_DIR" -type f -name "*.html" ! -name "index.html" | sort | while read -r file; do
  title="$(extract_title "$file")"
  rel="${file#$ROOT/}"
  echo "<li><a href=\"/$rel\">$title</a></li>" >> "$NOTES_INDEX"
done

html_footer >> "$NOTES_INDEX"
