info "Installing Immich..."

cat > /root/apps/immich/docker-compose.yml <<EOF
services:
  redis:
    image: redis:7-alpine
    networks: [proxy]

  postgres:
    image: tensorchord/pgvecto-rs:pg15-v0.2.0
    environment:
      POSTGRES_PASSWORD: immichpass
      POSTGRES_USER: immich
      POSTGRES_DB: immich
    networks: [proxy]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U immich"]
      interval: 5s
      timeout: 5s
      retries: 10

  server:
    image: ghcr.io/immich-app/immich-server:release
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_started
    environment:
      DB_HOSTNAME: postgres
      DB_USERNAME: immich
      DB_PASSWORD: immichpass
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: redis
    volumes:
      - ./library:/usr/src/app/upload
    networks: [proxy]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(\"immich.$ZONE_NAME\")"
      - "traefik.http.routers.immich.entrypoints=websecure"
      - "traefik.http.routers.immich.tls.certresolver=cloudflare"
      - "traefik.http.routers.immich.middlewares=ui-ratelimit@file"
      - "traefik.http.services.immich.loadbalancer.server.port=3001"
      - "traefik.http.routers.immich-login.rule=Host(\"immich.$ZONE_NAME\") && PathPrefix(\"/api/auth\")"
      - "traefik.http.routers.immich-login.entrypoints=websecure"
      - "traefik.http.routers.immich-login.tls.certresolver=cloudflare"
      - "traefik.http.routers.immich-login.middlewares=login-ratelimit@file"
      - "traefik.http.routers.immich-login.service=immich"
networks:
  proxy:
    external: true
EOF

cd /root/apps/immich && docker compose up -d
