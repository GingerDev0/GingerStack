#!/usr/bin/env bash

info "Installing LAMP stack..."

# --------------------------------------------------
# REQUIRED VARIABLES
# --------------------------------------------------
: "${PHP_VER:?PHP_VER is not set}"
: "${MYSQL_ROOT_PASS:?MYSQL_ROOT_PASS is not set}"

CHANGE_PHP_VERSION="${CHANGE_PHP_VERSION:-n}"

# Feature flags (safe defaults)
ENABLE_OPCACHE="${ENABLE_OPCACHE:-n}"
ENABLE_IONCUBE="${ENABLE_IONCUBE:-n}"
ENABLE_REDIS="${ENABLE_REDIS:-n}"
ENABLE_XDEBUG="${ENABLE_XDEBUG:-n}"
PHP_GRAPHICS="${PHP_GRAPHICS:-gd}"

# --------------------------------------------------
# Paths
# --------------------------------------------------
LAMP_DIR="/root/apps/lamp"
WWW_DIR="$LAMP_DIR/www"
PHP_DIR="$LAMP_DIR/php"
PHP_CONF_DIR="$PHP_DIR/conf.d"

SRC_INDEX="$ROOT_DIR/lib/index.php"
SRC_LOGO="$ROOT_DIR/lib/logo.png"
SRC_FAVICON="$ROOT_DIR/lib/favicon.ico"

# --------------------------------------------------
# Directory setup
# --------------------------------------------------
mkdir -p "$WWW_DIR" "$PHP_CONF_DIR"

# --------------------------------------------------
# Default web files (do not overwrite existing)
# --------------------------------------------------
[[ ! -f "$WWW_DIR/index.php" ]] && cp "$SRC_INDEX" "$WWW_DIR/index.php"
[[ -f "$SRC_LOGO" && ! -f "$WWW_DIR/logo.png" ]] && cp "$SRC_LOGO" "$WWW_DIR/logo.png"
[[ -f "$SRC_FAVICON" && ! -f "$WWW_DIR/favicon.ico" ]] && cp "$SRC_FAVICON" "$WWW_DIR/favicon.ico"

# --------------------------------------------------
# PHP configuration (defaults or user-custom)
# --------------------------------------------------
if [[ ! -f "$PHP_CONF_DIR/custom.ini" ]]; then
cat > "$PHP_CONF_DIR/custom.ini" <<EOF
memory_limit=${PHP_MEMORY_LIMIT:-512M}
upload_max_filesize=${PHP_UPLOAD_MAX:-64M}
post_max_size=${PHP_POST_MAX:-64M}
max_execution_time=${PHP_MAX_EXEC:-300}
display_errors=On
error_reporting=E_ALL
date.timezone=UTC
EOF
fi

# --------------------------------------------------
# PHP Dockerfile (PHP 8+ custom build)
# --------------------------------------------------
if [[ ! -f "$PHP_DIR/Dockerfile" ]]; then
cat > "$PHP_DIR/Dockerfile" <<'EOF'
ARG PHP_VER
FROM php:${PHP_VER}-apache

ARG ENABLE_OPCACHE
ARG ENABLE_IONCUBE
ARG ENABLE_REDIS
ARG ENABLE_XDEBUG
ARG PHP_GRAPHICS

RUN apt-get update && apt-get install -y \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    unzip \
    curl \
    && docker-php-ext-install \
      pdo_mysql \
      mysqli \
      intl \
      zip \
      bcmath \
      exif \
      soap

# Graphics
RUN if [ "$PHP_GRAPHICS" = "imagick" ]; then \
      apt-get install -y libmagickwand-dev && \
      pecl install imagick && docker-php-ext-enable imagick ; \
    else \
      apt-get install -y libpng-dev libjpeg-dev libfreetype6-dev && \
      docker-php-ext-configure gd --with-freetype --with-jpeg && \
      docker-php-ext-install gd ; \
    fi

# OPcache
RUN if [ "$ENABLE_OPCACHE" = "y" ]; then \
      docker-php-ext-install opcache ; \
    fi

# Redis
RUN if [ "$ENABLE_REDIS" = "y" ]; then \
      pecl install redis && docker-php-ext-enable redis ; \
    fi

# Xdebug
RUN if [ "$ENABLE_XDEBUG" = "y" ]; then \
      pecl install xdebug && docker-php-ext-enable xdebug ; \
    fi

# ionCube Loader (PHP 8+)
RUN if [ "$ENABLE_IONCUBE" = "y" ]; then \
      curl -fsSL https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
      | tar xz -C /tmp && \
      PHP_EXT_DIR="$(php -r 'echo ini_get("extension_dir");')" && \
      cp /tmp/ioncube/ioncube_loader_lin_$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;').so "$PHP_EXT_DIR" && \
      echo "zend_extension=ioncube_loader_lin_$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;').so" \
        > /usr/local/etc/php/conf.d/00-ioncube.ini ; \
    fi

RUN rm -rf /var/lib/apt/lists/*
EOF
fi

# --------------------------------------------------
# Docker Compose (regenerate if PHP version changes)
# --------------------------------------------------
if [[ "$CHANGE_PHP_VERSION" =~ ^[Yy]$ || ! -f "$LAMP_DIR/docker-compose.yml" ]]; then
  info "Generating Docker Compose (PHP ${PHP_VER})"

  cat > "$LAMP_DIR/docker-compose.yml" <<EOF
services:
  apache:
    build:
      context: ./php
      args:
        PHP_VER: ${PHP_VER}
        ENABLE_OPCACHE: ${ENABLE_OPCACHE}
        ENABLE_IONCUBE: ${ENABLE_IONCUBE}
        ENABLE_REDIS: ${ENABLE_REDIS}
        ENABLE_XDEBUG: ${ENABLE_XDEBUG}
        PHP_GRAPHICS: ${PHP_GRAPHICS}
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
else
  info "Using existing Docker Compose (PHP unchanged)"
fi

# --------------------------------------------------
# Start / Update stack
# --------------------------------------------------
cd "$LAMP_DIR"

if [[ "$CHANGE_PHP_VERSION" =~ ^[Yy]$ ]]; then
  info "Updating PHP to version ${PHP_VER}"
  docker compose build apache
  docker compose up -d apache
else
  docker compose up -d
fi