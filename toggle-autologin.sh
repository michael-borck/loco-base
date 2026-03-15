#!/bin/bash
# Toggle TTY autologin on/off
# Usage: sudo ./toggle-autologin.sh [on|off|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

USER="${SETUP_USER:-michael}"
TTY="${AUTOLOGIN_TTY:-tty1}"
OVERRIDE="/etc/systemd/system/getty@${TTY}.service.d/override.conf"

G='\033[1;32m'
Y='\033[1;33m'
R='\033[0m'

usage() {
    echo "Usage: sudo $(basename "$0") [on|off|status]"
    echo ""
    echo "  on      Enable autologin for ${USER} on ${TTY}"
    echo "  off     Disable autologin (require password at console)"
    echo "  status  Show current state"
    echo ""
    echo "Configure user/tty in config.env (SETUP_USER, AUTOLOGIN_TTY)"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Must run as root: sudo $(basename "$0") $1"
        exit 1
    fi
}

status() {
    if [ -f "$OVERRIDE" ] && grep -q 'autologin' "$OVERRIDE" 2>/dev/null; then
        echo -e "${Y}Autologin is ON${R} — ${USER} on ${TTY}"
        echo "  File: ${OVERRIDE}"
    else
        echo -e "${G}Autologin is OFF${R} — password required at console"
    fi
}

enable() {
    check_root on
    mkdir -p "$(dirname "$OVERRIDE")"
    cat > "$OVERRIDE" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${USER} --noclear %I \$TERM
EOF
    systemctl daemon-reload
    echo -e "${Y}Autologin ENABLED${R} for ${USER} on ${TTY}"
    echo "  Takes effect on next boot or: sudo systemctl restart getty@${TTY}"
}

disable() {
    check_root off
    if [ -f "$OVERRIDE" ]; then
        rm "$OVERRIDE"
        rmdir "$(dirname "$OVERRIDE")" 2>/dev/null || true
        systemctl daemon-reload
    fi
    echo -e "${G}Autologin DISABLED${R} — password required at console"
    echo "  Takes effect on next boot or: sudo systemctl restart getty@${TTY}"
}

case "${1:-}" in
    on)     enable ;;
    off)    disable ;;
    status) status ;;
    *)      usage ;;
esac
