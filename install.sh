#!/usr/bin/env bash
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }
set -e
trap 'err "Script exited at line $LINENO"' ERR

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

source "$ROOT_DIR/lib/logging.sh"
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
# LAMP-specific options (only if enabled)
# --------------------------------------------------
if [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]]; then

  # Detect available PHP versions (stable apache tags)
  mapfile -t PHP_VERSIONS < <(
    curl -s "https://registry.hub.docker.com/v2/repositories/library/php/tags?page_size=100" |
      jq -r '.results[].name' |
      grep -E '^[0-9]+\.[0-9]+-apache$' |
      sed 's/-apache//' |
      sort -V |
      uniq
  )

  # Fallback if Docker Hub is unreachable
  if [[ ${#PHP_VERSIONS[@]} -eq 0 ]]; then
    warn "Could not fetch PHP versions — using safe defaults"
    PHP_VERSIONS=(8.3 8.2 8.1)
  fi

  LATEST_PHP="${PHP_VERSIONS[-1]}"

  echo
  echo "Available PHP versions:"
  i=1
  for v in "${PHP_VERSIONS[@]}"; do
    if [[ "$v" == "$LATEST_PHP" ]]; then
      echo "  [$i] $v (latest stable)"
    else
      echo "  [$i] $v"
    fi
    ((i++))
  done

  read -p "Choose PHP version [default: latest]: " PHP_CHOICE

  if [[ -z "$PHP_CHOICE" ]]; then
    PHP_VER="$LATEST_PHP"
  else
    PHP_VER="${PHP_VERSIONS[$((PHP_CHOICE-1))]}"
  fi

  ok "Using PHP $PHP_VER"

  # MySQL root password
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

echo
echo "Cloudflare API Token Required"
echo
read -p "Paste Cloudflare API token: " CF_TOKEN
export CF_TOKEN

CF_API="https://api.cloudflare.com/client/v4"
ZONES_JSON=$(curl -s "$CF_API/zones" -H "Authorization: Bearer $CF_TOKEN")
ZONE_COUNT=$(echo "$ZONES_JSON" | jq '.result | length')

(( ZONE_COUNT == 0 )) && err "No zones found" && exit 1

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

# --------------------------------------------------
# Pre-install pause + selected services summary
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
echo "The installation will now:"
echo "  • Pull Docker images"
echo "  • Configure networking, DNS, and SSL"
echo "  • Deploy and start the selected services"
echo
echo "This may take several minutes depending on your server."
echo
echo "☕ Grab a coffee — press ENTER when you're ready."
echo "────────────────────────────────────────────────────────"
read -p ""

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
[[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && source "$ROOT_DIR/services/wireguard.sh"

if [[ "$INSTALL_HONEYPOT" =~ ^[Yy]$ ]]; then
  mkdir -p /root/apps/cowrie/var/lib/cowrie
  sed -i 's/\r$//' "$ROOT_DIR/services/honeypot.sh"
  source "$ROOT_DIR/services/honeypot.sh"
fi

source "$ROOT_DIR/core/99-summary.sh"
