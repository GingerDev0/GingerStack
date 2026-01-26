#!/usr/bin/env bash
set -e

title "Installing Mail Stack"

# -------------------------------------------------------------------
# REQUIREMENTS
# -------------------------------------------------------------------
# ZONE_NAME=example.com
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# CLEANUP
# -------------------------------------------------------------------
docker rm -f mailserver roundcube >/dev/null 2>&1 || true

# -------------------------------------------------------------------
# MAILSERVER (POSTE.IO)
# -------------------------------------------------------------------
docker run -d \
  --name mailserver \
  --restart unless-stopped \
  --hostname mail \
  --domainname "$ZONE_NAME" \
  --network proxy \
  -p 25:25 \
  -p 465:465 \
  -p 587:587 \
  -p 993:993 \
  -v /root/apps/mail/poste:/data \
  -v /root/GingerStack/lib/ssl:/certs:ro \
  -e LETSENCRYPT=OFF \
  -e SSL_TYPE=external \
  -e SSL_CERT=/certs/mail.$ZONE_NAME.crt \
  -e SSL_KEY=/certs/mail.$ZONE_NAME.key \
  -e HTTPS=OFF \
  -e HTTP_PORT=80 \
  -e TRUSTED_PROXIES=172.16.0.0/12 \
  -l "traefik.enable=true" \
  -l "traefik.http.routers.mailadmin.rule=Host(\"mailadmin.$ZONE_NAME\")" \
  -l "traefik.http.routers.mailadmin.entrypoints=websecure" \
  -l "traefik.http.routers.mailadmin.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.mailadmin.middlewares=ui-ratelimit@file" \
  -l "traefik.http.routers.mailadmin-login.rule=Host(\"mailadmin.$ZONE_NAME\") && PathPrefix(\"/login\")" \
  -l "traefik.http.routers.mailadmin-login.entrypoints=websecure" \
  -l "traefik.http.routers.mailadmin-login.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.mailadmin-login.middlewares=login-ratelimit@file" \
  -l "traefik.http.routers.mailadmin-login.service=mailadmin" \
  -l "traefik.http.services.mailadmin.loadbalancer.server.port=80" \
  -l "traefik.http.routers.mailcert.rule=Host(\"mail.$ZONE_NAME\")" \
  -l "traefik.http.routers.mailcert.entrypoints=websecure" \
  -l "traefik.http.routers.mailcert.tls.certresolver=cloudflare" \
  analogic/poste.io

# -------------------------------------------------------------------
# DNS RECORDS (Cloudflare TXT must be quoted)
# -------------------------------------------------------------------
ensure_mx
ensure_txt "@" "\"v=spf1 mx ~all\""
ensure_txt "_dmarc" "\"v=DMARC1; p=quarantine; rua=mailto:dmarc@$ZONE_NAME\""

# -------------------------------------------------------------------
# ROUNDCUBE
# -------------------------------------------------------------------
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
  -l "traefik.http.routers.roundcube.middlewares=ui-ratelimit@file" \
  -l "traefik.http.routers.roundcube-login.rule=Host(\"webmail.$ZONE_NAME\") && PathPrefix(\"/?_task=login\")" \
  -l "traefik.http.routers.roundcube-login.entrypoints=websecure" \
  -l "traefik.http.routers.roundcube-login.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.roundcube-login.middlewares=login-ratelimit@file" \
  -l "traefik.http.routers.roundcube-login.service=roundcube" \
  -l "traefik.http.services.roundcube.loadbalancer.server.port=80" \
  roundcube/roundcubemail
