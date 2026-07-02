#!/usr/bin/env bash
# Full ordered platform deploy — run on the VPS after env files are configured.
set -euo pipefail

WWW_ROOT="/var/www"

log() { echo "[deploy-all] $*"; }

for net in caddy greenbrain_rag; do
  docker network inspect "$net" >/dev/null 2>&1 || docker network create "$net"
done

log "1/6 viin backend"
cd "$WWW_ROOT/viin" && NEEDS_CADDY_NET=true NEEDS_RAG_NET=true bash scripts/deploy.sh

log "2/6 viin-rag (qdrant + embeddings + rag-api)"
cd "$WWW_ROOT/viin-rag" && NEEDS_CADDY_NET=true NEEDS_RAG_NET=true bash scripts/deploy.sh

log "3/6 chatwoot"
cd "$WWW_ROOT/chatwoot-docker-compose" && bash scripts/deploy.sh

log "4/6 postiz"
cd "$WWW_ROOT/postiz-docker-compose" && bash scripts/deploy.sh

log "5/6 viin-web"
cd "$WWW_ROOT/viin-web" && BUILD_NO_CACHE=true bash scripts/deploy.sh

log "6/6 caddy (control station)"
cd "$WWW_ROOT/viin-caddy" && bash scripts/deploy.sh

log "All stacks deployed."
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
