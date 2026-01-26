#!/usr/bin/env bash

info "Installing LAMP stack..."

# --------------------------------------------------
# REQUIRED VARIABLES
# --------------------------------------------------
: "${MYSQL_ROOT_PASS:?MYSQL_ROOT_PASS is not set}"
: "${ZONE_NAME:?ZONE_NAME is not set}"

PHP_ENV="${PHP_ENV:-prod}"

# --------------------------------------------------
# Paths
# --------------------------------------------------
LAMP_DIR="/root/apps/lamp"
WWW_DIR="$LAMP_DIR/www"
PHP_DIR="$LAMP_DIR/php"

PHP_INI_PROD="$PHP_DIR/prod.ini"
PHP_INI_DEV="$PHP_DIR/dev.ini"

SRC_INDEX="$ROOT_DIR/lib/index.php"
SRC_LOGO="$ROOT_DIR/lib/logo.png"
SRC_FAVICON="$ROOT_DIR/lib/favicon.ico"

# --------------------------------------------------
# Directory setup
# --------------------------------------------------
mkdir -p "$WWW_DIR" "$PHP_DIR"

# --------------------------------------------------
# Default web files (do not overwrite existing)
# --------------------------------------------------
[[ ! -f "$WWW_DIR/index.php" ]] && cp "$SRC_INDEX" "$WWW_DIR/index.php"
[[ -f "$SRC_LOGO" && ! -f "$WWW_DIR/logo.png" ]] && cp "$SRC_LOGO" "$WWW_DIR/logo.png"
[[ -f "$SRC_FAVICON" && ! -f "$WWW_DIR/favicon.ico" ]] && cp "$SRC_FAVICON" "$WWW_DIR/favicon.ico"

# --------------------------------------------------
# PHP.ini profiles (static, no prompts)
# --------------------------------------------------

if [[ ! -f "$PHP_INI_PROD" ]]; then
cat > "$PHP_INI_PROD" <<'EOF'
; GingerStack PHP – Production

memory_limit = 512M
upload_max_filesize = 64M
post_max_size = 64M
max_execution_time = 300

display_errors = Off
log_errors = On
error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT
expose_php = Off

date.timezone = UTC

session.cookie_httponly = 1
session.cookie_secure = 1
cgi.fix_pathinfo = 0
EOF
fi

if [[ ! -f "$PHP_INI_DEV" ]]; then
cat > "$PHP_INI_DEV" <<'EOF'
; GingerStack PHP – Development

memory_limit = 1024M
upload_max_filesize = 128M
post_max_size = 128M
max_execution_time = 0

display_errors = On
log_errors = On
error_reporting = E_ALL
expose_php = On

date.timezone = UTC
EOF
fi

# --------------------------------------------------
# Select PHP.ini profile
# --------------------------------------------------
case "$PHP_ENV" in
  dev)
    PHP_INI_FILE="./php/dev.ini"
    ;;
  *)
    PHP_INI_FILE="./php/prod.ini"
    ;;
esac

info "Using PHP.ini profile: $PHP_ENV"

# --------------------------------------------------
# Docker Compose (default LAMP image)
# --------------------------------------------------
cat > "$LAMP_DIR/docker-compose.yml" <<EOF
services:
  lamp:
    image: bitnami/lamp:latest
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASS}
      ALLOW_EMPTY_PASSWORD: "no"
    volumes:
      - ./www:/app
      - ${PHP_INI_FILE}:/opt/bitnami/php/etc/conf.d/99-custom.ini
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lamp.rule=Host(\\"${ZONE_NAME}\\")"
      - "traefik.http.routers.lamp.entrypoints=websecure"
      - "traefik.http.routers.lamp.tls.certresolver=cloudflare"
      - "traefik.http.routers.lamp.middlewares=ui-ratelimit@file"
      - "traefik.http.services.lamp.loadbalancer.server.port=8080"

  pma:
    image: phpmyadmin:latest
    restart: unless-stopped
    environment:
      PMA_HOST: lamp
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pma.rule=Host(\\"pma.${ZONE_NAME}\\")"
      - "traefik.http.routers.pma.entrypoints=websecure"
      - "traefik.http.routers.pma.tls.certresolver=cloudflare"
      - "traefik.http.routers.pma.middlewares=ui-ratelimit@file"
      - "traefik.http.services.pma.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
EOF

# --------------------------------------------------
# Start stack
# --------------------------------------------------
cd "$LAMP_DIR"
docker compose up -d

ok "LAMP stack deployed (${PHP_ENV} profile)"