info "Installing Jellyfin..."
docker rm -f jellyfin >/dev/null 2>&1 || true
docker run -d \
  --name jellyfin \
  --restart unless-stopped \
  --network proxy \
  -v /root/apps/jellyfin:/config \
  -v /media:/media \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.jellyfin.rule=Host(\"jellyfin.$ZONE_NAME\")" \
  -l "traefik.http.routers.jellyfin.entrypoints=websecure" \
  -l "traefik.http.routers.jellyfin.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.jellyfin.middlewares=login-ratelimit@file" \
  -l "traefik.http.services.jellyfin.loadbalancer.server.port=8096" \
  jellyfin/jellyfin
