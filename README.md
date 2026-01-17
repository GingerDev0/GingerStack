# GingerStack

A modular, self-hosted server stack installer with automatic DNS, SSL, and container management.

Built for:
- Docker + Docker Compose  
- Traefik reverse proxy  
- Cloudflare DNS automation  
- Clean, re-runnable service modules  

---

## ✨ Features

- 🔐 Automatic HTTPS via Traefik + Cloudflare DNS challenge  
- 🧩 Modular architecture (one service = one file)  
- 🔁 Safe to re-run individual services  
- 🐳 Docker-first, no host pollution  
- 🚀 Git-friendly (no secrets committed)  
- 🛡️ Built-in brute-force protection via Traefik rate-limit middleware
- 🎯 SSH Honeypot with Cowrie for early attack detection
- 🛡️ WireGuard VPN for secure remote access
- 🔒 Single-instance installer locking with rich diagnostics
- 🧾 Full install logging with timestamped log files
- 🤖 **AI Stack with Ollama + OpenWebUI (CPU/GPU auto-optimized)**

---

## 🧱 Installer Safety & Reliability

GingerStack includes **production-grade installer safeguards** to ensure safe, repeatable runs.

### 🔒 Single-instance locking

The installer uses a robust `flock`-based locking system (`lib/lock.sh`) to prevent multiple installs from running at the same time.

The lockfile records:
- PID and parent PID
- User and hostname
- Start timestamp
- Script path and working directory
- Bash version
- Live progress updates

If another installer is already running, GingerStack will:
- Refuse to start
- Show who is holding the lock
- Detect and warn about stale locks

This prevents race conditions, partial installs, and corrupted state.

### 🧾 Full install logging

Every installer run generates a full log file:

```
logs/install-YYYYMMDD-HHMMSS.log
```

- All stdout and stderr are captured
- Output is still streamed to the terminal
- Logs survive crashes and reboots
- The active logfile path is recorded in the lockfile

### 📁 Automatic directory bootstrap

On startup, the installer ensures all required directories exist and are writable:

- `lib/`
- `logs/`
- runtime directories created by services

Missing directories are automatically created and explicitly set to:

```
chmod 0777
```

---

## 📦 Included Services

You can enable any of these during install:

- **LAMP Stack** — Apache + PHP + MySQL  
- **Portainer** — Docker management UI  
- **Jellyfin** — Media streaming server  
- **qBittorrent** — Seedbox / download manager  
- **Immich** — Photo & video backup platform  
- **Mail Stack** — poste.io + Roundcube webmail
- **Cowrie Honeypot** — SSH attack detection and logging
- **WireGuard VPN** — Secure remote access to internal services
- **AI Stack** — Ollama + OpenWebUI (local LLMs)

---

## 🧠 AI Stack (Ollama + OpenWebUI)

GingerStack includes an **optional, fully integrated AI stack**:

- **Ollama** — Local LLM runtime (internal-only, never exposed)
- **OpenWebUI** — Secure web UI exposed via Traefik
- **Automatic CPU/GPU detection**
- **Automatic model pulling**
- **CPU tuning (all cores, optimized threading)**
- **Quantized models for fast CPU inference**
- **HTTPS + rate-limited access via Traefik**
- **Cloudflare DNS + TLS**

Default behavior:
- CPU systems pull optimized quantized models (e.g. `llama3.1:8b-instruct-q4_K_M`)
- GPU systems pull full-precision models automatically
- Models are immediately available in OpenWebUI after install

Access:
```
https://ai.your-domain.tld
```

Data directories:
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
├─ logs/
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
