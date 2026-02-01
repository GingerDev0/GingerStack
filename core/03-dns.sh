#!/usr/bin/env bash

title "Ensuring Cloudflare DNS records"

# Detect public IP each run
SERVER_IP=$(curl -s https://api.ipify.org)

# --------------------------------------------------
# ASK USER WHAT TO DELETE / KEEP
# --------------------------------------------------
interactive_dns_cleanup

# --------------------------------------------------
# BASE DNS RECORDS
# --------------------------------------------------
ensure_a "@"
ensure_a "traefik"

# --------------------------------------------------
# OPTIONAL SERVICES
# --------------------------------------------------
[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && ensure_a "portainer"

[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && ensure_a "pma"

[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]] && ensure_a "jellyfin"

[[ "$INSTALL_AI" =~ ^[Yy]$ ]] && ensure_a "ai"

[[ "$INSTALL_AI" =~ ^[Yy]$ ]] && ensure_a "ollama"

[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]] && ensure_a "seedbox"

[[ "$INSTALL_N8N" =~ ^[Yy]$ ]] && ensure_a "n8n"

[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]] && ensure_a "immich"

[[ "$INSTALL_STATUS" =~ ^[Yy]$ ]] && ensure_a "status"

# --------------------------------------------------
# MAIL
# --------------------------------------------------
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && {
  ensure_a "mail"
  ensure_a "mailadmin"
  ensure_a "webmail"
  ensure_mx
}

# ✅ CRITICAL: never let a sourced script return non-zero
return 0
