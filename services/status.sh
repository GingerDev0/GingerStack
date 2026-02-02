#!/usr/bin/env bash
set -e

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
# Write docker-compose.yml (THIS is where YAML lives)
# --------------------------------------------------
cat > "$STATUS_DIR/docker-compose.yml" <<'EOF'
services:
  apache:
    image: php:8.2-apache
    container_name: status-apache
    restart: unless-stopped
    privileged: true
    command: bash -c "a2enmod rewrite headers && apache2-foreground"

    volumes:
      - ./www:/var/www/html

      # ===== Host system telemetry =====
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /proc/net:/host/proc/net:ro
      - /sys/class/net:/host/sys/class/net:ro
      - /sys/block:/host/sys/block:ro
      - /sys/class/thermal:/host/sys/class/thermal:ro

      # Host identity
      - /etc/hostname:/host/hostname:ro
      - /etc/os-release:/host/os-release:ro

      # Disk usage
      - /:/host/root:ro

    networks:
      - proxy

    labels:
      traefik.enable: "true"
      traefik.http.routers.status.rule: "Host(`status.${ZONE_NAME}`)"
      traefik.http.routers.status.entrypoints: "websecure"
      traefik.http.routers.status.tls.certresolver: "cloudflare"
      traefik.http.routers.status.middlewares: "ui-ratelimit@file"

      traefik.http.routers.status-login.rule: "Host(`status.${ZONE_NAME}`) && PathPrefix(`/api/v2/auth`)"
      traefik.http.routers.status-login.entrypoints: "websecure"
      traefik.http.routers.status-login.tls.certresolver: "cloudflare"
      traefik.http.routers.status-login.middlewares: "login-ratelimit@file"
      traefik.http.routers.status-login.service: "status"

      traefik.http.services.status.loadbalancer.server.port: "80"

networks:
  proxy:
    external: true
EOF

# --------------------------------------------------
# Deploy
# --------------------------------------------------
cd "$STATUS_DIR"
docker compose up -d

ok "Status service deployed at https://status.${ZONE_NAME}"
lock_update "Status service installed"