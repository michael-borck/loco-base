#!/bin/bash
# Install AI/ML foundation: CUDA toolkit, Ollama, Docker, Node.js, HuggingFace CLI
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; Y='\033[1;33m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }
skip() { echo -e "  - $1 (skipped)"; }

export DEBIAN_FRONTEND=noninteractive

CUDA_VER="${CUDA_VERSION:-12-4}"
CUDA_APT_VER="${CUDA_VER//-/.}"     # 12.4 for display
CUDA_PKG_VER="${CUDA_VER//./-}"     # 12-4 for package names

USER_HOME=$(eval echo "~$SETUP_USER")

# ══════════════════════════════════════════════
# CUDA Toolkit
# ══════════════════════════════════════════════
if [ "$CUDA_ENABLE" = true ]; then
    if dpkg -l "cuda-toolkit-${CUDA_PKG_VER}" 2>/dev/null | grep -q '^ii'; then
        ok "CUDA toolkit ${CUDA_APT_VER} already installed"
    else
        echo "  Installing CUDA toolkit ${CUDA_APT_VER}..."

        # Add NVIDIA CUDA repo if not present
        if [ ! -f /etc/apt/sources.list.d/cuda-ubuntu2204-x86_64.list ] && \
           [ ! -f "/etc/apt/sources.list.d/cuda-ubuntu2204-$(dpkg --print-architecture).list" ]; then
            ARCH=$(dpkg --print-architecture)
            DISTRO="ubuntu2204"
            curl -fsSL "https://developer.download.nvidia.com/compute/cuda/repos/${DISTRO}/${ARCH}/cuda-keyring_1.1-1_all.deb" \
                -o /tmp/cuda-keyring.deb
            dpkg -i /tmp/cuda-keyring.deb
            rm -f /tmp/cuda-keyring.deb
            apt-get update -qq
            ok "NVIDIA CUDA apt repo added"
        fi

        apt-get install -y "cuda-toolkit-${CUDA_PKG_VER}" 2>&1 | tail -5
        ok "CUDA toolkit ${CUDA_APT_VER} installed"

        # Add CUDA to PATH if not already there
        CUDA_PROFILE="/etc/profile.d/cuda.sh"
        if [ ! -f "$CUDA_PROFILE" ]; then
            cat > "$CUDA_PROFILE" <<'EOF'
export PATH="/usr/local/cuda/bin${PATH:+:${PATH}}"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
EOF
            ok "CUDA added to system PATH"
        fi
    fi
else
    skip "CUDA toolkit"
fi

# ══════════════════════════════════════════════
# Ollama
# ══════════════════════════════════════════════
if [ "$OLLAMA_ENABLE" = true ]; then
    if command -v ollama &>/dev/null; then
        ok "Ollama already installed ($(ollama --version 2>/dev/null | head -1))"
    else
        echo "  Installing Ollama..."
        curl -fsSL https://ollama.com/install.sh | sh 2>&1 | tail -3
        ok "Ollama installed"
    fi

    # Enable and start service
    if systemctl is-active --quiet ollama 2>/dev/null; then
        ok "Ollama service running"
    else
        systemctl enable --now ollama 2>/dev/null || true
        ok "Ollama service enabled and started"
    fi
else
    skip "Ollama"
fi

# ══════════════════════════════════════════════
# Docker
# ══════════════════════════════════════════════
if [ "$DOCKER_ENABLE" = true ]; then
    if command -v docker &>/dev/null; then
        ok "Docker already installed ($(docker --version 2>/dev/null | head -1))"
    else
        echo "  Installing Docker..."

        # Add Docker repo
        if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
                > /etc/apt/sources.list.d/docker.list
            apt-get update -qq
        fi

        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 | tail -5
        ok "Docker installed"
    fi

    # Add user to docker group
    if id -nG "$SETUP_USER" 2>/dev/null | grep -qw docker; then
        ok "User ${SETUP_USER} already in docker group"
    else
        usermod -aG docker "$SETUP_USER"
        ok "User ${SETUP_USER} added to docker group (log out/in to take effect)"
    fi

    # NVIDIA Container Toolkit (for GPU passthrough to containers)
    if [ "$NVIDIA_ENABLE" = true ]; then
        if dpkg -l nvidia-container-toolkit 2>/dev/null | grep -q '^ii'; then
            ok "NVIDIA Container Toolkit already installed"
        else
            if [ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]; then
                curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
                    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
                curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
                    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
                    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
                apt-get update -qq
            fi
            apt-get install -y nvidia-container-toolkit 2>&1 | tail -3
            nvidia-ctk runtime configure --runtime=docker 2>/dev/null || true
            systemctl restart docker 2>/dev/null || true
            ok "NVIDIA Container Toolkit installed (GPU passthrough to Docker)"
        fi
    fi
else
    skip "Docker"
fi

# ══════════════════════════════════════════════
# Node.js (via NodeSource for current LTS)
# ══════════════════════════════════════════════
if [ "$NODEJS_ENABLE" = true ]; then
    if command -v node &>/dev/null; then
        ok "Node.js already installed ($(node --version 2>/dev/null))"
    else
        echo "  Installing Node.js LTS..."
        NODE_MAJOR="${NODEJS_VERSION:-22}"
        if [ ! -f /etc/apt/sources.list.d/nodesource.list ]; then
            curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - 2>&1 | tail -3
        fi
        apt-get install -y nodejs 2>&1 | tail -3
        ok "Node.js $(node --version) installed"
    fi
else
    skip "Node.js"
fi

# ══════════════════════════════════════════════
# HuggingFace CLI
# ══════════════════════════════════════════════
if [ "$HF_CLI_ENABLE" = true ]; then
    if su - "$SETUP_USER" -c "command -v huggingface-cli" &>/dev/null; then
        ok "HuggingFace CLI already installed"
    else
        echo "  Installing HuggingFace CLI..."
        su - "$SETUP_USER" -c "pip install --quiet huggingface-hub[cli]" 2>&1 | tail -3
        ok "HuggingFace CLI installed"
    fi
else
    skip "HuggingFace CLI"
fi

ok "AI stack setup complete"
