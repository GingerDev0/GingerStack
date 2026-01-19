# ==================================================
# Status Service (Apache + PHP + Traefik)
# ==================================================

info "Installing Status stack (Apache + PHP 8.2 + Traefik)"
lock_update "Installing status service"

: "${ROOT_DIR:?ROOT_DIR is not set}"
: "${ZONE_NAME:?ZONE_NAME is not set}"

STATUS_DIR="/root/apps/status"
WWW_DIR="$STATUS_DIR/www"
SRC_STATUS_DIR="$ROOT_DIR/lib/status"

mkdir -p "$WWW_DIR"

# --------------------------------------------------
# Copy status files (non-destructive)
# --------------------------------------------------
if [[ -d "$SRC_STATUS_DIR" ]]; then
  rsync -av --ignore-existing "$SRC_STATUS_DIR/" "$WWW_DIR/"
fi

# --------------------------------------------------
# Docker Compose (Apache + PHP + Traefik)
# --------------------------------------------------
cat > "$STATUS_DIR/docker-compose.yml" <<EOF
services:
  apache:
    image: php:8.2-apache
    container_name: status-apache
    restart: unless-stopped
    privileged: true
    command: bash -c "a2enmod rewrite headers && apache2-foreground"

    volumes:
      # Web files
      - ./www:/var/www/html

      # Host system info (read-only)
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/host/root:ro
      - /etc/hostname:/host/hostname:ro

      # Optional: Docker stats
      # - /var/run/docker.sock:/var/run/docker.sock:ro

    networks:
      - proxy

    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.status.rule=Host(\\"status.${ZONE_NAME}\\")"
      - "traefik.http.routers.status.entrypoints=websecure"
      - "traefik.http.routers.status.tls.certresolver=cloudflare"
      - "traefik.http.services.status.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
EOF

cd "$STATUS_DIR"
docker compose up -d

ok "Status service deployed at https://status.${ZONE_NAME}"
lock_update "Status service installed"
