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

This makes debugging, auditing, and post-mortem analysis trivial.

### 📁 Automatic directory bootstrap

On startup, the installer ensures all required directories exist and are writable:

- `lib/`
- `logs/`
- runtime directories created by services

Missing directories are automatically created and explicitly set to:

```
chmod 0777
```

This avoids permission issues on fresh servers, containers, bind mounts, and CI environments.

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
- **Wireguard VPN** — Secure remote access to internal services

---

## ⚡ Quick Start

```bash
git clone https://github.com/GingerDev0/GingerStack.git
cd GingerStack
chmod +x install.sh
./install.sh
```

The installer will:

1. Acquire an exclusive install lock  
2. Ask which services you want  
3. Prompt for a Cloudflare API token  
4. Configure DNS records automatically  
5. Install Docker + Compose if needed  
6. Deploy Traefik and selected services  
7. Write full logs to `logs/`

---

## 📁 Project Structure

```
.
├─ install.sh          # main entrypoint
├─ lib/                # shared helpers
│  ├─ lock.sh          # installer locking + metadata
│  ├─ logging.sh
│  ├─ docker.sh
│  └─ cloudflare.sh
├─ logs/               # install logs
├─ core/               # base system + proxy + dns
│  ├─ 00-base.sh
│  ├─ 01-network.sh
│  ├─ 02-traefik.sh
│  └─ 03-dns.sh
└─ services/           # optional services
   ├─ lamp.sh
   ├─ portainer.sh
   ├─ jellyfin.sh
   ├─ seedbox.sh
   ├─ immich.sh
   ├─ mail.sh
   ├─ honeypot.sh
   └─ wireguard.sh
```

---

## 🕵️ SSH Honeypot (Cowrie)

GingerStack can deploy **Cowrie**, a production-grade SSH honeypot.

- Cowrie listens on **port 22**  
- Your real SSH runs on a **custom port you choose**  
- Attackers hit the honeypot, not your real system  
- All attempts are logged for analysis  

View logs:

```bash
docker logs cowrie
```

---

## 🔐 Security Notes

- No secrets are stored in the repo  
- Cloudflare token is requested at runtime  
- TLS certificates are stored locally and ignored by git  
- All login endpoints are protected by Traefik rate-limiting middleware  
- Installer locking prevents concurrent destructive operations

---

## 🔁 Re-running Services

You can re-run any service at any time:

```bash
bash services/jellyfin.sh
bash services/portainer.sh
bash services/lamp.sh
```

You do **not** need to rerun the whole installer.

---

## 🛠 Requirements

- Ubuntu / Debian-based server  
- Root access  
- A domain using Cloudflare DNS  
- Cloudflare API Token with:  
  - **Zone → DNS → Edit**

---

## 🧠 Philosophy

GingerStack is built around:

- **Modularity over monoliths**  
- **Containers over host installs**  
- **Reproducibility over magic**  
- **Git over zip files**  
- **Security at the edge** with Traefik middleware  
- **Deterministic installs** with locks and logs

---

## 🤝 Contributing

Pull requests are welcome.

Guidelines:

- One service per file in `services/`  
- No secrets in commits  
- Keep scripts idempotent  
- Prefer docker-compose for multi-container stacks  
- Avoid hidden state; log everything

---

## 🧪 Development Workflow

Typical workflow for maintainers:

```bash
git pull
bash services/jellyfin.sh
```

or

```bash
git pull
./install.sh
```

Changes are immediately reflected without reinstalling the system.

---

## 📜 License

MIT — use it, fork it, ship it.

---

Built with ☕ and Docker by **GingerDev0**

