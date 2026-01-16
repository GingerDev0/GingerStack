info "Installing qBittorrent..."
docker rm -f seedbox >/dev/null 2>&1 || true

docker run -d \
  --name seedbox \
  --restart unless-stopped \
  --network proxy \
  -v /root/downloads:/downloads \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.seedbox.rule=Host(\"seedbox.$ZONE_NAME\")" \
  -l "traefik.http.routers.seedbox.entrypoints=websecure" \
  -l "traefik.http.routers.seedbox.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.seedbox.middlewares=ui-ratelimit@file" \
  -l "traefik.http.routers.seedbox-login.rule=Host(\"seedbox.$ZONE_NAME\") && PathPrefix(\"/api/v2/auth\")" \
  -l "traefik.http.routers.seedbox-login.entrypoints=websecure" \
  -l "traefik.http.routers.seedbox-login.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.seedbox-login.middlewares=login-ratelimit@file" \
  -l "traefik.http.routers.seedbox-login.service=seedbox" \
  -l "traefik.http.services.seedbox.loadbalancer.server.port=8080" \
  lscr.io/linuxserver/qbittorrent

sleep 10
QB_LINE=$(docker logs seedbox 2>&1 | grep -i "temporary password" | tail -n 1 || true)

if [[ -n "$QB_LINE" ]]; then
  SEEDBOX_PASS=$(echo "$QB_LINE" | sed 's/.*password is //')
  export SEEDBOX_PASS
fi
