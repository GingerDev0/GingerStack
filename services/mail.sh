title "Installing Mail Stack"

docker rm -f mailserver roundcube >/dev/null 2>&1 || true

docker run -d \
  --name mailserver \
  --restart unless-stopped \
  --hostname mail \
  --domainname "$ZONE_NAME" \
  --network proxy \
  -p 25:25 -p 465:465 -p 587:587 -p 993:993 \
  -v /root/apps/mail/poste:/data \
  -e HTTPS=OFF \
  -e HTTP_PORT=80 \
  -e TRUSTED_PROXIES=172.16.0.0/12 \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.mailadmin.rule=Host(\"mailadmin.$ZONE_NAME\")" \
  -l "traefik.http.routers.mailadmin.entrypoints=websecure" \
  -l "traefik.http.routers.mailadmin.tls.certresolver=cloudflare" \
  -l "traefik.http.services.mailadmin.loadbalancer.server.port=80" \
  analogic/poste.io

ensure_mx
ensure_txt "@" "v=spf1 mx ~all"
ensure_txt "_dmarc" "v=DMARC1; p=none; rua=mailto:dmarc@$ZONE_NAME"

docker run -d \
  --name roundcube \
  --restart unless-stopped \
  --network proxy \
  -e ROUNDCUBEMAIL_DEFAULT_HOST=tls://mail.$ZONE_NAME \
  -e ROUNDCUBEMAIL_DEFAULT_PORT=993 \
  -e ROUNDCUBEMAIL_SMTP_SERVER=tls://mail.$ZONE_NAME \
  -e ROUNDCUBEMAIL_SMTP_PORT=465 \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.roundcube.rule=Host(\"webmail.$ZONE_NAME\")" \
  -l "traefik.http.routers.roundcube.entrypoints=websecure" \
  -l "traefik.http.routers.roundcube.tls.certresolver=cloudflare" \
  -l "traefik.http.services.roundcube.loadbalancer.server.port=80" \
  roundcube/roundcubemail
