info "Installing LAMP stack..."

cat > /root/apps/lamp/docker-compose.yml <<EOF
services:
  apache:
    image: php:$PHP_VER-apache
    restart: unless-stopped
    volumes:
      - ./www:/var/www/html
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.lamp.rule=Host(\"$ZONE_NAME\")"
      - "traefik.http.routers.lamp.entrypoints=websecure"
      - "traefik.http.routers.lamp.tls.certresolver=cloudflare"
      - "traefik.http.routers.lamp.middlewares=ui-ratelimit@file"

  db:
    image: mysql:8
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: $MYSQL_ROOT_PASS
    networks:
      - proxy

  pma:
    image: phpmyadmin
    restart: unless-stopped
    environment:
      PMA_HOST: db
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pma.rule=Host(\"pma.$ZONE_NAME\")"
      - "traefik.http.routers.pma.entrypoints=websecure"
      - "traefik.http.routers.pma.tls.certresolver=cloudflare"
      - "traefik.http.routers.pma.middlewares=ui-ratelimit@file"
      - "traefik.http.routers.pma-login.rule=Host(\"pma.$ZONE_NAME\") && Path(\"/index.php\")"
      - "traefik.http.routers.pma-login.entrypoints=websecure"
      - "traefik.http.routers.pma-login.tls.certresolver=cloudflare"
      - "traefik.http.routers.pma-login.middlewares=login-ratelimit@file"
      - "traefik.http.routers.pma-login.service=pma"
      - "traefik.http.services.pma.loadbalancer.server.port=80"

networks:
  proxy:
    external: true
EOF

cd /root/apps/lamp && docker compose up -d
