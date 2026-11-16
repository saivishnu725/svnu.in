#!/usr/bin/env bash
# pull_and_index.sh — pull the latest site from git and rebuild the indexes.
# only regenerates indexes when the pull brought something new
# (or when an index is missing, e.g. on a fresh clone).
#
# Cron example (every 5 min):
#   */5 * * * * /root/nginx/html/pull_and_index.sh >> /var/log/svnu-pull.log 2>&1

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="/tmp/svnu-pull.lock"

log() { echo "[$(date -u +"%Y-%m-%d %H:%M UTC")] $*"; }

# don't let two runs overlap if a pull hangs
exec 9>"$LOCK"
if ! flock -n 9; then
  log "another run is still going, skipping"
  exit 0
fi

cd "$ROOT"

# The homepage is tracked, but its recent-posts section is generated locally.
# Restore the committed copy before pulling only when that section is the
# entire difference. This keeps generated links from blocking a future pull
# without discarding edits elsewhere on the page.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
git show HEAD:index.html > "$tmp_dir/committed.html"
strip_recent() {
  sed '/<!-- recent blogs start -->/,/<!-- recent blogs end -->/{ /<!-- recent blogs start -->/p; /<!-- recent blogs end -->/p; d; }' "$1"
}
strip_recent index.html > "$tmp_dir/current.txt"
strip_recent "$tmp_dir/committed.html" > "$tmp_dir/committed.txt"
restored=false
if cmp -s "$tmp_dir/current.txt" "$tmp_dir/committed.txt" && ! cmp -s index.html "$tmp_dir/committed.html"; then
  cp index.html "$tmp_dir/original.html"
  cp "$tmp_dir/committed.html" index.html
  restored=true
fi

before="$(git rev-parse HEAD)"
if ! git pull --ff-only --quiet; then
  if [[ "$restored" == true ]]; then cp "$tmp_dir/original.html" index.html; fi
  exit 1
fi
after="$(git rev-parse HEAD)"

if [[ "$before" == "$after" ]] \
  && [[ -f blogs/index.html ]] && [[ -f notes/index.html ]]; then
  if [[ "$restored" == true ]]; then bash "$ROOT/generate_recent_blogs.sh"; fi
  exit 0   # nothing new, stay quiet
fi

if [[ "$before" == "$after" ]]; then
  log "no new commits but an index is missing"
else
  log "updated ${before:0:7} → ${after:0:7}"
fi

bash "$ROOT/generate_indexes.sh"
bash "$ROOT/generate_recent_blogs.sh"
log "indexes and recent blogs regenerated"
