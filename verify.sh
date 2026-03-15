#!/bin/bash
# Post-install verification
source "$(dirname "$0")/config.env"

PASS='\033[1;32m✓\033[0m'
FAIL='\033[1;31m✗\033[0m'
USER_HOME=$(eval echo "~$SETUP_USER")
THEME_NAME="${MACHINE_NAME,,}"
TTY="${AUTOLOGIN_TTY:-tty1}"

echo "=== ${MACHINE_NAME} Post-Install Checklist ==="
echo ""

# Plymouth
if [ -f "/usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.plymouth" ]; then
    echo -e "  $PASS Plymouth theme '${THEME_NAME}' installed"
else
    echo -e "  $FAIL Plymouth theme '${THEME_NAME}' not found"
fi

# Autologin
if grep -q 'autologin' "/etc/systemd/system/getty@${TTY}.service.d/override.conf" 2>/dev/null; then
    echo -e "  $PASS Auto-login configured on ${TTY}"
else
    echo -e "  $FAIL Auto-login not configured"
fi

# tmux / dashboard
if [ -x "${USER_HOME}/${THEME_NAME}-dashboard.sh" ]; then
    echo -e "  $PASS Dashboard script exists"
else
    echo -e "  $FAIL Dashboard script missing"
fi

# NVIDIA
if command -v nvidia-smi &>/dev/null; then
    if nvidia-smi &>/dev/null; then
        echo -e "  $PASS nvidia-smi works — GPU detected"
    else
        echo -e "  $FAIL nvidia-smi installed but GPU not detected (install GPU or disable Secure Boot)"
    fi
else
    echo -e "  $FAIL nvidia-smi not found"
fi

# MOTD
echo ""
echo "=== MOTD Test ==="
run-parts /etc/update-motd.d/ 2>&1
echo ""

# Firewall
if sudo ufw status 2>/dev/null | grep -q 'active'; then
    echo -e "  $PASS UFW firewall is active"
else
    echo -e "  $FAIL UFW firewall is not active"
fi

# fail2ban
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    echo -e "  $PASS fail2ban is running"
else
    echo -e "  $FAIL fail2ban is not running"
fi

echo ""
echo "=== All checks complete ==="
echo ""
echo "If everything looks good, run as FINAL step:"
echo "  sudo rm /etc/sudoers.d/${SETUP_USER}-nopasswd"
