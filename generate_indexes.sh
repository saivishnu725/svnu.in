#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLOGS_DIR="$ROOT/blogs"
NOTES_DIR="$ROOT/notes"

ACCENT="#22d3ee"

html_header() {
cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
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
EOF
}

html_footer() {
cat <<EOF
<p class="dim">auto-generated · $(date -u +"%Y-%m-%d %H:%M UTC")</p>
</body>
</html>
EOF
}

extract_title() {
  sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$1" \
    | head -n1 \
    | sed 's/ *| *svnu\.in$//'
}

# Series membership lives in the corresponding Markdown source. HTML-only
# posts, and posts without a series comment, go under uncategorised.
extract_series() {
  local source="${1%.html}.md" series=""
  if [[ -f "$source" ]]; then
    series="$(sed -n 's/^<!-- series: \(.*\) -->$/\1/p' "$source" | head -n1)"
  fi
  printf '%s\n' "${series:-uncategorised}"
}

escape_html() {
  local value="$1"
  value="${value//&/\&amp;}"
  value="${value//</\&lt;}"
  value="${value//>/\&gt;}"
  value="${value//\"/\&quot;}"
  printf '%s' "$value"
}

# -------- BLOG INDEX --------
BLOG_INDEX="$BLOGS_DIR/index.html"
html_header "blogs" "blogs" > "$BLOG_INDEX"

declare -A series_seen=()
while IFS= read -r -d '' file; do
  series_seen["$(extract_series "$file")"]=1
done < <(find "$BLOGS_DIR" -type f -name '*.html' ! -name 'index.html' -print0)

while IFS= read -r series; do
  [[ "$series" == "uncategorised" ]] && continue
  printf '<h3>%s</h3>\n<ul>\n' "$(escape_html "$series")" >> "$BLOG_INDEX"
  while IFS= read -r file; do
    [[ "$(extract_series "$file")" == "$series" ]] || continue
    title="$(extract_title "$file")"
    rel="${file#$ROOT/}"
    printf '<li><a href="/%s">%s</a></li>\n' "$(escape_html "$rel")" "$title" >> "$BLOG_INDEX"
  done < <(find "$BLOGS_DIR" -type f -name '*.html' ! -name 'index.html' | sort)
  echo '</ul>' >> "$BLOG_INDEX"
done < <(printf '%s\n' "${!series_seen[@]}" | LC_ALL=C sort)

if [[ -n "${series_seen[uncategorised]:-}" ]]; then
  printf '<h3>uncategorised</h3>\n<ul>\n' >> "$BLOG_INDEX"
  while IFS= read -r file; do
    [[ "$(extract_series "$file")" == "uncategorised" ]] || continue
    title="$(extract_title "$file")"
    rel="${file#$ROOT/}"
    printf '<li><a href="/%s">%s</a></li>\n' "$(escape_html "$rel")" "$title" >> "$BLOG_INDEX"
  done < <(find "$BLOGS_DIR" -type f -name '*.html' ! -name 'index.html' | sort -r)
  echo '</ul>' >> "$BLOG_INDEX"
fi

html_footer >> "$BLOG_INDEX"

# -------- NOTES INDEX --------
NOTES_INDEX="$NOTES_DIR/index.html"
html_header "notes" "notes" > "$NOTES_INDEX"
echo '<ul>' >> "$NOTES_INDEX"

find "$NOTES_DIR" -type f -name "*.html" ! -name "index.html" | sort | while read -r file; do
  title="$(extract_title "$file")"
  rel="${file#$ROOT/}"
  echo "<li><a href=\"/$rel\">$title</a></li>" >> "$NOTES_INDEX"
done

echo '</ul>' >> "$NOTES_INDEX"
html_footer >> "$NOTES_INDEX"
