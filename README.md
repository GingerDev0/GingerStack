# GingerStack

![Docker](https://img.shields.io/badge/Docker-Containerized-blue?logo=docker&logoColor=white)
![Traefik](https://img.shields.io/badge/Traefik-Reverse%20Proxy-blueviolet?logo=traefikproxy&logoColor=white)
![Cloudflare](https://img.shields.io/badge/Cloudflare-DNS%20%26%20TLS-orange?logo=cloudflare&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green?logo=open-source-initiative&logoColor=white)

A **modular, infrastructure-focused, self-hosted server stack installer** designed for **repeatable, production-grade deployments** with automated DNS, TLS, and container lifecycle management.

Built for:
- Docker + Docker Compose  
- Traefik reverse proxy  
- Cloudflare DNS automation  
- Deterministic, re-runnable service modules  

---

## ✨ Features

- 🔐 Automated HTTPS using Traefik with Cloudflare DNS-01 challenges  
- 🧩 Strictly modular service architecture (one service = one installer unit)  
- 🔁 Idempotent installs — services can be safely re-run or repaired  
- 🐳 Container-first design with zero host-level dependency pollution  
- 🚀 Git-safe by default (no secrets committed, runtime-only credentials)  
- 🛡️ Integrated edge protection via Traefik rate-limiting middleware
- 🔒 Single-instance installer locking to prevent race conditions
- 🧪 Environment-aware PHP configuration (Production / Development)
- 🤖 Integrated AI stack (Ollama + OpenWebUI) with automatic CPU/GPU optimization
- 🔗 Secure automation workflows via **n8n**, protected behind Traefik and HTTPS

---

## 📦 Included Services

Services are enabled selectively during installation, allowing tailored deployments per host or environment:

- **LAMP Stack** — Apache, PHP, and MySQL  
- **Portainer** — Docker management UI  
- **Jellyfin** — Media streaming  
- **qBittorrent** — Seedbox service  
- **Immich** — Photo & video backup  
- **Mail Stack** — poste.io + webmail  
- **Cowrie Honeypot** — SSH attack detection  
- **WireGuard VPN** — Secure remote access  
- **AI Stack** — Ollama + OpenWebUI  
- **n8n** — Workflow automation platform 

---

## ⚡ Quick Start

```bash
git clone https://github.com/GingerDev0/GingerStack.git
cd GingerStack
chmod +x install.sh
./install.sh
```

---

## 📁 Project Structure

```
.
├─ install.sh
├─ lib/
├─ core/
└─ services/
   ├─ lamp.sh
   ├─ portainer.sh
   ├─ jellyfin.sh
   ├─ seedbox.sh
   ├─ immich.sh
   ├─ mail.sh
   ├─ honeypot.sh
   ├─ wireguard.sh
   ├─ ollama.sh
   └─ n8n.sh
```

---

## 🔐 Security Notes

- No secrets are stored in the repository  
- Cloudflare API token is requested at runtime  
- TLS certificates are stored locally and ignored by git  
- All dashboards and login endpoints are protected by rate limiting  
- Internal-only services are never exposed publicly  

---

## 📜 License

MIT — use it, fork it, ship it.

---

Built with ☕ and Docker by **GingerDev0**
