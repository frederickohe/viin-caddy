#!/usr/bin/env bash
# One-time VPS bootstrap for the Viin platform.
# Run as root on the server: bash server-bootstrap.sh
set -euo pipefail

DEPLOY_USER="${DEPLOY_USER:-root}"
DEPLOY_KEY_PATH="${DEPLOY_KEY_PATH:-/root/.ssh/github_actions_deploy}"
WWW_ROOT="/var/www"
GITHUB_ORG="${GITHUB_ORG:-frederickohe}"

REPOS=(
  viin
  viin-web
  viin-caddy
  viin-rag
  qdrant
  chatwoot-docker-compose
  postiz-docker-compose
)

log() { echo "[bootstrap] $*"; }

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
    return
  fi
  log "Installing Docker..."
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git rsync
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
}

create_networks() {
  for net in caddy greenbrain_rag; do
    if docker network inspect "$net" >/dev/null 2>&1; then
      log "Network '$net' exists"
    else
      docker network create "$net"
      log "Created network '$net'"
    fi
  done
}

setup_deploy_key() {
  if [ ! -f "$DEPLOY_KEY_PATH" ]; then
    log "Generating deploy SSH key at $DEPLOY_KEY_PATH"
    ssh-keygen -t ed25519 -f "$DEPLOY_KEY_PATH" -N "" -C "github-actions-viin"
  fi
  log "Add this public key as a read-only deploy key on each GitHub repo:"
  echo "----- PUBLIC KEY (deploy key) -----"
  cat "${DEPLOY_KEY_PATH}.pub"
  echo "-----------------------------------"
  log "Add the private key below as VPS_SSH_KEY secret in each repo:"
  echo "----- PRIVATE KEY (GitHub secret) -----"
  cat "$DEPLOY_KEY_PATH"
  echo "---------------------------------------"
}

clone_repos() {
  mkdir -p "$WWW_ROOT"
  for repo in "${REPOS[@]}"; do
    target="$WWW_ROOT/$repo"
    if [ -d "$target/.git" ]; then
      log "Repo already cloned: $target"
      continue
    fi
    log "Cloning $repo via HTTPS..."
    git clone "https://github.com/${GITHUB_ORG}/${repo}.git" "$target"
  done
}

prepare_env_files() {
  if [ -f "$WWW_ROOT/viin-rag/.env.example" ] && [ ! -f "$WWW_ROOT/viin-rag/.env" ]; then
    cp "$WWW_ROOT/viin-rag/.env.example" "$WWW_ROOT/viin-rag/.env"
    log "Created viin-rag/.env from example — set RAG_API_KEY"
  fi
  if [ -f "$WWW_ROOT/chatwoot-docker-compose/.env.example" ] && [ ! -f "$WWW_ROOT/chatwoot-docker-compose/.env" ]; then
    cp "$WWW_ROOT/chatwoot-docker-compose/.env.example" "$WWW_ROOT/chatwoot-docker-compose/.env"
    log "Created chatwoot .env from example — set SECRET_KEY_BASE and REDIS_PASSWORD"
  fi
  if [ -f "$WWW_ROOT/viin-web/.env.example" ] && [ ! -f "$WWW_ROOT/viin-web/.env" ]; then
    cp "$WWW_ROOT/viin-web/.env.example" "$WWW_ROOT/viin-web/.env"
    log "Created viin-web/.env from example"
  fi
}

upload_platform_scripts() {
  log "Platform deploy scripts will be available after first git pull from each repo."
}

install_docker
apt-get install -y -qq git rsync 2>/dev/null || true
create_networks
setup_deploy_key
clone_repos
prepare_env_files
chmod +x "$WWW_ROOT"/*/scripts/deploy.sh 2>/dev/null || true
upload_platform_scripts

log "Bootstrap complete."
log "Next steps:"
log "  1. Add deploy key to each GitHub repo (Settings → Deploy keys)"
log "  2. Add GitHub secrets: VPS_HOST, VPS_USER=root, VPS_SSH_KEY"
log "  3. Configure .env files on the server for viin, chatwoot, viin-rag"
log "  4. Run: bash $WWW_ROOT/viin-caddy/scripts/server-bootstrap-deploy.sh"
