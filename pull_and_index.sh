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

before="$(git rev-parse HEAD)"
git pull --ff-only --quiet
after="$(git rev-parse HEAD)"

if [[ "$before" == "$after" ]] \
  && [[ -f blogs/index.html ]] && [[ -f notes/index.html ]]; then
  exit 0   # nothing new, stay quiet
fi

if [[ "$before" == "$after" ]]; then
  log "no new commits but an index is missing"
else
  log "updated ${before:0:7} → ${after:0:7}"
fi

# generate_indexes.sh uses $(pwd) as the site root, so we run it from $ROOT
bash "$ROOT/generate_indexes.sh"
log "indexes regenerated"
