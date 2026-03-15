#!/bin/bash
# Install NVIDIA drivers
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; Y='\033[1;33m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }

export DEBIAN_FRONTEND=noninteractive

VER="${NVIDIA_DRIVER_VERSION:-535}"

# Skip if correct version already installed and working
if command -v nvidia-smi &>/dev/null && nvidia-smi &>/dev/null; then
    INSTALLED_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 | cut -d. -f1)
    if [ "$INSTALLED_VER" = "$VER" ]; then
        ok "NVIDIA ${VER} already installed and working"
        exit 0
    fi
fi

apt-get install -y \
    nvidia-driver-${VER} \
    nvidia-dkms-${VER} \
    nvidia-utils-${VER} 2>&1 | tail -5

# Check if Secure Boot is on
if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
    warn "Secure Boot is ENABLED — NVIDIA DKMS will fail"
    warn "Disable Secure Boot in BIOS, then re-run: sudo dpkg --configure -a"
else
    # Configure any pending packages
    dpkg --configure -a 2>&1 | tail -5
    apt-get install -f -y 2>&1 | tail -1
    ok "NVIDIA ${VER} drivers installed"
fi
