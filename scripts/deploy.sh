#!/usr/bin/env bash
# Caddy control station — reload proxy without tearing down app stacks.
#
# Default: run the viin-caddy container (needs ports 80/443 free).
# Shared VPS: set SHARED_CADDY_DIR + SHARED_CADDY_CONTAINER to merge viin routes
# into an existing Caddy stack (e.g. memapp-caddy on the same host).
set -euo pipefail

BRANCH="${DEPLOY_BRANCH:-main}"
SHARED_CADDY_DIR="${SHARED_CADDY_DIR:-}"
SHARED_CADDY_CONTAINER="${SHARED_CADDY_CONTAINER:-}"

ensure_network() {
  if ! docker network inspect caddy >/dev/null 2>&1; then
    docker network create caddy
  fi
}

merge_shared_caddyfile() {
  local target="$SHARED_CADDY_DIR/Caddyfile"
  local begin="# --- viin.app (managed by viin-caddy deploy) ---"
  local end="# --- end viin.app ---"

  if [ ! -f "$target" ]; then
    echo "Shared Caddyfile not found: $target" >&2
    exit 1
  fi

  python3 - "$target" "$begin" "$end" <<'PY'
import pathlib
import sys

target, begin, end = sys.argv[1:4]
viin = pathlib.Path("Caddyfile").read_text().strip()
block = f"{begin}\n{viin}\n{end}\n"

path = pathlib.Path(target)
text = path.read_text()
if begin in text and end in text:
    before, rest = text.split(begin, 1)
    _, after = rest.split(end, 1)
    path.write_text(before + block + after.lstrip("\n"))
else:
    if text and not text.endswith("\n"):
        text += "\n"
    path.write_text(text + "\n" + block)
PY

  if [ -n "$SHARED_CADDY_CONTAINER" ]; then
    docker network connect caddy "$SHARED_CADDY_CONTAINER" 2>/dev/null || true
    docker exec "$SHARED_CADDY_CONTAINER" caddy reload --config /etc/caddy/Caddyfile
  fi
}

git fetch origin "$BRANCH"
git reset --hard "origin/$BRANCH"

ensure_network

if [ -n "$SHARED_CADDY_DIR" ]; then
  merge_shared_caddyfile
  echo "Merged viin routes into $SHARED_CADDY_DIR/Caddyfile"
  exit 0
fi

docker compose pull
docker compose up -d --remove-orphans
docker image prune -f

docker compose ps
