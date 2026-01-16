info "Installing LAMP stack..."

LAMP_DIR="/root/apps/lamp"
WWW_DIR="$LAMP_DIR/www"
PHP_DIR="$LAMP_DIR/php"
PHP_CONF_DIR="$PHP_DIR/conf.d"

SRC_INDEX="$ROOT_DIR/lib/index.php"
SRC_LOGO="$ROOT_DIR/lib/logo.png"
SRC_FAVICON="$ROOT_DIR/lib/favicon.ico"

# -------------------------------------------------------------------
# Directory setup
# -------------------------------------------------------------------
mkdir -p "$WWW_DIR" "$PHP_CONF_DIR"

# -------------------------------------------------------------------
# Default web files (do not overwrite existing)
# -------------------------------------------------------------------
[[ ! -f "$WWW_DIR/index.php" ]] && cp "$SRC_INDEX" "$WWW_DIR/index.php"
[[ -f "$SRC_LOGO" && ! -f "$WWW_DIR/logo.png" ]] && cp "$SRC_LOGO" "$WWW_DIR/logo.png"
[[ -f "$SRC_FAVICON" && ! -f "$WWW_DIR/favicon.ico" ]] && cp "$SRC_FAVICON" "$WWW_DIR/favicon.ico"

# -------------------------------------------------------------------
# Default PHP configuration (custom.ini)
# -------------------------------------------------------------------
if [[ ! -f "$PHP_CONF_DIR/custom.ini" ]]; then
cat > "$PHP_CONF_DIR/custom.ini" <<EOF
memory_limit=512M
upload_max_filesize=64M
post_max_size=64M
max_execution_time=300
display_errors=On
error_reporting=E_ALL
date.timezone=UTC
EOF
fi

# -------------------------------------------------------------------
# Docker Compose
# -------------------------------------------------------------------
cat > "$LAMP_DIR/docker-compose.yml" <<EOF
services:
  apache:
    image: php:${PHP_VER}-apache
    restart: unless-stopped
    volumes:
      - ./www:/var/www/html
      - ./php/conf.d:/usr/local/etc/php/conf.d
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lamp.rule=Host(\\"${ZONE_NAME}\\")"
      - "traefik.http.routers.lamp.entrypoints=websecure"
      - "traefik.http.routers.lamp.tls.certresolver=cloudflare"
      - "traefik.http.routers.lamp.middlewares=ui-ratelimit@file"

  db:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASS}
    networks:
      - proxy

  pma:
    image: phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: db
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pma.rule=Host(\\"pma.${ZONE_NAME}\\")"
      - "traefik.http.routers.pma.entrypoints=websecure"
      - "traefik.http.routers.pma.tls.certresolver=cloudflare"
      - "traefik.http.routers.pma.middlewares=ui-ratelimit@file"
      - "traefik.http.routers.pma-login.rule=Host(\\"pma.${ZONE_NAME}\\") && Path(\\"/index.php\\")"
      - "traefik.http.routers.pma-login.entrypoints=websecure"
      - "traefik.http.routers.pma-login.tls.certresolver=cloudflare"
      - "traefik.http.routers.pma-login.middlewares=login-ratelimit@file"
      - "traefik.http.routers.pma-login.service=pma"
      - "traefik.http.services.pma.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
EOF

# -------------------------------------------------------------------
# Start stack
# -------------------------------------------------------------------
cd "$LAMP_DIR" && docker compose up -d
