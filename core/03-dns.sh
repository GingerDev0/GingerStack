title "Ensuring Cloudflare DNS records"

SERVER_IP=$(curl -s https://api.ipify.org)

ensure_a "@"
ensure_a "*"
ensure_a "traefik"
ensure_a "portainer"
ensure_a "pma"
ensure_a "jellyfin"
ensure_a "seedbox"
ensure_a "immich"
ensure_a "mail"
ensure_a "mailadmin"
ensure_a "webmail"
