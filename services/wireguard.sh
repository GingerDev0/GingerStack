info "Installing WireGuard..."
docker rm -f wireguard >/dev/null 2>&1 || true

# Ensure WireGuard config directory exists
mkdir -p /root/apps/wireguard

docker run -d \
  --name wireguard \
  --restart unless-stopped \
  --network proxy \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -e SERVERURL=wg.$ZONE_NAME \
  -e SERVERPORT=51820 \
  -e PEERS=1 \
  -e PEERDNS=auto \
  -e INTERNAL_SUBNET=10.13.13.0 \
  -v /root/apps/wireguard:/config \
  -v /lib/modules:/lib/modules:ro \
  -p 51820:51820/udp \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.wireguard.rule=Host(\"wg.$ZONE_NAME\")" \
  -l "traefik.http.routers.wireguard.entrypoints=websecure" \
  -l "traefik.http.routers.wireguard.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.wireguard.middlewares=ui-ratelimit@file" \
  -l "traefik.http.services.wireguard.loadbalancer.server.port=9876" \
  lscr.io/linuxserver/wireguard
