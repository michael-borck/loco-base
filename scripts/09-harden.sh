#!/bin/bash
# UFW + fail2ban hardening
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
skip() { echo -e "  - $1 (skipped)"; }

# UFW
if [ "$UFW_ENABLE" = true ]; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw --force enable
    ok "UFW enabled (deny incoming, allow SSH)"
else
    skip "UFW"
fi

# fail2ban
if [ "$FAIL2BAN_ENABLE" = true ]; then
    # Use systemd backend (minimal installs don't have rsyslog)
    mkdir -p /etc/fail2ban
    cat > /etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
backend = systemd
EOF
    systemctl enable --now fail2ban
    ok "fail2ban enabled (systemd backend)"
else
    skip "fail2ban"
fi
