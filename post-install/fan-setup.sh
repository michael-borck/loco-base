#!/bin/bash
# ══════════════════════════════════════════════
# Post-Install: Fan curve configuration
# Runs sensors-detect to find hardware sensors, then pwmconfig
# to set up fan curves. Enables fancontrol service on boot.
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/config.env"

G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; DIM='\033[2m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }
step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }

# ── Check packages ──
for cmd in sensors pwmconfig fancontrol; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "  Missing: $cmd — run 01-packages.sh first (installs lm-sensors + fancontrol)"
        exit 1
    fi
done

step "Fan Curve Setup"

echo ""
echo -e "  ${DIM}This is a two-step process:${R}"
echo -e "  ${DIM}  1. sensors-detect — probes for hardware sensor modules${R}"
echo -e "  ${DIM}  2. pwmconfig     — configures fan speed curves${R}"
echo ""
echo -e "  ${DIM}Both are interactive. Answer the prompts for your hardware.${R}"
echo -e "  ${DIM}When in doubt, accept the defaults (Enter/YES).${R}"
echo ""

read -rp "  Continue? [Y/n]: " confirm
if [[ "$confirm" =~ ^[Nn] ]]; then
    echo "  Aborted."
    exit 0
fi

# ── Step 1: Detect sensors ──
step "Sensor Detection"
echo ""
sensors-detect
echo ""
ok "Sensor detection complete"

# Show detected sensors
echo ""
echo "  Detected sensors:"
sensors 2>/dev/null | head -30
echo ""

# ── Step 2: Configure fan curves ──
step "Fan Curve Configuration (pwmconfig)"
echo ""
echo -e "  ${DIM}pwmconfig will test each fan by cycling it off/on.${R}"
echo -e "  ${DIM}You'll set min/max temperatures and fan speeds.${R}"
echo -e "  ${DIM}Configuration is saved to /etc/fancontrol.${R}"
echo ""

pwmconfig

# ── Step 3: Enable service ──
if [ -f /etc/fancontrol ]; then
    systemctl enable --now fancontrol
    ok "fancontrol service enabled and started"
    echo ""
    echo "  Fan curves active. Check with:"
    echo "    sensors            # current readings"
    echo "    cat /etc/fancontrol  # saved configuration"
    echo "    sudo systemctl status fancontrol"
    echo ""
else
    warn "No /etc/fancontrol config file found — pwmconfig may have been cancelled"
    echo "  Re-run this script to try again."
fi
