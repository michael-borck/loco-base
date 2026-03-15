#!/bin/bash
# ══════════════════════════════════════════════
# Machine Setup — Main Installer
# Usage: sudo -E ./install.sh  (or run as root with SETUP_USER set)
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.env"

export SCRIPT_DIR MACHINE_NAME SETUP_USER

# Colors for output
G='\033[1;32m'  # green
C='\033[1;36m'  # cyan
R='\033[0m'     # reset

step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }
ok()   { echo -e "  ${G}✓${R} $1"; }
skip() { echo -e "  - $1 (skipped)"; }

# Must run as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Please run with: sudo -E bash install.sh"
    exit 1
fi

USER_HOME=$(eval echo "~$SETUP_USER")

# ── Step 1: Temporary NOPASSWD sudo ──
step "Setting up temporary NOPASSWD sudo"
echo "$SETUP_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/${SETUP_USER}-nopasswd
chmod 440 /etc/sudoers.d/${SETUP_USER}-nopasswd
ok "NOPASSWD sudo enabled (remove at end with: sudo rm /etc/sudoers.d/${SETUP_USER}-nopasswd)"

# ── Step 2: Packages ──
step "Installing packages"
bash "$SCRIPT_DIR/scripts/01-packages.sh"

# ── Step 3: NVIDIA ──
step "NVIDIA drivers"
if [ "$NVIDIA_ENABLE" = true ]; then
    bash "$SCRIPT_DIR/scripts/02-nvidia.sh"
else
    skip "NVIDIA"
fi

# ── Step 4: Plymouth ──
step "Plymouth boot splash"
if [ "$PLYMOUTH_ENABLE" = true ]; then
    bash "$SCRIPT_DIR/scripts/03-plymouth.sh"
else
    skip "Plymouth"
fi

# ── Step 5: MOTD ──
step "MOTD"
if [ "$MOTD_ENABLE" = true ]; then
    bash "$SCRIPT_DIR/scripts/04-motd.sh"
else
    skip "MOTD"
fi

# ── Step 6: GRUB ──
step "GRUB splash config"
bash "$SCRIPT_DIR/scripts/05-grub.sh"

# ── Step 7: Autologin ──
step "Autologin"
if [ "$AUTOLOGIN_ENABLE" = true ]; then
    bash "$SCRIPT_DIR/scripts/06-autologin.sh"
else
    skip "Autologin"
fi

# ── Step 8: Dashboard ──
step "tmux dashboard"
if [ "$DASHBOARD_ENABLE" = true ]; then
    bash "$SCRIPT_DIR/scripts/07-dashboard.sh"
else
    skip "Dashboard"
fi

# ── Step 9: Bash prompt ──
step "Bash prompt"
bash "$SCRIPT_DIR/scripts/08-prompt.sh"

# ── Step 10: Hardening ──
step "Hardening"
bash "$SCRIPT_DIR/scripts/09-harden.sh"

# ── Done ──
step "SETUP COMPLETE"
echo ""
echo "  Machine: $MACHINE_NAME"
echo "  User:    $SETUP_USER"
echo ""
echo "  Next steps:"
echo "    1. Reboot to verify Plymouth + autologin + dashboard"
echo "    2. After verifying, remove NOPASSWD sudo:"
echo "       sudo rm /etc/sudoers.d/${SETUP_USER}-nopasswd"
echo ""
