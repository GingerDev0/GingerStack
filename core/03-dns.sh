title "Ensuring Cloudflare DNS records"

SERVER_IP=$(curl -s https://api.ipify.org)

ensure_a "@"
ensure_a "traefik"

[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && ensure_a "portainer"

[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && ensure_a "pma"

[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]] && ensure_a "jellyfin"

[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]] && ensure_a "seedbox"

[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]] && ensure_a "immich"

[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && {
  ensure_a "mail"
  ensure_a "mailadmin"
  ensure_a "webmail"
  ensure_mx
}

# ✅ CRITICAL: never let a sourced script return non-zero
return 0
