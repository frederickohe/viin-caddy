#!/usr/bin/env bash
# Full ordered platform deploy — run on the VPS after env files are configured.
set -euo pipefail

WWW_ROOT="/var/www"

log() { echo "[deploy-all] $*"; }

docker network inspect caddy >/dev/null 2>&1 || docker network create caddy

log "1/3 viin backend"
cd "$WWW_ROOT/viin-backend" && NEEDS_CADDY_NET=true bash scripts/deploy.sh

log "2/3 viin-web"
cd "$WWW_ROOT/viin-web" && BUILD_NO_CACHE=true bash scripts/deploy.sh

log "3/3 caddy (control station)"
cd "$WWW_ROOT/viin-caddy" && bash scripts/deploy.sh

log "All stacks deployed."
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
