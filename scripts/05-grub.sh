#!/bin/bash
# Configure GRUB boot parameters
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

# Build desired cmdline from config
CMDLINE="quiet splash"
if [ "${NVIDIA_OLD_BIOS_QUIRKS:-false}" = true ]; then
    CMDLINE="$CMDLINE intel_iommu=off pcie_aspm=off pci=realloc=off pci=nocrs"
fi

CURRENT=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub | sed 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/\1/')

if [ "$CURRENT" = "$CMDLINE" ]; then
    ok "GRUB already configured correctly"
else
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${CMDLINE}\"|" /etc/default/grub
    update-grub
    ok "GRUB configured: ${CMDLINE}"
fi
