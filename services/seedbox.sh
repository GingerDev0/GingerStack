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

  # 🔐 Rate-limit middleware
  -l "traefik.http.routers.seedbox.middlewares=login-ratelimit@file" \

  -l "traefik.http.services.seedbox.loadbalancer.server.port=8080" \
  lscr.io/linuxserver/qbittorrent

sleep 10
QB_LINE=$(docker logs seedbox 2>&1 | grep -i "temporary password" | tail -n 1 || true)

if [[ -n "$QB_LINE" ]]; then
  SEEDBOX_PASS=$(echo "$QB_LINE" | sed 's/.*password is //')
  export SEEDBOX_PASS
fi
