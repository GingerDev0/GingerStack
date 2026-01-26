# GingerStack

![Docker](https://img.shields.io/badge/Docker-Containerized-blue)
![Traefik](https://img.shields.io/badge/Traefik-Reverse%20Proxy-blueviolet)
![Cloudflare](https://img.shields.io/badge/Cloudflare-DNS%20%26%20TLS-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

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
- 🧪 **Environment-aware PHP configuration (Production / Development)**
- 🤖 Integrated AI stack (Ollama + OpenWebUI) with automatic CPU/GPU optimization

---

## 🧱 Installer Safety & Reliability

GingerStack is engineered with **infrastructure-grade safeguards** to support reliable, repeatable execution in both fresh and long-lived environments.

### 🔒 Single-instance locking

A robust `flock`-based locking mechanism (`lib/lock.sh`) enforces **single-installer execution**, preventing concurrent runs that could corrupt state or produce partial deployments.

The lockfile captures:
- Active process metadata (PID, PPID)
- Executing user and host
- Start timestamp
- Script path and working directory
- Bash runtime version
- Live execution status

---

## 📦 Included Services

Services are enabled selectively during installation, allowing tailored deployments per host or environment:

- **LAMP Stack** — Apache, PHP, and MySQL using a stock Docker image  
  - Static PHP configuration via `prod.ini` / `dev.ini`
  - No custom PHP builds or version drift
- **Portainer** — Operational Docker management UI  
- **Jellyfin** — Media streaming platform  
- **qBittorrent** — Managed download / seedbox service  
- **Immich** — Self-hosted photo and video backup platform  
- **Mail Stack** — poste.io with Roundcube webmail
- **Cowrie Honeypot** — SSH attack detection and telemetry
- **WireGuard VPN** — Secure access to internal-only services
- **AI Stack** — Ollama + OpenWebUI for on-prem LLM workloads

---

## 🧪 PHP Configuration (LAMP)

When installing LAMP, GingerStack prompts you to select a PHP configuration profile:

```
[1] Production (recommended)
[2] Development
```

### Profiles

**Production**
- Errors hidden from users
- Secure session cookies
- Hardened defaults

**Development**
- Full error reporting
- Higher memory limits
- Unlimited execution time

PHP settings live in:
```
/root/apps/lamp/php/prod.ini
/root/apps/lamp/php/dev.ini
```

Switching profiles later:
```bash
export PHP_ENV=dev
docker compose restart lamp
```

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
   └─ ollama.sh
```

---

## 🔐 Security Notes

- No secrets are stored in the repo  
- Cloudflare token is requested at runtime  
- TLS certificates are stored locally and ignored by git  
- All login endpoints are protected by Traefik rate-limiting middleware  
- AI backend (Ollama) is **never publicly exposed**

---

## 📜 License

MIT — use it, fork it, ship it.

---

Built with ☕ and Docker by **GingerDev0**
