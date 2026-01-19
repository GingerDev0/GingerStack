#!/usr/bin/env bash
[ -z "$BASH_VERSION" ] && { echo "ERROR: Run with bash"; exit 1; }
set -e

# --------------------------------------------------
# Colors
# --------------------------------------------------
ORANGE='\033[38;5;208m'
AMBER='\033[38;5;214m'
GREEN='\033[38;5;112m'
RED='\033[38;5;196m'
WHITE='\033[38;5;15m'
GRAY='\033[38;5;245m'
NC='\033[0m'

info()  { echo -e "${AMBER} [i]${NC} $1"; }
ok()    { echo -e "${GREEN} [OK]${NC} $1"; }
warn()  { echo -e "${ORANGE} [!]${NC} $1"; }
err()   { echo -e "${RED} [X]${NC} $1"; }
line()  { echo -e "${GRAY}------------------------------------------------${NC}"; }

# --------------------------------------------------
# Docker Compose helper
# --------------------------------------------------
dc() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
  else
    err "Docker Compose not found"
    exit 1
  fi
}

# --------------------------------------------------
# Banner
# --------------------------------------------------
clear
echo -e "${ORANGE}"
cat <<'EOF'
   _____ _                       _____ _             _
  / ____(_)                     / ____| |           | |
 | |  __ _ _ __   __ _  ___ _ _| (___ | |_ __ _  ___| | __
 | | |_ | | '_ \ / _` |/ _ \ '__\___ \| __/ _` |/ __| |/ /
 | |__| | | | | | (_| |  __/ |  ____) | || (_| | (__|   <
  \_____|_|_| |_|\__, |\___|_| |_____/ \__\__,_|\___|_|\_\
                  __/ |
                 |___/

                GingerStack Uninstaller
EOF
echo -e "${NC}"

warn "This will completely remove GingerStack from your system."
warn "Media deletion is optional and explicitly confirmed."
echo

# --------------------------------------------------
# Detection (matches install.sh)
# --------------------------------------------------
INST_TRAEFIK=false
INST_PORTAINER=false
INST_LAMP=false
INST_JELLYFIN=false
INST_SEEDBOX=false
INST_IMMICH=false
INST_MAIL=false
INST_WIREGUARD=false
INST_HONEYPOT=false
INST_NETWORK=false
INST_DOWNLOADS=false

has_container() {
  docker ps -a --format '{{.Names}} {{.Labels}}' | grep -Eqi "$1"
}

has_container 'traefik'        && INST_TRAEFIK=true
has_container 'portainer'      && INST_PORTAINER=true
has_container 'jellyfin'       && INST_JELLYFIN=true
has_container 'qbittorrent'    && INST_SEEDBOX=true
has_container 'immich'         && INST_IMMICH=true
has_container 'poste|roundcube|mailserver' && INST_MAIL=true
has_container 'wireguard'      && INST_WIREGUARD=true
has_container 'cowrie'         && INST_HONEYPOT=true

[[ -d /root/apps/lamp      ]] && INST_LAMP=true
[[ -d /root/apps/traefik   ]] && INST_TRAEFIK=true
[[ -d /root/apps/immich    ]] && INST_IMMICH=true
[[ -d /root/apps/wireguard ]] && INST_WIREGUARD=true
[[ -d /root/apps/cowrie    ]] && INST_HONEYPOT=true

docker network inspect proxy >/dev/null 2>&1 && INST_NETWORK=true
[[ -d /root/downloads ]] && INST_DOWNLOADS=true

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo -e "${WHITE}Detected GingerStack components:${NC}\n"

show() {
  if [[ "$2" == true ]]; then
    echo -e "  ${GREEN}✓${NC} ${WHITE}$1${NC}"
  else
    echo -e "  ${GRAY}✕${NC} ${GRAY}$1${NC}"
  fi
}

show "Traefik reverse proxy"     $INST_TRAEFIK
show "Portainer"                $INST_PORTAINER
show "LAMP stack"               $INST_LAMP
show "Jellyfin"                 $INST_JELLYFIN
show "Seedbox (qBittorrent)"    $INST_SEEDBOX
show "Immich"                   $INST_IMMICH
show "Mail server + Webmail"    $INST_MAIL
show "WireGuard VPN"            $INST_WIREGUARD
show "SSH Honeypot (Cowrie)"    $INST_HONEYPOT
show "Docker network (proxy)"   $INST_NETWORK
show "Downloads directory"      $INST_DOWNLOADS

echo
line
echo

# --------------------------------------------------
# Media choice
# --------------------------------------------------
echo -e "${WHITE}Media handling:${NC}\n"
echo -e "  ${GREEN}1)${NC} Keep /root/downloads"
echo -e "  ${RED}2)${NC} Permanently delete /root/downloads"
echo -e "  ${AMBER}C)${NC} Cancel\n"

read -rp "Select an option: " MODE

case "${MODE^^}" in
  1) MODE=KEEP ;;
  2) MODE=DELETE ;;
  C) warn "Uninstall cancelled."; exit 0 ;;
  *) err "Invalid option"; exit 1 ;;
esac

# --------------------------------------------------
# Docker choice
# --------------------------------------------------
echo
echo -e "${WHITE}Docker handling:${NC}\n"
echo -e "  ${GREEN}K)${NC} Keep Docker installed"
echo -e "  ${RED}R)${NC} Remove Docker completely\n"

read -rp "Select an option: " DOCKER_MODE

case "${DOCKER_MODE^^}" in
  K) DOCKER_MODE=KEEP ;;
  R) DOCKER_MODE=REMOVE ;;
  *) err "Invalid option"; exit 1 ;;
esac

# --------------------------------------------------
# Helpers
# --------------------------------------------------
rm_container() { docker rm -f "$1" >/dev/null 2>&1 || true; }

rm_by_pattern() {
  docker ps -a --format '{{.Names}}' | grep -E "$1" | while read -r c; do
    rm_container "$c"
  done
}

rm_stack() {
  [[ -f "$1/docker-compose.yml" ]] && (cd "$1" && dc down -v) || true
}

purge_docker() {
  echo
  warn "⚠️  FULL DOCKER REMOVAL ⚠️"
  warn "This will remove Docker engine, images, volumes, and config."
  echo
  read -rp "Press ENTER to confirm full Docker removal..." _

  # Hard stop everything Docker-related
  systemctl stop docker docker.socket containerd 2>/dev/null || true
  systemctl disable docker docker.socket containerd 2>/dev/null || true

  # Kill any remaining processes holding namespaces
  pkill -9 dockerd 2>/dev/null || true
  pkill -9 containerd 2>/dev/null || true
  pkill -9 containerd-shim 2>/dev/null || true

  # Force systemd to release leftover scopes
  systemctl daemon-reexec
  systemctl daemon-reload

  # 🔑 THIS is what actually works
  # Recursively unmount overlay2 mounts via findmnt
  findmnt -rn -o TARGET | grep '^/var/lib/docker' | sort -r | while read -r m; do
    umount -Rlf "$m" 2>/dev/null || true
  done

  sync
  sleep 2

  # Now removal is safe
  rm -rf /var/lib/docker \
         /var/lib/containerd \
         /etc/docker \
         /root/.docker

  apt purge -y docker.io docker-ce docker-ce-cli docker-compose docker-compose-plugin containerd >/dev/null 2>&1 || true
  apt autoremove -y --purge >/dev/null 2>&1 || true

  groupdel docker 2>/dev/null || true

  ok "Docker fully removed."
}

# --------------------------------------------------
# Uninstall begins
# --------------------------------------------------
echo
info "Initiating GingerStack removal sequence..."
sleep 1

info "Stopping and removing containers..."
rm_by_pattern 'traefik|portainer|jellyfin|qbittorrent|immich|poste|roundcube|wireguard|cowrie'

info "Dismantling compose stacks..."
rm_stack /root/apps/traefik
rm_stack /root/apps/lamp
rm_stack /root/apps/immich
rm_stack /root/apps/wireguard
rm_stack /root/apps/cowrie

info "Removing application files..."
rm -rf /root/apps

if $INST_NETWORK; then
  info "Removing Docker network proxy..."
  docker network rm proxy >/dev/null 2>&1 || true
fi

if [[ "$MODE" == "DELETE" && "$INST_DOWNLOADS" == true ]]; then
  echo
  warn "⚠️  PERMANENT DATA DELETION ⚠️"
  warn "All files in /root/downloads will be destroyed."
  echo
  read -rp "Press ENTER to confirm permanent deletion..." _
  rm -rf /root/downloads
  ok "Media deleted."
else
  ok "Media preserved at /root/downloads"
fi

if [[ "$DOCKER_MODE" == "REMOVE" ]]; then
  purge_docker
else
  ok "Docker preserved."
fi

echo
line
ok "GingerStack has been completely removed."
echo -e "${WHITE}Your system is now clean and ready for a fresh start.${NC}"
echo -e "${ORANGE}Thank you for using GingerStack.${NC}"
line
echo
