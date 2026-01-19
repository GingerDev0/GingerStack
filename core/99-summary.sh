title "INSTALL COMPLETE"

info "Traefik is handling SSL + routing."
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && info "LAMP web root: /root/apps/lamp/www"

# --------------------------------------------------
# Dashboards
# --------------------------------------------------
if [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ || "$INSTALL_MAIL" =~ ^[Yy]$ || "$INSTALL_WIREGUARD" =~ ^[Yy]$ || "$INSTALL_AI" =~ ^[Yy]$ ]]; then
  echo
  echo "Dashboards:"
  echo " - Traefik:    https://traefik.$ZONE_NAME"
  [[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && echo " - Portainer:  https://portainer.$ZONE_NAME"
  [[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - Mail Admin: https://mailadmin.$ZONE_NAME"
  [[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && echo " - WireGuard:  https://wg.$ZONE_NAME"
  [[ "$INSTALL_AI" =~ ^[Yy]$ ]] && echo " - AI UI:      https://ai.$ZONE_NAME"
fi

# --------------------------------------------------
# Services
# --------------------------------------------------
if [[ "$INSTALL_LAMP" =~ ^[Yy]$ || "$INSTALL_JELLYFIN" =~ ^[Yy]$ || "$INSTALL_SEEDBOX" =~ ^[Yy]$ || "$INSTALL_IMMICH" =~ ^[Yy]$ || "$INSTALL_MAIL" =~ ^[Yy]$ || "$INSTALL_AI" =~ ^[Yy]$ ]]; then
  echo
  echo "Services:"
  [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && echo " - Website:    https://$ZONE_NAME"
  [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && echo " - phpMyAdmin: https://pma.$ZONE_NAME"
  [[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]] && echo " - Jellyfin:   https://jellyfin.$ZONE_NAME"
  [[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]] && echo " - Seedbox:    https://seedbox.$ZONE_NAME"
  [[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]] && echo " - Immich:     https://immich.$ZONE_NAME"
  [[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - Webmail:    https://webmail.$ZONE_NAME"
  [[ "$INSTALL_AI" =~ ^[Yy]$ ]] && echo " - OpenWebUI:  https://ai.$ZONE_NAME"
fi

# --------------------------------------------------
# AI Stack
# --------------------------------------------------
if [[ "$INSTALL_AI" =~ ^[Yy]$ ]]; then
  echo
  echo "AI Stack:"
  echo " - UI:         OpenWebUI"
  echo " - Access:     https://ai.$ZONE_NAME"
  echo " - Backend:    Ollama (internal only)"
  echo " - Storage:"
  echo "     • Models: /root/apps/ollama"
  echo "     • UI:     /root/apps/openwebui"

  echo
  echo "Installed Models:"
  if docker exec ollama ollama list >/dev/null 2>&1; then
    docker exec ollama ollama list | awk 'NR>1 { printf " - %s\n", $1 }'
  else
    echo " - (unable to query Ollama)"
  fi
fi

# --------------------------------------------------
# VPN
# --------------------------------------------------
if [[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]]; then
  echo
  echo "VPN:"
  echo " - WireGuard UDP: 51820"
  echo " - WireGuard UI:  https://wg.$ZONE_NAME"
fi

# --------------------------------------------------
# Mail Services
# --------------------------------------------------
if [[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]; then
  echo
  echo "Mail Services:"
  echo " - SMTP: mail.$ZONE_NAME (465 / 587)"
  echo " - IMAP: mail.$ZONE_NAME (993)"
fi

# --------------------------------------------------
# DNS
# --------------------------------------------------
if [[ "$INSTALL_MAIL" =~ ^[Yy]$ ]]; then
  echo
  echo "DNS:"
  echo " - MX, SPF, DMARC configured"
  echo " - DKIM configured via poste.io"
fi

# --------------------------------------------------
# Directories
# --------------------------------------------------
if [[ "$INSTALL_LAMP" =~ ^[Yy]$ || "$INSTALL_JELLYFIN" =~ ^[Yy]$ || "$INSTALL_IMMICH" =~ ^[Yy]$ || "$INSTALL_MAIL" =~ ^[Yy]$ || "$INSTALL_SEEDBOX" =~ ^[Yy]$ || "$INSTALL_WIREGUARD" =~ ^[Yy]$ || "$INSTALL_AI" =~ ^[Yy]$ ]]; then
  echo
  echo "Directories:"
  [[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && echo " - LAMP web root:        /root/apps/lamp/www"
  [[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]] && echo " - Jellyfin config:     /root/apps/jellyfin"
  [[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]] && echo " - Immich library:      /root/apps/immich/library"
  [[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - Mail data:           /root/apps/mail/poste"
  [[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]] && echo " - Seedbox downloads:   /root/downloads"
  [[ "$INSTALL_WIREGUARD" =~ ^[Yy]$ ]] && echo " - WireGuard config:    /root/apps/wireguard"
  [[ "$INSTALL_AI" =~ ^[Yy]$ ]] && echo " - AI models:           /root/apps/ollama"
fi

# --------------------------------------------------
# Media Mapping
# --------------------------------------------------
if [[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]]; then
  echo
  echo "Media Mapping:"
  echo " - /root/downloads/movies  ->  /media/movies  ->  Jellyfin"
  echo " - /root/downloads/tv      ->  /media/tv      ->  Jellyfin"
fi

# --------------------------------------------------
# Security
# --------------------------------------------------
if [[ "$INSTALL_HONEYPOT" =~ ^[Yy]$ ]]; then
  echo
  echo "Security:"
  echo " - SSH honeypot active on port 22"
  [[ -n "$SSH_PORT" ]] && echo " - Real SSH configured on port $SSH_PORT"
  echo
  echo "To change your real SSH port:"
  echo "  1) Edit config:  nano /etc/ssh/sshd_config"
  echo "  2) Set:          Port <your-port>"
  echo "  3) Restart SSH: systemctl restart ssh"
  echo
  echo "Test with: ssh -p <your-port> user@server"
fi

# --------------------------------------------------
# Seedbox Credentials
# --------------------------------------------------
if [[ -n "$SEEDBOX_PASS" ]]; then
  echo
  echo "=========================================="
  echo " qBittorrent Web UI Credentials"
  echo "------------------------------------------"
  echo " URL:      https://seedbox.$ZONE_NAME"
  echo " Username: admin"
  echo " Password: $SEEDBOX_PASS"
  echo "=========================================="
fi

# --------------------------------------------------
# STATUS INSTALL
# --------------------------------------------------
if [[ -n "$INSTALL_STATUS" ]]; then
  echo
  echo "=========================================="
  echo " Status page installed"
  echo "------------------------------------------"
  echo " URL:      https://status.$ZONE_NAME"
  echo "=========================================="
fi

echo
ok "All services are up and running!"
