# --------------------------------------------------
# FINAL OUTPUT
# --------------------------------------------------
title "INSTALL COMPLETE"

info "Traefik is handling SSL + routing."
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && info "LAMP web root: /root/apps/lamp/www"

echo
echo "Dashboards:"
echo " - Traefik:    https://traefik.$ZONE_NAME"
[[ "$INSTALL_PORTAINER" =~ ^[Yy]$ ]] && echo " - Portainer:  https://portainer.$ZONE_NAME"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - Mail Admin: https://mailadmin.$ZONE_NAME"

echo
echo "Services:"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && echo " - Website:    https://$ZONE_NAME"
[[ "$INSTALL_LAMP" =~ ^[Yy]$ ]] && echo " - phpMyAdmin: https://pma.$ZONE_NAME"
[[ "$INSTALL_JELLYFIN" =~ ^[Yy]$ ]] && echo " - Jellyfin:   https://jellyfin.$ZONE_NAME"
[[ "$INSTALL_SEEDBOX" =~ ^[Yy]$ ]] && echo " - Seedbox:    https://seedbox.$ZONE_NAME"
[[ "$INSTALL_IMMICH" =~ ^[Yy]$ ]] && echo " - Immich:     https://immich.$ZONE_NAME"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - Webmail:    https://webmail.$ZONE_NAME"

echo
echo "Mail Services:"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - SMTP: mail.$ZONE_NAME (465 / 587)"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - IMAP: mail.$ZONE_NAME (993)"

echo
echo "DNS:"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - MX, SPF, DMARC configured"
[[ "$INSTALL_MAIL" =~ ^[Yy]$ ]] && echo " - DKIM configured via poste.io"

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

echo
ok "All services are up and running!"
