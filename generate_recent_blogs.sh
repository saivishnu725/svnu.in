#!/usr/bin/env bash
# Update only the marked section of the homepage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAGE="$ROOT/index.html"
[[ $(grep -c '<!-- recent blogs start -->' "$PAGE") == 1 && $(grep -c '<!-- recent blogs end -->' "$PAGE") == 1 ]] || {
  echo "recent blog markers missing or duplicated in $PAGE" >&2
  exit 1
}
TMP="$(mktemp "$ROOT/.recent-blogs.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

# The list uses HTML file modification times, like ls -t.
{
  awk '/<!-- recent blogs start -->/ { print; exit } { print }' "$PAGE"
  count=0
  while IFS= read -r -d '' entry; do
    file="${entry#* }"
    title="$(sed -n 's:.*<title>\(.*\)</title>.*:\1:p' "$file" | head -n1 | sed 's/ *| *svnu\.in$//')"
    source="${file%.html}.md"
    category=""
    if [[ -f "$source" ]]; then
      category="$(sed -n '/^# /q; s/^<!-- series: \(.*\) -->$/\1/p' "$source" | head -n1)"
    fi
    category="${category:-uncategorised}"
    category="${category//&/\&amp;}"
    category="${category//</\&lt;}"
    category="${category//>/\&gt;}"
    rel="${file#$ROOT/}"
    rel="${rel//&/\&amp;}"
    rel="${rel//\"/\&quot;}"
    rel="${rel//</\&lt;}"
    rel="${rel//>/\&gt;}"
    printf '    %s → <a href="/%s">%s</a><br>\n' "$category" "$rel" "$title"
    count=$((count + 1))
    (( count == 3 )) && break
  done < <(find "$ROOT/blogs" -type f -name '*.html' ! -name 'index.html' -printf '%T@ %p\0' | sort -z -nr)
  awk 'found { print } /<!-- recent blogs end -->/ { found=1; print }' "$PAGE"
} > "$TMP"

# Avoid replacing the page at all when the generated list hasn't changed.
cmp -s "$TMP" "$PAGE" || cat "$TMP" > "$PAGE"
