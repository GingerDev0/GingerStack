CF_API="https://api.cloudflare.com/client/v4"

ensure_a() {
  local NAME="$1"
  local FQDN

  [[ "$NAME" == "@" ]] && FQDN="$ZONE_NAME" || FQDN="$NAME.$ZONE_NAME"

  REC=$(curl -s "$CF_API/zones/$ZONE_ID/dns_records?type=A&name=$FQDN" \
    -H "Authorization: Bearer $CF_TOKEN" \
    | jq -r '.result[0].id')

  # Record already exists → SUCCESS
  if [[ "$REC" != "null" && -n "$REC" ]]; then
    ok "$FQDN exists"
    return 0
  fi

  info "Creating A record for $FQDN"

  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$NAME\",\"content\":\"$SERVER_IP\",\"ttl\":120,\"proxied\":false}" \
    >/dev/null

  return 0
}

ensure_txt() {
  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"TXT\",\"name\":\"$1\",\"content\":\"$2\"}" \
    >/dev/null

  return 0
}

ensure_mx() {
  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"MX\",\"name\":\"@\",\"content\":\"mail.$ZONE_NAME\",\"priority\":10}" \
    >/dev/null

  return 0
}
