info "Installing base packages..."
apt update
apt install -y docker.io curl ca-certificates jq
systemctl enable docker
systemctl start docker

info "Fixing Docker storage..."
systemctl stop docker || true
mkdir -p /var/lib/docker/tmp
chmod 711 /var/lib/docker /var/lib/docker/tmp
systemctl start docker

if ! docker compose version >/dev/null 2>&1; then
  info "Installing Docker Compose..."
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -sSL https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64 \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

mkdir -p /root/apps/{traefik,lamp/www,jellyfin,immich,mail/poste,n8n/data}
mkdir -p /root/downloads/{tv,movies}
mkdir -p /media/{tv,movies}
