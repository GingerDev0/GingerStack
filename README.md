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
- 🎯 SSH honeypot (Cowrie) for early-stage intrusion visibility
- 🛡️ WireGuard VPN for controlled, private access to internal services
- 🔒 Single-instance installer locking to prevent race conditions
- 🤖 **Integrated AI stack (Ollama + OpenWebUI) with automatic CPU/GPU optimization**

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

If an installer is already running, GingerStack will:
- Refuse execution
- Surface detailed lock ownership information
- Detect and warn on stale or orphaned locks

This guarantees deterministic behavior and protects against race conditions.

### 📁 Automatic directory bootstrap

At startup, the installer validates and prepares all required filesystem paths:

- `lib/`
- Service-specific runtime directories

Missing directories are created automatically and explicitly permissioned to ensure container compatibility:

```
chmod 0777
```

---

## 📦 Included Services

Services are enabled selectively during installation, allowing tailored deployments per host or environment:

- **LAMP Stack** — Apache, PHP, and MySQL for legacy or internal applications  
- **Portainer** — Operational Docker management UI  
- **Jellyfin** — Media streaming platform  
- **qBittorrent** — Managed download / seedbox service  
- **Immich** — Self-hosted photo and video backup platform  
- **Mail Stack** — poste.io with Roundcube webmail
- **Cowrie Honeypot** — SSH attack detection and telemetry
- **WireGuard VPN** — Secure access to internal-only services
- **AI Stack** — Ollama + OpenWebUI for on-prem LLM workloads

---

## 🧠 AI Stack (Ollama + OpenWebUI)

GingerStack provides an **optional, production-integrated AI subsystem** suitable for on-premise inference workloads:

- **Ollama** — Internal-only local LLM runtime
- **OpenWebUI** — Hardened web interface exposed exclusively via Traefik
- **Automatic CPU/GPU capability detection**
- **Automated model acquisition**
- **CPU affinity and threading optimization**
- **Quantized models for efficient CPU inference**
- **HTTPS termination and rate-limited access**
- **Cloudflare-managed DNS and TLS**

Default behavior:
- CPU-only hosts pull optimized quantized models (e.g. `llama3.1:8b-instruct-q4_K_M`)
- GPU-enabled systems automatically deploy full-precision models
- Models are immediately available within OpenWebUI post-install

Access endpoint:
```
https://ai.your-domain.tld
```

Persistent data paths:
```
/root/apps/ollama
/root/apps/openwebui
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

