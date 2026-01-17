#!/usr/bin/env bash
set -e

ok "Installing Ollama + OpenWebUI..."

# --------------------------------------------------
# GPU Detection
# --------------------------------------------------
HAS_NVIDIA=0
if command -v nvidia-smi >/dev/null 2>&1; then
  HAS_NVIDIA=1
elif lspci | grep -i nvidia >/dev/null 2>&1; then
  HAS_NVIDIA=1
fi

# --------------------------------------------------
# NVIDIA Driver + Container Toolkit
# --------------------------------------------------
if [[ "$HAS_NVIDIA" -eq 1 ]]; then
  ok "NVIDIA GPU detected"

  if ! command -v nvidia-smi >/dev/null 2>&1; then
    ok "Installing NVIDIA drivers"
    apt update
    apt install -y nvidia-driver
  fi

  if ! docker info | grep -q nvidia; then
    ok "Installing NVIDIA container runtime"
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
      sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' |
      tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt update
    apt install -y nvidia-container-toolkit
    nvidia-ctk runtime configure --runtime=docker
    systemctl restart docker
  fi
else
  warn "No NVIDIA GPU detected — Ollama will run on CPU"
fi

# --------------------------------------------------
# Docker GPU args (SAFE)
# --------------------------------------------------
DOCKER_GPU_ARGS=()
if [[ "$HAS_NVIDIA" -eq 1 ]] && docker info | grep -q nvidia; then
  DOCKER_GPU_ARGS+=(--gpus all)
fi

# --------------------------------------------------
# Cleanup
# --------------------------------------------------
docker rm -f ollama openwebui >/dev/null 2>&1 || true

mkdir -p /root/apps/ollama
mkdir -p /root/apps/openwebui

# --------------------------------------------------
# Ollama (internal only, CPU/GPU tuned)
# --------------------------------------------------
docker run -d \
  --name ollama \
  --restart unless-stopped \
  --network proxy \
  --network-alias ollama \
  "${DOCKER_GPU_ARGS[@]}" \
  -e OLLAMA_NUM_THREADS="$(nproc)" \
  -e OLLAMA_MAX_LOADED_MODELS=1 \
  -e OLLAMA_KEEP_ALIVE=10m \
  -v /root/apps/ollama:/root/.ollama \
  ollama/ollama

# --------------------------------------------------
# Wait for Ollama API
# --------------------------------------------------
ok "Waiting for Ollama API..."
for i in {1..30}; do
  if docker exec ollama ollama list >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# --------------------------------------------------
# Auto-pull models (CPU/GPU optimized)
# --------------------------------------------------
if [[ "$HAS_NVIDIA" -eq 1 ]]; then
  ok "Pulling GPU models"
  MODELS=(
    "llama3.1:8b-instruct"
    "mixtral:8x7b"
  )
else
  ok "Pulling CPU models (optimized)"
  MODELS=(
    "llama3.1:8b-instruct-q4_K_M"
	"phi3:mini"
  )
fi

for model in "${MODELS[@]}"; do
  ok "Pulling model: $model"
  docker exec ollama ollama pull "$model" || warn "Failed to pull $model"
done

# --------------------------------------------------
# OpenWebUI (exposed via Traefik)
# --------------------------------------------------
docker run -d \
  --name openwebui \
  --restart unless-stopped \
  --network proxy \
  -e OLLAMA_BASE_URL=http://ollama:11434 \
  -e WEBUI_AUTH=true \
  -v /root/apps/openwebui:/app/backend/data \
  -l "traefik.enable=true" \
  -l "traefik.docker.network=proxy" \
  -l "traefik.http.routers.ai.rule=Host(\"ai.$ZONE_NAME\")" \
  -l "traefik.http.routers.ai.entrypoints=websecure" \
  -l "traefik.http.routers.ai.tls.certresolver=cloudflare" \
  -l "traefik.http.routers.ai.middlewares=ui-ratelimit@file" \
  -l "traefik.http.services.ai.loadbalancer.server.port=8080" \
  ghcr.io/open-webui/open-webui:main

ok "Ollama + OpenWebUI started"
