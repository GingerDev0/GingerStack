#!/usr/bin/env bash

# ==================================================
# GingerStack Installer
# Purpose: End-to-end server bootstrap + service install
# Audience: End users / clients (clear, step-based output)
# ==================================================

# --------------------------------------------------
# Safety checks
# --------------------------------------------------
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }

set -e
trap 'err "Script exited at line $LINENO"' ERR

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==================================================
# PHASE 1: Filesystem & Environment Bootstrap
# ==================================================

REQUIRED_DIRS=(
  "$ROOT_DIR/lib"
  "$ROOT_DIR/logs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  [[ -d "$dir" ]] || mkdir -p "$dir"
  chmod 0777 "$dir"
done

MEDIA_ROOT="/root/downloads"
MEDIA_DIRS=("$MEDIA_ROOT" "$MEDIA_ROOT/movies" "$MEDIA_ROOT/tv")

for dir in "${MEDIA_DIRS[@]}"; do
  [[ -d "$dir" ]] || mkdir -p "$dir"
done

chmod -R 755 "$MEDIA_ROOT"

# ==================================================
# PHASE 2: Installer Banner & Locking
# ==================================================

echo "────────────────────────────────────────"
echo "GingerStack Installer"
echo "Started : $(date -Is)"
echo "────────────────────────────────────────"

REQUIRED_LIBS=(
  "$ROOT_DIR/lib/lock.sh"
  "$ROOT_DIR/lib/logging.sh"
  "$ROOT_DIR/lib/docker.sh"
  "$ROOT_DIR/lib/cloudflare.sh"
)

for lib in "${REQUIRED_LIBS[@]}"; do
  [[ -f "$lib" ]] || {
    echo "FATAL: Required library missing: $lib" >&2
    exit 1
  }
done

source "$ROOT_DIR/lib/lock.sh"
source "$ROOT_DIR/lib/logging.sh"

lock_init gingerstack-installer
lock_update "Installer started"

# ==================================================
# PHASE 3: Environment Configuration
# ==================================================

ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  cat >"$ENV_FILE" <<'EOF'
# GingerStack environment configuration
CF_TOKEN=PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE
EOF

  chmod 600 "$ENV_FILE"

  warn ".env file created:"
  warn "  $ENV_FILE"
  warn "Insert your Cloudflare API token and re-run the installer."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

[[ -z "$CF_TOKEN" || "$CF_TOKEN" == "PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE" ]] && {
  err "CF_TOKEN is not set or still contains the placeholder"
  exit 1
}

lock_update "Environment loaded"

# ==================================================
# PHASE 4: Docker Reset & Health Checks
# ==================================================

docker_hard_reset() {
  warn "Performing HARD Docker reset"

  systemctl stop docker docker.socket containerd 2>/dev/null || true
  apt purge -y docker.io containerd docker-compose-plugin docker-buildx-plugin || true

  rm -rf /var/lib/docker /var/lib/containerd /etc/docker
  systemctl daemon-reexec
  systemctl daemon-reload

  apt update
  apt install -y docker.io

  mkdir -p /etc/docker
  cat >/etc/docker/daemon.json <<'EOF'
{
  "default-address-pools": [
    { "base": "10.10.0.0/16", "size": 24 },
    { "base": "10.20.0.0/16", "size": 24 }
  ]
}
EOF

  systemctl enable --now containerd docker.socket docker
}

docker_sanity_check() {
  info "Running Docker sanity checks"

  systemctl is-active --quiet containerd     || err "containerd not running"
  systemctl is-active --quiet docker.socket || err "docker.socket not running"
  systemctl is-active --quiet docker        || err "docker not running"

  docker info >/dev/null
  docker run --rm hello-world >/dev/null

  ok "Docker is healthy"
}

read -p "Reset Docker (purge + reinstall)? (recommended) (y/n): " RESET_DOCKER
[[ "$RESET_DOCKER" =~ ^[Yy]$ ]] && docker_hard_reset

docker_sanity_check
lock_update "Docker verified"

# ==================================================
# PHASE 5: Load Core Libraries
# ==================================================

source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/cloudflare.sh"

# ==================================================
# PHASE 6: Service Selection
# ==================================================

clear
cat <<'EOF'
────────────────────────────────────────────────────
   _____ _                       _____ _             _
  / ____(_)                     / ____| |           | |
 | |  __ _ _ __   __ _  ___ _ _| (___ | |_ __ _  ___| | __
 | | |_ | | '_ \ / _` |/ _ \ '__\___ \| __/ _` |/ __| |/ /
 | |__| | | | | | (_| |  __/ |  ____) | || (_| | (__|   <
  \_____|_|_| |_|\__, |\___|_| |_____/ \__\__,_|\___|_|\_\
                  __/ |
                 |___/

                GingerStack Installer
────────────────────────────────────────────────────
Choose which services to install.
Only selected services will be deployed.

EOF

read -p "Install LAMP stack? (y/n): " INSTALL_LAMP

if [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]; then
  lock_update "LAMP selected"

  read -s -p "MySQL root password: " MYSQL_ROOT_PASS; echo
  read -s -p "Confirm MySQL root password: " MYSQL_ROOT_PASS2; echo

  [[ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS2" ]] && {
    err "Passwords do not match"
    exit 1
  }

  export MYSQL_ROOT_PASS
fi

echo ""
read -p "Install Portainer? (y/n): " INSTALL_PORTAINER
read -p "Install Jellyfin? (y/n): " INSTALL_JELLYFIN
read -p "Install Seedbox (qBittorrent)? (y/n): " INSTALL_SEEDBOX
read -p "Install Immich? (y/n): " INSTALL_IMMICH
read -p "Install Mail Server + Webmail? (y/n): " INSTALL_MAIL
read -p "Install WireGuard VPN? (y/n): " INSTALL_WIREGUARD
read -p "Install SSH Honeypot (Cowrie)? (y/n): " INSTALL_HONEYPOT
read -p "Install AI Stack (Ollama + OpenWebUI)? (y/n): " INSTALL_AI
read -p "Install Status page? (y/n): " INSTALL_STATUS

lock_update "Service selection complete"

# ==================================================
# PHASE 7: Cloudflare DNS Configuration
# ==================================================

CF_API="https://api.cloudflare.com/client/v4"
ZONES_JSON=$(curl -s "$CF_API/zones" -H "Authorization: Bearer $CF_TOKEN")

mapfile -t ZONE_NAMES < <(echo "$ZONES_JSON" | jq -r '.result[].name')
mapfile -t ZONE_IDS   < <(echo "$ZONES_JSON" | jq -r '.result[].id')

i=1
for z in "${ZONE_NAMES[@]}"; do
  echo " [$i] $z"
  ((i++))
done

read -p "Select zone number: " ZONE_CHOICE
INDEX=$((ZONE_CHOICE-1))

export ZONE_NAME="${ZONE_NAMES[$INDEX]}"
export ZONE_ID="${ZONE_IDS[$INDEX]}"

ok "Using zone: $ZONE_NAME"
lock_update "Cloudflare zone selected"

source "$ROOT_DIR/core/03-dns.sh"

# ==================================================
# PHASE 8: Final Confirmation
# ==================================================

echo
echo "Ready to install GingerStack for domain: $ZONE_NAME"
read -p "Press ENTER to begin installation..."

lock_update "Installation started"

# ==================================================
# PHASE 9: Core Infrastructure
# ==================================================

source "$ROOT_DIR/core/00-base.sh"
source "$ROOT_DIR/core/01-network.sh"
source "$ROOT_DIR/core/02-traefik.sh"

# ==================================================
# PHASE 10: Service Deployment
# ==================================================

[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/portainer.sh"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/lamp.sh"
[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]]  && source "$ROOT_DIR/services/jellyfin.sh"
[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]]   && source "$ROOT_DIR/services/seedbox.sh"
[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]]    && source "$ROOT_DIR/services/immich.sh"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/mail.sh"
[[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/wireguard.sh"
[[ "$INSTALL_AI" =~ ^[Yy]$ ]]        && source "$ROOT_DIR/services/ollama.sh"

if [[ "$INSTALL_HONEYPOT" =~ ^[Yy]$ ]]; then
  mkdir -p /root/apps/cowrie/var/lib/cowrie
  chmod -R 0777 /root/apps/cowrie
  source "$ROOT_DIR/services/honeypot.sh"
fi

[[ "$INSTALL_STATUS" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/status.sh"

# ==================================================
# PHASE 11: Completion
# ==================================================

lock_update "Installation complete"
echo "Finished : $(date -Is)"

source "$ROOT_DIR/core/99-summary.sh"
