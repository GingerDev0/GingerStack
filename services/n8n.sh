#!/usr/bin/env bash
set -e

info "Installing n8n stack..."

# --------------------------------------------------
# REQUIRED VARIABLES
# --------------------------------------------------
: "${ZONE_NAME:?ZONE_NAME is not set}"
: "${ROOT_DIR:?ROOT_DIR is not set}"
: "${N8N_BASIC_AUTH_USER:?N8N_BASIC_AUTH_USER is not set}"
: "${N8N_BASIC_AUTH_PASS:?N8N_BASIC_AUTH_PASS is not set}"

# --------------------------------------------------
# Paths
# --------------------------------------------------
N8N_DIR="/root/apps/n8n"
DATA_DIR="$N8N_DIR/data"

# --------------------------------------------------
# Directory setup
# --------------------------------------------------
mkdir -p "$DATA_DIR"

# 🔐 FIX: n8n runs as UID 1000 and must write config + encryption key
chown -R 1000:1000 "$DATA_DIR"
chmod -R 700 "$DATA_DIR"

# --------------------------------------------------
# Docker Compose
# --------------------------------------------------
cat > "$N8N_DIR/docker-compose.yml" <<EOF
services:
  n8n:
    container_name: n8n
    image: n8nio/n8n:latest
    restart: unless-stopped
    user: "1000:1000"
    environment:
      N8N_HOST: n8n.${ZONE_NAME}
      N8N_PORT: 5678
      N8N_PROTOCOL: https
      N8N_LISTEN_ADDRESS: 0.0.0.0
      N8N_PATH: /
      N8N_EDITOR_BASE_URL: https://n8n.${ZONE_NAME}
      WEBHOOK_URL: https://n8n.${ZONE_NAME}
      NODE_ENV: production
      N8N_BASIC_AUTH_ACTIVE: "true"
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASS}
      GENERIC_TIMEZONE: UTC
    volumes:
      - ./data:/home/node/.n8n
    networks:
      - proxy
    labels:
      traefik.enable: "true"
      traefik.docker.network: proxy
      traefik.http.routers.n8n.rule: Host(\`n8n.${ZONE_NAME}\`)
      traefik.http.routers.n8n.entrypoints: websecure
      traefik.http.routers.n8n.tls.certresolver: cloudflare
      traefik.http.services.n8n.loadbalancer.server.port: "5678"

networks:
  proxy:
    external: true
EOF

# --------------------------------------------------
# Start stack
# --------------------------------------------------
cd "$N8N_DIR"
docker compose down
docker compose up -d

ok "n8n deployed"
