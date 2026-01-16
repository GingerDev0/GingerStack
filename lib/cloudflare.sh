#!/usr/bin/env bash

CF_API="https://api.cloudflare.com/client/v4"

# --------------------------------------------------
# INTERACTIVE DNS CLEANUP
# --------------------------------------------------
interactive_dns_cleanup() {
  info "Scanning Cloudflare DNS records"

  mapfile -t DNS_ROWS < <(
    curl -s "$CF_API/zones/$ZONE_ID/dns_records?per_page=500" \
      -H "Authorization: Bearer $CF_TOKEN" |
    jq -r '.result[]
      | select(
          .type != "NS"
          and .type != "SOA"
          and .type != "CAA"
      )
      | "\(.id)|\(.type)|\(.name)"'
  )

  if [[ ${#DNS_ROWS[@]} -eq 0 ]]; then
    ok "No deletable DNS records found"
    return 0
  fi

  echo
  echo "Deletable DNS records:"
  i=1
  for row in "${DNS_ROWS[@]}"; do
    IFS="|" read -r ID TYPE NAME <<<"$row"
    printf "  [%d] %-6s %s\n" "$i" "$TYPE" "$NAME"
    ((i++))
  done

  echo
  echo "Choose DNS records to delete:"
  echo "  a) delete all"
  echo "  n) delete none"
  echo "  1 3 5) delete selected"
  read -p "Choice: " CHOICE

  if [[ "$CHOICE" == "n" || -z "$CHOICE" ]]; then
    info "Skipping DNS cleanup"
    return 0
  fi

  declare -a DELETE_INDEXES=()

  if [[ "$CHOICE" == "a" ]]; then
    for ((i=1; i<=${#DNS_ROWS[@]}; i++)); do
      DELETE_INDEXES+=("$i")
    done
  else
    for idx in $CHOICE; do
      [[ "$idx" =~ ^[0-9]+$ ]] && DELETE_INDEXES+=("$idx")
    done
  fi

  for idx in "${DELETE_INDEXES[@]}"; do
    row="${DNS_ROWS[$((idx-1))]}"
    IFS="|" read -r ID TYPE NAME <<<"$row"

    warn "Deleting $TYPE record: $NAME"
    curl -s -X DELETE "$CF_API/zones/$ZONE_ID/dns_records/$ID" \
      -H "Authorization: Bearer $CF_TOKEN" \
      >/dev/null
  done

  return 0
}

# --------------------------------------------------
# CREATE A RECORD
# --------------------------------------------------
ensure_a() {
  local NAME="$1"

  info "Creating A record for $NAME"

  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"A\",
      \"name\":\"$NAME\",
      \"content\":\"$SERVER_IP\",
      \"ttl\":120,
      \"proxied\":false
    }" \
    >/dev/null

  return 0
}

# --------------------------------------------------
# CREATE TXT RECORD
# --------------------------------------------------
ensure_txt() {
  local NAME="$1"
  local VALUE="$2"

  info "Creating TXT record for $NAME"

  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"TXT\",
      \"name\":\"$NAME\",
      \"content\":\"$VALUE\"
    }" \
    >/dev/null

  return 0
}

# --------------------------------------------------
# CREATE MX RECORD
# --------------------------------------------------
ensure_mx() {
  info "Creating MX record"

  curl -s -X POST "$CF_API/zones/$ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{
      \"type\":\"MX\",
      \"name\":\"@\",
      \"content\":\"mail.$ZONE_NAME\",
      \"priority\":10
    }" \
    >/dev/null

  return 0
}
