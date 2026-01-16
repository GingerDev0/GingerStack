#!/usr/bin/env bash
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }
set -e
trap 'err "Script exited at line $LINENO"' ERR

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --------------------------------------------------
# Directory bootstrap (ensure existence + perms)
# --------------------------------------------------
REQUIRED_DIRS=(
  "$ROOT_DIR/lib"
  "$ROOT_DIR/logs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
  chmod 0777 "$dir"
done

# --------------------------------------------------
# Shared media directories (seedbox + jellyfin)
# --------------------------------------------------
MEDIA_ROOT="/root/downloads"

MEDIA_DIRS=(
  "$MEDIA_ROOT"
  "$MEDIA_ROOT/movies"
  "$MEDIA_ROOT/tv"
)

for dir in "${MEDIA_DIRS[@]}"; do
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
done

# Safe, readable defaults for all containers
chmod -R 755 "$MEDIA_ROOT"

# --------------------------------------------------
# Logging
# --------------------------------------------------
LOG_DIR="$ROOT_DIR/logs"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "────────────────────────────────────────"
echo "GingerStack Installer"
echo "Started : $(date -Is)"
echo "Logfile : $LOG_FILE"
echo "────────────────────────────────────────"

# --------------------------------------------------
# Locking
# --------------------------------------------------
source "$ROOT_DIR/lib/lock.sh"
lock_init gingerstack-installer
lock_update "Installer started"
lock_update "Logfile: $LOG_FILE"

# --------------------------------------------------
# Load / bootstrap .env
# --------------------------------------------------
ENV_FILE="$ROOT_DIR/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  cat >"$ENV_FILE" <<'EOF'
# GingerStack environment configuration
# ------------------------------------
# Cloudflare API Token
# Required scopes:
#   - Zone:Read
#   - DNS:Edit
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

set -a
source "$ENV_FILE"
set +a

# --------------------------------------------------
# Validate required env vars
# --------------------------------------------------
source "$ROOT_DIR/lib/logging.sh"

[[ -z "$CF_TOKEN" || "$CF_TOKEN" == "PASTE_YOUR_CLOUDFLARE_API_TOKEN_HERE" ]] && {
  err "CF_TOKEN is not set or still contains the placeholder"
  err "Edit .env and add your real Cloudflare API token"
  exit 1
}

lock_update "Environment loaded"

# --------------------------------------------------
# Source libraries
# --------------------------------------------------
source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/cloudflare.sh"

clear
cat <<'EOF'
   _____ _                       _____ _             _
  / ____(_)                     / ____| |           | |
 | |  __ _ _ __   __ _  ___ _ _| (___ | |_ __ _  ___| | __
 | | |_ | | '_ \ / _` |/ _ \ '__\___ \| __/ _` |/ __| |/ /
 | |__| | | | | | (_| |  __/ |  ____) | || (_| | (__|   <
  \_____|_|_| |_|\__, |\___|_| |_____/ \__\__,_|\___|_|\_\
                  __/ |
                 |___/

                GingerStack Installer
EOF

read -p "Install LAMP stack? (y/n): " INSTALL_LAMP

# --------------------------------------------------
# LAMP-specific options
# --------------------------------------------------
if [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]; then
  lock_update "LAMP selected"

  mapfile -t PHP_VERSIONS < <(
    curl -s "https://registry.hub.docker.com/v2/repositories/library/php/tags?page_size=100" |
      jq -r '.results[].name' |
      grep -E '^[0-9]+\.[0-9]+-apache$' |
      sed 's/-apache//' |
      sort -V |
      uniq
  )

  if [[ ${#PHP_VERSIONS[@]} -eq 0 ]]; then
    warn "Could not fetch PHP versions — using safe defaults"
    PHP_VERSIONS=(8.3 8.2 8.1)
  fi

  LATEST_PHP="${PHP_VERSIONS[-1]}"

  echo
  echo "Available PHP versions:"
  i=1
  for v in "${PHP_VERSIONS[@]}"; do
    [[ "$v" == "$LATEST_PHP" ]] && echo "  [$i] $v (latest stable)" || echo "  [$i] $v"
    ((i++))
  done

  read -p "Choose PHP version [default: latest]: " PHP_CHOICE

  if [[ -z "$PHP_CHOICE" ]]; then
    PHP_VER="$LATEST_PHP"
  else
    PHP_VER="${PHP_VERSIONS[$((PHP_CHOICE-1))]}"
  fi

  ok "Using PHP $PHP_VER"
  lock_update "PHP version selected: $PHP_VER"

  read -s -p "MySQL root password: " MYSQL_ROOT_PASS; echo
  read -s -p "Confirm MySQL root password: " MYSQL_ROOT_PASS2; echo

  [[ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS2" ]] && err "Passwords do not match" && exit 1
fi

# --------------------------------------------------
# Other services
# --------------------------------------------------
read -p "Install Portainer? (y/n): " INSTALL_PORTAINER
read -p "Install Jellyfin? (y/n): " INSTALL_JELLYFIN
read -p "Install Seedbox (qBittorrent)? (y/n): " INSTALL_SEEDBOX
read -p "Install Immich? (y/n): " INSTALL_IMMICH
read -p "Install Mail Server + Webmail? (y/n): " INSTALL_MAIL
read -p "Install WireGuard VPN? (y/n): " INSTALL_WIREGUARD
read -p "Install SSH Honeypot (Cowrie)? (y/n): " INSTALL_HONEYPOT

lock_update "Service selection complete"

# --------------------------------------------------
# Cloudflare zone selection
# --------------------------------------------------
CF_API="https://api.cloudflare.com/client/v4"

ZONES_JSON=$(curl -s "$CF_API/zones" \
  -H "Authorization: Bearer $CF_TOKEN")

ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')
(( ZONE_COUNT == 0 )) && err "No Cloudflare zones found" && exit 1

i=1
mapfile -t ZONE_NAMES < <(echo "$ZONES_JSON" | jq -r '.result[].name')
mapfile -t ZONE_IDS   < <(echo "$ZONES_JSON" | jq -r '.result[].id')

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

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo
echo "────────────────────────────────────────────────────────"
echo "🚀 Ready to install GingerStack"
echo
echo "Domain:"
echo "  • $ZONE_NAME"
echo
echo "Selected services:"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]      && echo "  • LAMP stack (PHP $PHP_VER)"
[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && echo "  • Portainer"
[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]]  && echo "  • Jellyfin"
[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]]   && echo "  • Seedbox (qBittorrent)"
[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]]    && echo "  • Immich"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]      && echo "  • Mail server + Webmail"
[[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && echo "  • WireGuard VPN"
[[ "$INSTALL_HONEYPOT" =~ ^[Yy]$ ]]  && echo "  • SSH Honeypot (Cowrie)"

echo
echo "☕ Grab a coffee — press ENTER when you're ready."
read -p ""

lock_update "Installation started"

# --------------------------------------------------
# Core
# --------------------------------------------------
source "$ROOT_DIR/core/00-base.sh"
source "$ROOT_DIR/core/01-network.sh"
source "$ROOT_DIR/core/03-dns.sh"
source "$ROOT_DIR/core/02-traefik.sh"

# --------------------------------------------------
# Services
# --------------------------------------------------
[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/portainer.sh"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/lamp.sh"
[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]]  && source "$ROOT_DIR/services/jellyfin.sh"
[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]]   && source "$ROOT_DIR/services/seedbox.sh"
[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]]    && source "$ROOT_DIR/services/immich.sh"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/mail.sh"
[[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/wireguard.sh"

if [[ "$INSTALL_HONEYPOT" =~ ^[Yy]$ ]]; then
  mkdir -p /root/apps/cowrie/var/lib/cowrie
  chmod -R 0777 /root/apps/cowrie
  sed -i 's/\r$//' "$ROOT_DIR/services/honeypot.sh"
  source "$ROOT_DIR/services/honeypot.sh"
fi

lock_update "Installation complete"
echo "Finished : $(date -Is)"

source "$ROOT_DIR/core/99-summary.sh"
