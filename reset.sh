#!/bin/bash
# ══════════════════════════════════════════════
# Machine Reset — Strip to Ubuntu 22.04 minimal server state
# Usage: sudo -E bash reset.sh
#
# This aggressively removes desktop environments, snaps, flatpak,
# unnecessary services, and any previous machine-setup artifacts,
# leaving a clean minimal server ready for install.sh.
#
# Safe: never touches SSH, kernel, networking, sudo, or apt itself.
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/config.env"

# Colors
G='\033[1;32m'
Y='\033[1;33m'
RED='\033[1;31m'
C='\033[1;36m'
R='\033[0m'

step()  { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }
ok()    { echo -e "  ${G}✓${R} $1"; }
warn()  { echo -e "  ${Y}!${R} $1"; }
skip()  { echo -e "  - $1 (nothing to do)"; }

if [ "$EUID" -ne 0 ]; then
    echo "Please run with: sudo -E bash reset.sh"
    exit 1
fi

# OS check
if [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    if [ "$DISTRIB_RELEASE" != "22.04" ]; then
        echo -e "${RED}ERROR:${R} This script targets Ubuntu 22.04 LTS only (detected: ${DISTRIB_RELEASE})"
        exit 1
    fi
else
    echo -e "${RED}ERROR:${R} Cannot detect Ubuntu version"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

USER_HOME=$(eval echo "~$SETUP_USER")
THEME_NAME="${MACHINE_NAME,,}"
TTY="${AUTOLOGIN_TTY:-tty1}"

echo ""
echo -e "${RED}  ╔══════════════════════════════════════════════════════════╗${R}"
echo -e "${RED}  ║  WARNING: This will strip this machine to minimal       ║${R}"
echo -e "${RED}  ║  Ubuntu 22.04 server state. Desktop environments,       ║${R}"
echo -e "${RED}  ║  snaps, and unnecessary services will be REMOVED.       ║${R}"
echo -e "${RED}  ╚══════════════════════════════════════════════════════════╝${R}"
echo ""
echo "  Machine: $MACHINE_NAME"
echo "  User:    $SETUP_USER"
echo ""
read -rp "  Type YES to proceed: " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo "Aborted."
    exit 1
fi

# ══════════════════════════════════════════════
# Phase 1: Remove our own artifacts
# ══════════════════════════════════════════════
step "Phase 1: Remove machine-setup artifacts"

# Plymouth theme
if [ -d "/usr/share/plymouth/themes/${THEME_NAME}" ]; then
    update-alternatives --remove default.plymouth \
        "/usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.plymouth" 2>/dev/null || true
    rm -rf "/usr/share/plymouth/themes/${THEME_NAME}"
    ok "Removed Plymouth theme '${THEME_NAME}'"
else
    skip "Plymouth theme"
fi

# Custom MOTD — remove ours, re-enable defaults
if [ -f "/etc/update-motd.d/01-${THEME_NAME}" ]; then
    rm -f "/etc/update-motd.d/01-${THEME_NAME}"
    ok "Removed custom MOTD script"
else
    skip "Custom MOTD"
fi
for f in /etc/update-motd.d/{00-header,10-help-text,50-motd-news,60-unminimize,91-release-upgrade,92-unattended-upgrades}; do
    [ -f "$f" ] && chmod +x "$f"
done
ok "Re-enabled default MOTD scripts"

# Autologin override
OVERRIDE="/etc/systemd/system/getty@${TTY}.service.d/override.conf"
if [ -f "$OVERRIDE" ]; then
    rm -f "$OVERRIDE"
    rmdir "/etc/systemd/system/getty@${TTY}.service.d" 2>/dev/null || true
    systemctl daemon-reload
    ok "Removed autologin override"
else
    skip "Autologin override"
fi

# Dashboard script and pane-runner
rm -f "${USER_HOME}/${THEME_NAME}-dashboard.sh"
rm -f "${USER_HOME}/.local/bin/pane-runner.sh"
ok "Removed dashboard scripts"

# Dashboard hook from .bash_profile
if [ -f "${USER_HOME}/.bash_profile" ]; then
    sed -i "/# Auto-start ${MACHINE_NAME} dashboard/,/^fi$/d" "${USER_HOME}/.bash_profile"
    # Clean up blank lines left behind
    sed -i '/^$/N;/^\n$/d' "${USER_HOME}/.bash_profile"
    ok "Removed dashboard hook from .bash_profile"
fi

# Custom prompt from .bashrc (marker-based or legacy)
BASHRC="${USER_HOME}/.bashrc"
if [ -f "$BASHRC" ]; then
    # Remove marker-based block if present
    sed -i '/^# >>> machine-setup prompt >>>/,/^# <<< machine-setup prompt <<</d' "$BASHRC" 2>/dev/null
    # Remove legacy (non-marker) prompt lines
    sed -i '/__git_branch/d' "$BASHRC" 2>/dev/null
    sed -i '/┌.*::.*git_branch/d' "$BASHRC" 2>/dev/null
    sed -i '/^$/N;/^\n$/d' "$BASHRC"
    chown "${SETUP_USER}:${SETUP_USER}" "$BASHRC"
    ok "Removed custom prompt from .bashrc"
fi

# Sudoers files from our scripts
rm -f "/etc/sudoers.d/${SETUP_USER}-nopasswd"
rm -f "/etc/sudoers.d/nopasswd-${SETUP_USER}"
ok "Removed NOPASSWD sudoers entries"

# fail2ban custom jail
rm -f /etc/fail2ban/jail.local
ok "Removed fail2ban jail.local"

# ══════════════════════════════════════════════
# Phase 2: Remove desktop environments and display managers
# ══════════════════════════════════════════════
step "Phase 2: Remove desktop environments"

DE_PACKAGES=(
    # GNOME
    ubuntu-desktop ubuntu-desktop-minimal
    gnome-shell gnome-session gdm3 gnome-terminal nautilus
    gnome-control-center gnome-software gnome-tweaks
    # KDE
    kde-standard kde-plasma-desktop sddm plasma-desktop
    # XFCE
    xfce4 xfce4-session xfce4-panel
    # LXQt / LXDE
    lxde lxqt lxqt-session
    # MATE / Cinnamon
    mate-desktop-environment cinnamon cinnamon-session
    # Display managers
    gdm3 sddm lightdm slim
    # X11 core
    xorg xserver-xorg xserver-xorg-core x11-common
    xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-gtk
)

INSTALLED_DE=()
for pkg in "${DE_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        INSTALLED_DE+=("$pkg")
    fi
done

if [ ${#INSTALLED_DE[@]} -gt 0 ]; then
    echo "  Removing ${#INSTALLED_DE[@]} desktop/GUI packages..."
    apt-get purge -y "${INSTALLED_DE[@]}" 2>&1 | tail -5
    ok "Desktop environments removed"
else
    skip "No desktop environments found"
fi

# ══════════════════════════════════════════════
# Phase 3: Remove snap and flatpak
# ══════════════════════════════════════════════
step "Phase 3: Remove snap and flatpak"

if command -v snap &>/dev/null; then
    # Remove all snaps (leaf packages first)
    SNAP_COUNT=0
    for attempt in 1 2 3; do
        snap list 2>/dev/null | awk 'NR>1 && $1!="snapd" {print $1}' | while read -r s; do
            snap remove --purge "$s" 2>/dev/null && ((SNAP_COUNT++)) || true
        done
    done
    snap remove --purge snapd 2>/dev/null || true
    apt-get purge -y snapd 2>/dev/null || true
    rm -rf /snap /var/snap /var/lib/snapd "${USER_HOME}/snap"
    ok "Snap removed"
else
    skip "Snap not installed"
fi

if command -v flatpak &>/dev/null; then
    flatpak uninstall --all --noninteractive 2>/dev/null || true
    apt-get purge -y flatpak 2>/dev/null || true
    rm -rf /var/lib/flatpak "${USER_HOME}/.local/share/flatpak"
    ok "Flatpak removed"
else
    skip "Flatpak not installed"
fi

# ══════════════════════════════════════════════
# Phase 4: Disable and remove unnecessary services
# ══════════════════════════════════════════════
step "Phase 4: Remove unnecessary services"

SERVICE_PACKAGES=(
    cups cups-browsed cups-daemon       # printing
    avahi-daemon avahi-utils            # mDNS
    bluetooth bluez                     # bluetooth
    modemmanager                        # modem
    whoopsie                            # Ubuntu error reporting
    apport                              # crash reporting
    unattended-upgrades                 # auto-updates (we manage explicitly)
    ubuntu-advantage-tools              # UA / Pro
    popularity-contest                  # package stats
    speech-dispatcher                   # accessibility
    brltty                              # braille display
    cloud-init                          # cloud provisioning (bare metal)
)

# Disable services first (graceful)
for svc in cups avahi-daemon bluetooth ModemManager whoopsie apport cloud-init speech-dispatcher brltty; do
    if systemctl is-active "$svc" 2>/dev/null | grep -q 'active'; then
        systemctl disable --now "$svc" 2>/dev/null || true
    fi
done

INSTALLED_SVC=()
for pkg in "${SERVICE_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        INSTALLED_SVC+=("$pkg")
    fi
done

if [ ${#INSTALLED_SVC[@]} -gt 0 ]; then
    apt-get purge -y "${INSTALLED_SVC[@]}" 2>&1 | tail -5
    ok "Removed ${#INSTALLED_SVC[@]} unnecessary service packages"
else
    skip "No unnecessary services found"
fi

# ══════════════════════════════════════════════
# Phase 5: Reset shells to bash
# ══════════════════════════════════════════════
step "Phase 5: Reset default shells"

CHANGED=0
awk -F: '$3 >= 1000 && $3 < 65534 && $7 != "/bin/bash" {print $1, $7}' /etc/passwd | while read -r user shell; do
    chsh -s /bin/bash "$user"
    echo "  ${user}: ${shell} → /bin/bash"
    CHANGED=1
done
if [ "$CHANGED" -eq 0 ] 2>/dev/null; then
    skip "All user shells already bash"
fi

# Remove non-standard shells if installed (except bash/sh)
for shell_pkg in zsh fish; do
    if dpkg -l "$shell_pkg" 2>/dev/null | grep -q '^ii'; then
        apt-get purge -y "$shell_pkg" 2>&1 | tail -1
        ok "Removed $shell_pkg"
    fi
done

# ══════════════════════════════════════════════
# Phase 6: Remove packages installed by our scripts
# ══════════════════════════════════════════════
step "Phase 6: Remove machine-setup packages"

OUR_PACKAGES=(
    tmux figlet toilet toilet-fonts
    htop btop cmatrix cbonsai neofetch nmon tty-clock
    ufw fail2ban
    imagemagick lynis nmap
    plymouth plymouth-themes
    nvidia-driver-535 nvidia-dkms-535 nvidia-utils-535
)

INSTALLED_OURS=()
for pkg in "${OUR_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        INSTALLED_OURS+=("$pkg")
    fi
done

if [ ${#INSTALLED_OURS[@]} -gt 0 ]; then
    apt-get purge -y "${INSTALLED_OURS[@]}" 2>&1 | tail -5
    ok "Removed ${#INSTALLED_OURS[@]} machine-setup packages"
else
    skip "Machine-setup packages already removed"
fi

# Remove source-installed binaries
rm -f /usr/local/bin/pipes.sh /usr/local/bin/asciiquarium
ok "Removed source-installed binaries"

# ══════════════════════════════════════════════
# Phase 7: Clean up
# ══════════════════════════════════════════════
step "Phase 7: Clean up"

apt-get autoremove --purge -y 2>&1 | tail -3
apt-get autoclean 2>&1 | tail -1
ok "Orphaned packages removed"

# Remove leftover config dirs
rm -rf /etc/fail2ban 2>/dev/null || true
systemctl daemon-reload

# ══════════════════════════════════════════════
# Done
# ══════════════════════════════════════════════
step "RESET COMPLETE"
echo ""
echo "  Machine stripped to minimal Ubuntu 22.04 server state."
echo ""
echo "  Next steps:"
echo "    1. Review with: sudo bash ${SCRIPT_DIR}/verify.sh"
echo "    2. Re-install with: sudo -E bash ${SCRIPT_DIR}/install.sh"
echo ""
