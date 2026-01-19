#!/usr/bin/env bash

# ==================================================
# GingerStack Installer
# Purpose: End-to-end server bootstrap + service install
# Audience: End users / clients (clear, step-based output)
# ==================================================

# --------------------------------------------------
# Safety checks
# --------------------------------------------------
# Ensure script is run with bash (not sh/dash)
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }

# Exit immediately on errors and report failing line
set -e
trap 'err "Script exited at line $LINENO"' ERR

# Ensure required dependencies exist
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

# Resolve installer root directory
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ==================================================
# PHASE 1: Filesystem & Environment Bootstrap
# ==================================================

# --------------------------------------------------
# Ensure required directories exist (logs, libs)
# These are required before any other steps run
# --------------------------------------------------
REQUIRED_DIRS=(
  "$ROOT_DIR/lib"
  "$ROOT_DIR/logs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  [[ -d "$dir" ]] || mkdir -p "$dir"
  chmod 0777 "$dir"
done

# --------------------------------------------------
# Create shared media directories
# Used by Seedbox and Jellyfin
# --------------------------------------------------
MEDIA_ROOT="/root/downloads"

MEDIA_DIRS=(
  "$MEDIA_ROOT"
  "$MEDIA_ROOT/movies"
  "$MEDIA_ROOT/tv"
)

for dir in "${MEDIA_DIRS[@]}"; do
  [[ -d "$dir" ]] || mkdir -p "$dir"
done

chmod -R 755 "$MEDIA_ROOT"

# ==================================================
# PHASE 2: Installer Banner & Locking
# ==================================================

# --------------------------------------------------
# Display installer header
# --------------------------------------------------
echo "────────────────────────────────────────"
echo "GingerStack Installer"
echo "Started : $(date -Is)"
echo "────────────────────────────────────────"

# --------------------------------------------------
# Prevent multiple installer instances
# --------------------------------------------------
# --------------------------------------------------
# Verify required core libraries exist
# --------------------------------------------------
REQUIRED_LIBS=(
  "$ROOT_DIR/lib/lock.sh"
  "$ROOT_DIR/lib/logging.sh"
  "$ROOT_DIR/lib/docker.sh"
  "$ROOT_DIR/lib/cloudflare.sh"
)

for lib in "${REQUIRED_LIBS[@]}"; do
  if [[ ! -f "$lib" ]]; then
    echo "FATAL: Required library missing: $lib" >&2
    echo "This installer is incomplete or corrupted." >&2
    echo "Please re-clone the repository and try again." >&2
    exit 1
  fi
done

# Safe to source after validation
source "$ROOT_DIR/lib/lock.sh"
source "$ROOT_DIR/lib/logging.sh"
lock_init gingerstack-installer
lock_update "Installer started"

# ==================================================
# PHASE 3: Environment Configuration
# ==================================================

# --------------------------------------------------
# Load or bootstrap .env configuration
# --------------------------------------------------
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  cat >"$ENV_FILE" <<'EOF'
# GingerStack environment configuration
CF_TOKEN=PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE
EOF

  chmod 600 "$ENV_FILE"

  source "$ROOT_DIR/lib/logging.sh"
  warn ".env file was not found and has been created:"
  warn "  $ENV_FILE"
  warn "Edit this file and insert your Cloudflare API token."
  warn "Then re-run the installer."
  exit 1
fi

# Export env vars for child scripts
set -a
source "$ENV_FILE"
set +a

# --------------------------------------------------
# Validate required environment variables
# --------------------------------------------------
source "$ROOT_DIR/lib/logging.sh"

[[ -z "$CF_TOKEN" || "$CF_TOKEN" == "PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE" ]] && {
  err "CF_TOKEN is not set or still contains the placeholder"
  exit 1
}

lock_update "Environment loaded"

# ==================================================
# PHASE 4: Docker Reset & Health Checks
# ==================================================

# --------------------------------------------------
# Optional full Docker reset
# This ensures a clean, predictable environment
# --------------------------------------------------
docker_hard_reset() {
  warn "Performing HARD Docker reset (purge + reinstall)"

  systemctl stop docker docker.socket containerd 2>/dev/null || true

  apt purge -y docker.io containerd docker-compose-plugin docker-buildx-plugin || true

  rm -rf /var/lib/docker \
         /var/lib/containerd \
         /etc/docker \
         /etc/systemd/system/docker.service.d

  systemctl daemon-reexec
  systemctl daemon-reload

  apt update
  apt install -y docker.io

  systemctl enable --now containerd
  systemctl enable --now docker.socket
  systemctl enable --now docker
}

# --------------------------------------------------
# Verify Docker is healthy and usable
# --------------------------------------------------
docker_sanity_check() {
  info "Running Docker sanity checks"

  systemctl is-active --quiet containerd     || { err "containerd is NOT running"; exit 1; }
  systemctl is-active --quiet docker.socket || { err "docker.socket is NOT active"; exit 1; }
  systemctl is-active --quiet docker        || { err "docker.service is NOT running"; exit 1; }

  docker info >/dev/null 2>&1 || { err "docker info failed — daemon unhealthy"; exit 1; }
  docker run --rm hello-world >/dev/null 2>&1 || { err "Docker runtime test failed"; exit 1; }

  ok "Docker is healthy and ready"
}

read -p "Reset Docker (purge + reinstall)? (recommended) (y/n): " RESET_DOCKER
[[ "$RESET_DOCKER" =~ ^[Yy]$ ]] && docker_hard_reset

docker_sanity_check
lock_update "Docker verified"

# ==================================================
# PHASE 5: Load Core Libraries
# ==================================================

# Safe to load after Docker + env validation
source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/cloudflare.sh"

# ==================================================
# PHASE 6: User Service Selection
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

# --------------------------------------------------
# LAMP-specific configuration (PHP + MySQL)
# --------------------------------------------------
if [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]; then
  lock_update "LAMP selected"

  # Fetch available PHP versions dynamically
  mapfile -t PHP_VERSIONS < <(
    curl -s "https://registry.hub.docker.com/v2/repositories/library/php/tags?page_size=100" |
      jq -r '.results[].name' |
      grep -E '^[0-9]+\.[0-9]+-apache$' |
      sed 's/-apache//' |
      sort -V | uniq
  )

  [[ ${#PHP_VERSIONS[@]} -eq 0 ]] && PHP_VERSIONS=(8.3 8.2 8.1)

  LATEST_PHP="${PHP_VERSIONS[-1]}"

  echo
  echo "Available PHP versions:"
  i=1
  for v in "${PHP_VERSIONS[@]}"; do
    [[ "$v" == "$LATEST_PHP" ]] && echo "  [$i] $v (latest stable)" || echo "  [$i] $v"
    ((i++))
  done

  read -p "Choose PHP version [default: latest]: " PHP_CHOICE
  PHP_VER="${PHP_CHOICE:+${PHP_VERSIONS[$((PHP_CHOICE-1))]}}"
  PHP_VER="${PHP_VER:-$LATEST_PHP}"

  export PHP_VER
  ok "Using PHP $PHP_VER"
  lock_update "PHP version selected: $PHP_VER"

  # --------------------------------------------------
  # PHP runtime features
  # --------------------------------------------------
  echo
  echo "PHP runtime features:"
  read -p "Enable OPcache? (recommended) (y/n): " ENABLE_OPCACHE
  read -p "Enable ionCube Loader? (y/n): " ENABLE_IONCUBE
  read -p "Enable Redis (cache/sessions)? (y/n): " ENABLE_REDIS
  read -p "Enable Xdebug (dev only)? (y/n): " ENABLE_XDEBUG

  echo
  echo "PHP graphics library:"
  echo "  [1] gd (default)"
  echo "  [2] imagick"
  read -p "Choose graphics library [1]: " GRAPHICS_CHOICE

  case "$GRAPHICS_CHOICE" in
    2) PHP_GRAPHICS="imagick" ;;
    *) PHP_GRAPHICS="gd" ;;
  esac

  export ENABLE_OPCACHE ENABLE_IONCUBE ENABLE_REDIS ENABLE_XDEBUG PHP_GRAPHICS
  lock_update "PHP runtime features selected"

  # --------------------------------------------------
  # PHP ini customization (optional)
  # --------------------------------------------------
  echo
  read -p "Customize PHP runtime settings? (memory, uploads, execution time) (y/n): " CUSTOMIZE_PHP

  if [[ "$CUSTOMIZE_PHP" =~ ^[Yy]$ ]]; then
    read -p "PHP memory_limit [512M]: " PHP_MEMORY_LIMIT
    read -p "upload_max_filesize [64M]: " PHP_UPLOAD_MAX
    read -p "post_max_size [64M]: " PHP_POST_MAX
    read -p "max_execution_time [300]: " PHP_MAX_EXEC

    PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT:-512M}"
    PHP_UPLOAD_MAX="${PHP_UPLOAD_MAX:-64M}"
    PHP_POST_MAX="${PHP_POST_MAX:-64M}"
    PHP_MAX_EXEC="${PHP_MAX_EXEC:-300}"

    export PHP_MEMORY_LIMIT PHP_UPLOAD_MAX PHP_POST_MAX PHP_MAX_EXEC
    lock_update "Custom PHP ini values selected"
  else
    lock_update "Using default PHP ini values"
  fi

  # --------------------------------------------------
  # MySQL credentials
  # --------------------------------------------------
  read -s -p "MySQL root password: " MYSQL_ROOT_PASS; echo
  read -s -p "Confirm MySQL root password: " MYSQL_ROOT_PASS2; echo

  [[ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS2" ]] && err "Passwords do not match" && exit 1
fi

# --------------------------------------------------
# Optional services selection
# --------------------------------------------------
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

# --------------------------------------------------
# Let user choose Cloudflare zone
# --------------------------------------------------
CF_API="https://api.cloudflare.com/client/v4"
ZONES_JSON=$(curl -s "$CF_API/zones" -H "Authorization: Bearer $CF_TOKEN")

ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')
(( ZONE_COUNT == 0 )) && err "No Cloudflare zones found" && exit 1

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
lock_update "Cloudflare zone selected: $ZONE_NAME"

# Apply DNS changes now that all options are known
source "$ROOT_DIR/core/03-dns.sh"

# ==================================================
# PHASE 8: Final Confirmation
# ==================================================
echo
echo "────────────────────────────────────────────────────────"
echo "🚀 Ready to install GingerStack"
echo "Domain: $ZONE_NAME"
echo
echo "This process will now set up your server and deploy all selected services."
echo "⏳ Installation can take 10–30 minutes depending on your server speed."
echo "☕ This is a good time to grab a coffee — no interaction will be needed."
echo
echo "Once started, the installation will run automatically."
echo "────────────────────────────────────────────────────────"
read -p "Press ENTER to begin installation..."

lock_update "Installation started"

# ==================================================
# PHASE 9: Core Infrastructure Deployment
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
  sed -i 's/\r$//' "$ROOT_DIR/services/honeypot.sh"
  source "$ROOT_DIR/services/honeypot.sh"
fi

[[ "$INSTALL_STATUS" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/status.sh"

# ==================================================
# PHASE 11: Completion & Summary
# ==================================================
lock_update "Installation complete"
echo "Finished : $(date -Is)"

source "$ROOT_DIR/core/99-summary.sh"
