info "Installing Traefik..."

TRAEFIK_DIR="/root/apps/traefik"
TRAEFIK_FILE="$TRAEFIK_DIR/traefik.yml"
TRAEFIK_DYNAMIC="$TRAEFIK_DIR/dynamic.yml"

# ensure base dir
mkdir -p "$TRAEFIK_DIR"

# 🔥 FIX: if traefik.yml exists as a directory, remove it
if [ -d "$TRAEFIK_FILE" ]; then
  warn "$TRAEFIK_FILE is a directory — removing it"
  rm -rf "$TRAEFIK_FILE"
fi

# 🔥 FIX: if dynamic.yml exists as a directory, remove it
if [ -d "$TRAEFIK_DYNAMIC" ]; then
  warn "$TRAEFIK_DYNAMIC is a directory — removing it"
  rm -rf "$TRAEFIK_DYNAMIC"
fi

mkdir -p "$TRAEFIK_DIR/letsencrypt"
touch "$TRAEFIK_DIR/letsencrypt/acme.json"
chmod 600 "$TRAEFIK_DIR/letsencrypt/acme.json"

# --------------------------------------------------
# Traefik static config
# --------------------------------------------------
cat > "$TRAEFIK_FILE" <<EOF
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
  websecure:
    address: ":443"

providers:
  docker:
    exposedByDefault: false
  file:
    filename: /dynamic.yml

certificatesResolvers:
  cloudflare:
    acme:
      email: admin@$ZONE_NAME
      storage: /letsencrypt/acme.json
      dnsChallenge:
        provider: cloudflare

api:
  dashboard: true
EOF

# --------------------------------------------------
# 🔐 Dynamic middleware config (rate limiting)
# --------------------------------------------------
cat > "$TRAEFIK_DYNAMIC" <<'EOF'
http:
  middlewares:

    # 🔐 Strict for login endpoints
    login-ratelimit:
      rateLimit:
        average: 3
        burst: 5

    # 🌐 Relaxed for UI + assets
    ui-ratelimit:
      rateLimit:
        average: 30
        burst: 60
EOF

# --------------------------------------------------
# Docker Compose
# --------------------------------------------------
cat > "$TRAEFIK_DIR/docker-compose.yml" <<EOF
services:
  traefik:
    image: traefik:v3.0
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    environment:
      - CF_DNS_API_TOKEN=$CF_TOKEN
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/traefik.yml:ro
      - ./dynamic.yml:/dynamic.yml:ro
      - ./letsencrypt:/letsencrypt
    command:
      - "--configFile=/traefik.yml"
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(\"traefik.$ZONE_NAME\")"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=cloudflare"
      - "traefik.http.routers.traefik.service=api@internal"
networks:
  proxy:
    external: true
EOF

cd "$TRAEFIK_DIR" && docker compose up -d
