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
  -l "traefik.http.routers.jellyfin.middlewares=ui-ratelimit@file" \
  -l "traefik.http.routers.jellyfin-login.rule=Host(\"jellyfin.$ZONE_NAME\") && PathPrefix(\"/Users/Authenticate\")" \
  -l "traefik.http.routers.jellyfin-login.entrypoints=websecure" \
  -l "traefik.http.routers.jellyfin-login.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.jellyfin-login.middlewares=login-ratelimit@file" \
  -l "traefik.http.routers.jellyfin-login.service=jellyfin" \
  -l "traefik.http.services.jellyfin.loadbalancer.server.port=8096" \
  jellyfin/jellyfin
