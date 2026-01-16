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
warn "This action is irreversible."
echo

# --------------------------------------------------
# Detection (robust)
# --------------------------------------------------
INST_TRAEFIK=false
INST_PORTAINER=false
INST_LAMP=false
INST_JELLYFIN=false
INST_SEEDBOX=false
INST_IMMICH=false
INST_MAIL=false
INST_NETWORK=false
INST_MOUNTS=false
INST_DOWNLOADS=false

# ---- Containers by name or label ----
has_container() {
  docker ps -a --format '{{.Names}} {{.Labels}}' | grep -Eqi "$1"
}

has_container 'traefik'                     && INST_TRAEFIK=true
has_container 'portainer'                   && INST_PORTAINER=true
has_container 'jellyfin'                    && INST_JELLYFIN=true
has_container 'qbittorrent|seedbox'         && INST_SEEDBOX=true
has_container 'immich'                      && INST_IMMICH=true
has_container 'poste|mailserver|roundcube'  && INST_MAIL=true

# ---- Stacks / files ----
[[ -d /root/apps/lamp    ]] && INST_LAMP=true
[[ -d /root/apps/immich  ]] && INST_IMMICH=true
[[ -d /root/apps/traefik ]] && INST_TRAEFIK=true

# ---- Network ----
docker network inspect proxy >/dev/null 2>&1 && INST_NETWORK=true

# ---- Mounts (robust detection) ----
if mountpoint -q /media/tv 2>/dev/null || \
   mountpoint -q /media/movies 2>/dev/null || \
   grep -qE '^[^#].*\s/media/(tv|movies)\s' /etc/fstab || \
   [[ -d /media/tv || -d /media/movies ]]; then
  INST_MOUNTS=true
fi

# ---- Downloads ----
[[ -d /root/downloads ]] && INST_DOWNLOADS=true

# --------------------------------------------------
# Summary
# --------------------------------------------------
echo -e "${WHITE}Detected GingerStack components:${NC}\n"

show() {
  if [[ "$2" == true ]]; then
    echo -e "  ${GREEN}✓${NC} ${WHITE}$1${NC}"
  else
    echo -e "  ${RED}✕${NC} ${GRAY}$1 (not found)${NC}"
  fi
}

show "Traefik reverse proxy"        $INST_TRAEFIK
show "Portainer"                   $INST_PORTAINER
show "LAMP stack"                  $INST_LAMP
show "Jellyfin"                    $INST_JELLYFIN
show "Seedbox (qBittorrent)"       $INST_SEEDBOX
show "Immich"                      $INST_IMMICH
show "Mail server + Webmail"       $INST_MAIL
show "Docker network (proxy)"      $INST_NETWORK
show "Media bind mounts (/media)"  $INST_MOUNTS
show "Downloads directory"         $INST_DOWNLOADS

echo
line
echo -e "${AMBER}Everything listed above will be removed.${NC}"
line
echo

# --------------------------------------------------
# Choice: uninstall mode
# --------------------------------------------------
echo -e "${WHITE}How would you like to proceed?${NC}\n"
echo -e "  ${GREEN}1)${NC} Uninstall GingerStack"
echo -e "     → Keep all media in ${ORANGE}/root/downloads${NC}\n"
echo -e "  ${RED}2)${NC} Uninstall GingerStack"
echo -e "     → ${RED}Permanently delete ALL media${NC} in /root/downloads\n"
echo -e "  ${AMBER}C)${NC} Cancel and exit\n"

read -rp "Select an option (1, 2, or C): " MODE

case "${MODE^^}" in
  1) MODE="KEEP" ;;
  2) MODE="DELETE" ;;
  C)
    warn "Uninstall cancelled."
    exit 0
    ;;
  *)
    err "Invalid option"
    exit 1
    ;;
esac

# --------------------------------------------------
# Choice: Docker removal
# --------------------------------------------------
echo
echo -e "${WHITE}Docker cleanup options:${NC}\n"
echo -e "  ${GREEN}K)${NC} Keep Docker installed"
echo -e "  ${RED}R)${NC} Remove Docker completely\n"

read -rp "Select an option (K or R): " DOCKER_MODE

case "${DOCKER_MODE^^}" in
  K) DOCKER_MODE="KEEP" ;;
  R) DOCKER_MODE="REMOVE" ;;
  *)
    err "Invalid option"
    exit 1
    ;;
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

  info "Stopping Docker..."
  systemctl stop docker 2>/dev/null || true
  systemctl disable docker 2>/dev/null || true

  info "Removing Docker resources..."
  docker system prune -a --volumes -f >/dev/null 2>&1 || true

  info "Uninstalling Docker..."
  apt purge -y docker.io docker-compose docker-compose-plugin >/dev/null 2>&1 || true
  apt autoremove -y --purge >/dev/null 2>&1 || true

  rm -rf /var/lib/docker /var/lib/containerd /etc/docker /root/.docker
  groupdel docker 2>/dev/null || true

  ok "Docker fully removed."
}

# --------------------------------------------------
# Uninstall begins
# --------------------------------------------------
echo
info "Initiating GingerStack removal sequence..."
sleep 1

# ---- Containers ----
info "Stopping and removing containers..."
rm_by_pattern 'traefik'
rm_by_pattern 'portainer'
rm_by_pattern 'jellyfin'
rm_by_pattern 'qbittorrent|seedbox'
rm_by_pattern 'immich'
rm_by_pattern 'poste|mailserver|roundcube'

# ---- Stacks ----
info "Dismantling compose stacks..."
rm_stack /root/apps/traefik
rm_stack /root/apps/lamp
rm_stack /root/apps/immich

# ---- Files ----
info "Removing application files..."
rm -rf /root/apps

# ---- Network ----
if $INST_NETWORK; then
  info "Removing Docker network proxy..."
  docker network rm proxy >/dev/null 2>&1 || true
fi

# ---- Mounts ----
if $INST_MOUNTS; then
  info "Detaching media mounts..."
  umount /media/tv     >/dev/null 2>&1 || true
  umount /media/movies >/dev/null 2>&1 || true
  sed -i '\#/media/tv#d' /etc/fstab
  sed -i '\#/media/movies#d' /etc/fstab
  rmdir /media/tv /media/movies 2>/dev/null || true
fi

# ---- Media ----
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

# ---- Docker ----
if [[ "$DOCKER_MODE" == "REMOVE" ]]; then
  purge_docker
else
  ok "Docker preserved."
fi

# --------------------------------------------------
# Finale
# --------------------------------------------------
echo
line
ok "GingerStack has been completely removed."
echo -e "${WHITE}Your system is now clean and ready for a fresh start.${NC}"
echo -e "${ORANGE}Thank you for using GingerStack.${NC}"
line
echo
