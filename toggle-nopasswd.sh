#!/bin/bash
# Toggle NOPASSWD sudo on/off
# Usage: sudo ./toggle-nopasswd.sh [on|off|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/config.env" ]; then
    source "$SCRIPT_DIR/config.env"
fi

USER="${SETUP_USER:-michael}"
SUDOERS_FILE="/etc/sudoers.d/nopasswd-${USER}"

G='\033[1;32m'
Y='\033[1;33m'
R='\033[0m'

usage() {
    echo "Usage: sudo $(basename "$0") [on|off|status]"
    echo ""
    echo "  on      Enable NOPASSWD sudo for ${USER}"
    echo "  off     Disable NOPASSWD sudo (require password for sudo)"
    echo "  status  Show current state"
    echo ""
    echo "Configure user in config.env (SETUP_USER)"
    exit 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Must run as root: sudo $(basename "$0") $1"
        exit 1
    fi
}

status() {
    if [ -f "$SUDOERS_FILE" ]; then
        echo -e "${Y}NOPASSWD sudo is ON${R} — ${USER} can sudo without password"
        echo "  File: ${SUDOERS_FILE}"
    else
        echo -e "${G}NOPASSWD sudo is OFF${R} — password required for sudo"
    fi
}

enable() {
    check_root on
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    # Validate syntax before leaving it in place
    if ! visudo -cf "$SUDOERS_FILE" >/dev/null 2>&1; then
        rm "$SUDOERS_FILE"
        echo "ERROR: sudoers syntax check failed — file removed"
        exit 1
    fi
    echo -e "${Y}NOPASSWD sudo ENABLED${R} for ${USER}"
    echo "  Effective immediately"
}

disable() {
    check_root off
    if [ -f "$SUDOERS_FILE" ]; then
        rm "$SUDOERS_FILE"
    fi
    echo -e "${G}NOPASSWD sudo DISABLED${R} — password required for sudo"
    echo "  Effective immediately"
}

case "${1:-}" in
    on)     enable ;;
    off)    disable ;;
    status) status ;;
    *)      usage ;;
esac
