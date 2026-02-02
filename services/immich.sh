#!/usr/bin/env bash
set -e

info "Installing Immich"
lock_update "Installing Immich service"

: "${ROOT_DIR:?ROOT_DIR is not set}"
: "${ZONE_NAME:?ZONE_NAME is not set}"

IMMICH_DIR="/root/apps/immich"
LIBRARY_DIR="$IMMICH_DIR/library"

mkdir -p "$LIBRARY_DIR"

# --------------------------------------------------
# Write docker-compose.yml (single source of truth)
# --------------------------------------------------
cat > "$IMMICH_DIR/docker-compose.yml" <<'EOF'
services:
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    networks:
      - proxy

  postgres:
    image: tensorchord/pgvecto-rs:pg15-v0.2.0
    restart: unless-stopped
    environment:
      POSTGRES_PASSWORD: immichpass
      POSTGRES_USER: immich
      POSTGRES_DB: immich
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U immich"]
      interval: 5s
      timeout: 5s
      retries: 10
    networks:
      - proxy

  machine-learning:
    image: ghcr.io/immich-app/immich-machine-learning:release
    restart: unless-stopped
    networks:
      - proxy

  server:
    image: ghcr.io/immich-app/immich-server:release
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
      machine-learning:
        condition: service_started

    environment:
      DB_HOSTNAME: postgres
      DB_USERNAME: immich
      DB_PASSWORD: immichpass
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: redis
      IMMICH_MACHINE_LEARNING_URL: http://machine-learning:3003

    volumes:
      - ./library:/usr/src/app/upload

    networks:
      - proxy

    labels:
      traefik.enable: "true"

      # Main UI
      traefik.http.routers.immich.rule: "Host(`immich.${ZONE_NAME}`)"
      traefik.http.routers.immich.entrypoints: "websecure"
      traefik.http.routers.immich.tls.certresolver: "cloudflare"
      traefik.http.routers.immich.middlewares: "ui-ratelimit@file"
      traefik.http.routers.immich.service: "immich"

      # Auth endpoints
      traefik.http.routers.immich-login.rule: "Host(`immich.${ZONE_NAME}`) && PathPrefix(`/api/auth`)"
      traefik.http.routers.immich-login.entrypoints: "websecure"
      traefik.http.routers.immich-login.tls.certresolver: "cloudflare"
      traefik.http.routers.immich-login.middlewares: "login-ratelimit@file"
      traefik.http.routers.immich-login.service: "immich"

      # ✅ Correct backend port for Immich v2.5+
      traefik.http.services.immich.loadbalancer.server.port: "2283"

networks:
  proxy:
    external: true
EOF

# --------------------------------------------------
# Deploy
# --------------------------------------------------
cd "$IMMICH_DIR"
docker compose up -d

ok "Immich deployed at https://immich.${ZONE_NAME}"
lock_update "Immich service installed"
