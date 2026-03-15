#!/bin/bash
# Configure GRUB for Plymouth splash
G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

CURRENT=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub)

if echo "$CURRENT" | grep -q 'quiet splash'; then
    ok "GRUB already has 'quiet splash'"
else
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/' /etc/default/grub
    update-grub
    ok "GRUB configured with 'quiet splash'"
fi
