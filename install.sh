#!/usr/bin/env bash
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$ROOT_DIR/lib/logging.sh"
source "$ROOT_DIR/lib/docker.sh"
source "$ROOT_DIR/lib/cloudflare.sh"

title "GingerStack Modular Installer"

read -p "Install LAMP stack? (y/n): " INSTALL_LAMP
read -p "Install Portainer? (y/n): " INSTALL_PORTAINER
read -p "Install Jellyfin? (y/n): " INSTALL_JELLYFIN
read -p "Install Seedbox (qBittorrent)? (y/n): " INSTALL_SEEDBOX
read -p "Install Immich? (y/n): " INSTALL_IMMICH
read -p "Install Mail Server + Webmail? (y/n): " INSTALL_MAIL

if [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]; then
  read -p "PHP version (8.1 / 8.2 / 8.3) [8.2]: " PHP_VER
  PHP_VER=${PHP_VER:-8.2}
  read -s -p "MySQL root password: " MYSQL_ROOT_PASS; echo
  read -s -p "Confirm MySQL root password: " MYSQL_ROOT_PASS2; echo
  [[ "$MYSQL_ROOT_PASS" != "$MYSQL_ROOT_PASS2" ]] && err "Passwords do not match" && exit 1
fi

title "Cloudflare API Token Required"
read -p "Paste Cloudflare API token: " CF_TOKEN
export CF_TOKEN

CF_API="https://api.cloudflare.com/client/v4"
ZONES_JSON=$(curl -s "$CF_API/zones" -H "Authorization: Bearer $CF_TOKEN")
ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')

(( ZONE_COUNT == 0 )) && err "No zones found" && exit 1

i=1
mapfile -t ZONE_NAMES < <(echo "$ZONES_JSON" | jq -r '.result[].name')
mapfile -t ZONE_IDS   < <(echo "$ZONES_JSON" | jq -r '.result[].id')

for z in "${ZONE_NAMES[@]}"; do echo " [$i] $z"; ((i++)); done
read -p "Select zone number: " ZONE_CHOICE

INDEX=$((ZONE_CHOICE-1))
export ZONE_NAME="${ZONE_NAMES[$INDEX]}"
export ZONE_ID="${ZONE_IDS[$INDEX]}"

ok "Using zone: $ZONE_NAME"

source "$ROOT_DIR/core/00-base.sh"
source "$ROOT_DIR/core/01-network.sh"
source "$ROOT_DIR/core/03-dns.sh"
source "$ROOT_DIR/core/02-traefik.sh"

[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/portainer.sh"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/lamp.sh"
[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]]  && source "$ROOT_DIR/services/jellyfin.sh"
[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]]   && source "$ROOT_DIR/services/seedbox.sh"
[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]]    && source "$ROOT_DIR/services/immich.sh"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]      && source "$ROOT_DIR/services/mail.sh"

title "INSTALL COMPLETE"
ok "All services are up and running!"
