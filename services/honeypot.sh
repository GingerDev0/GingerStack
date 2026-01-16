info "Installing SSH honeypot (Cowrie)..."

docker rm -f ssh-honeypot >/dev/null 2>&1 || true

mkdir -p /root/apps/honeypot/data/lib/cowrie

docker run -d \
  --name ssh-honeypot \
  --restart unless-stopped \
  -p 22:2222 \
  -v /root/apps/honeypot/data:/cowrie/cowrie-git/var \
  cowrie/cowrie:latest

sleep 5

ok "SSH honeypot active on port 22"
ok "Real SSH should now be accessed on your chosen port"
ok "Logs: /root/apps/honeypot/data/log"