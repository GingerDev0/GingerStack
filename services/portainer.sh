info "Installing Portainer..."
docker volume create portainer_data >/dev/null 2>&1 || true
docker rm -f portainer >/dev/null 2>&1 || true

docker run -d \
  --name portainer \
  --restart unless-stopped \
  --network proxy \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.portainer.rule=Host(\"portainer.$ZONE_NAME\")" \
  -l "traefik.http.routers.portainer.entrypoints=websecure" \
  -l "traefik.http.routers.portainer.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.portainer.middlewares=ui-ratelimit@file" \
  -l "traefik.http.routers.portainer-login.rule=Host(\"portainer.$ZONE_NAME\") && PathPrefix(\"/api/auth\")" \
  -l "traefik.http.routers.portainer-login.entrypoints=websecure" \
  -l "traefik.http.routers.portainer-login.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.portainer-login.middlewares=login-ratelimit@file" \
  -l "traefik.http.routers.portainer-login.service=portainer" \
  -l "traefik.http.services.portainer.loadbalancer.server.port=9000" \
  portainer/portainer-ce
