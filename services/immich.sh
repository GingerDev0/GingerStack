#!/usr/bin/env bash
set -e

info "Installing Immich stack"
lock_update "Installing immich service"

: "${ROOT_DIR:?ROOT_DIR is not set}"
: "${ZONE_NAME:?ZONE_NAME is not set}"

IMMICH_DIR="/root/apps/immich"
UPLOAD_DIR="/mnt/data/immich"
DB_DIR="$IMMICH_DIR/postgres"
ENV_FILE="$IMMICH_DIR/.env"

mkdir -p "$IMMICH_DIR" "$UPLOAD_DIR" "$DB_DIR"

# --------------------------------------------------
# Generate .env with random password (FIRST RUN ONLY)
# --------------------------------------------------
if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -n "$(ls -A "$DB_DIR" 2>/dev/null)" ]]; then
    echo "ERROR: Existing Postgres data detected at $DB_DIR"
    echo "Cannot auto-generate DB password for an existing database."
    echo
    echo "Either:"
    echo "  1) Create $ENV_FILE with the correct DB_PASSWORD"
    echo "  2) OR wipe the database directory to start fresh:"
    echo "     rm -rf $DB_DIR/*"
    exit 1
  fi

  DB_PASSWORD="$(openssl rand -base64 32)"

  cat > "$ENV_FILE" <<EOF
DB_PASSWORD=${DB_PASSWORD}
EOF

  chmod 600 "$ENV_FILE"
  info "Generated .env with random database password"
fi

# --------------------------------------------------
# Write docker-compose.yml
# --------------------------------------------------
cat > "$IMMICH_DIR/docker-compose.yml" <<'EOF'
services:
  immich-server:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-server
    restart: unless-stopped
    env_file: .env

    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started

    volumes:
      - ${UPLOAD_DIR}:/usr/src/app/upload

    environment:
      TZ: UTC
      DB_HOSTNAME: postgres
      DB_PORT: 5432
      DB_USERNAME: immich
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: redis

    networks:
      - internal

    labels:
      traefik.enable: "true"
      traefik.docker.network: internal
      traefik.http.routers.immich.rule: "Host(`immich.${ZONE_NAME}`)"
      traefik.http.routers.immich.entrypoints: websecure
      traefik.http.routers.immich.tls.certresolver: cloudflare
      traefik.http.services.immich.loadbalancer.server.port: "3001"

  immich-microservices:
    image: ghcr.io/immich-app/immich-server:release
    container_name: immich-microservices
    restart: unless-stopped
    env_file: .env

    command: ["start.sh", "microservices"]

    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started

    volumes:
      - ${UPLOAD_DIR}:/usr/src/app/upload

    environment:
      TZ: UTC
      DB_HOSTNAME: postgres
      DB_PORT: 5432
      DB_USERNAME: immich
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: redis

    networks:
      - internal

  redis:
    image: redis:7
    container_name: immich-redis
    restart: unless-stopped
    networks:
      - internal

  postgres:
    image: tensorchord/pgvecto-rs:pg15-v0.2.0
    container_name: immich-postgres
    restart: unless-stopped
    env_file: .env

    environment:
      POSTGRES_USER: immich
      POSTGRES_DB: immich

    volumes:
      - ./postgres:/var/lib/postgresql/data

    networks:
      - internal

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U immich"]
      interval: 5s
      timeout: 5s
      retries: 10
      start_period: 30s

networks:
  internal:
    internal: true
EOF

# --------------------------------------------------
# Deploy
# --------------------------------------------------
cd "$IMMICH_DIR"
UPLOAD_DIR="$UPLOAD_DIR" ZONE_NAME="$ZONE_NAME" docker compose up -d

ok "Immich deployed at https://immich.${ZONE_NAME}"
lock_update "Immich service installed"
