#!/bin/bash
# Configure autologin on TTY
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

TTY="${AUTOLOGIN_TTY:-tty1}"

mkdir -p "/etc/systemd/system/getty@${TTY}.service.d"
cat > "/etc/systemd/system/getty@${TTY}.service.d/override.conf" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ${SETUP_USER} --noclear %I \$TERM
EOF

ok "Autologin for ${SETUP_USER} on ${TTY}"
