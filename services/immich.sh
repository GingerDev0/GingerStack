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

  server:
    image: ghcr.io/immich-app/immich-server:release
    environment:
      DB_HOSTNAME: postgres
      DB_USERNAME: immich
      DB_PASSWORD: immichpass
      DB_DATABASE_NAME: immich
      REDIS_HOSTNAME: redis
    volumes: [ "./library:/usr/src/app/upload" ]
    networks: [proxy]
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.immich.rule=Host(\"immich.$ZONE_NAME\")"
      - "traefik.http.routers.immich.entrypoints=websecure"
      - "traefik.http.routers.immich.tls.certresolver=cloudflare"
      - "traefik.http.routers.immich.middlewares=login-ratelimit@file"
      - "traefik.http.services.immich.loadbalancer.server.port=3001"
networks:
  proxy:
    external: true
EOF

cd /root/apps/immich && dc up -d
