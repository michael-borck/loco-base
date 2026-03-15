#!/bin/bash
# Install all required packages
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

export DEBIAN_FRONTEND=noninteractive

# GitHub CLI repo (not in default Ubuntu repos)
if [ ! -f /etc/apt/sources.list.d/github-cli-stable.list ]; then
    mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        > /etc/apt/keyrings/githubcli-archive-keyring.gpg
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli-stable.list
    ok "GitHub CLI apt repo added"
fi

apt-get update -qq

# Core tools
APT_PACKAGES=(
    tmux
    figlet
    toilet
    toilet-fonts
    htop
    btop
    cmatrix
    cbonsai
    neofetch
    nmon
    tty-clock
    ufw
    fail2ban
    git
    gh
    curl
    imagemagick
    lynis
    nmap
)

# Plymouth
if [ "$PLYMOUTH_ENABLE" = true ]; then
    APT_PACKAGES+=(plymouth plymouth-themes)
fi

# Extra user-defined packages
if [ -n "$EXTRA_PACKAGES" ]; then
    APT_PACKAGES+=($EXTRA_PACKAGES)
fi

# Show what's missing for cleaner output
MISSING=()
for pkg in "${APT_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        MISSING+=("$pkg")
    fi
done

apt-get install -y "${APT_PACKAGES[@]}" 2>&1 | tail -5
if [ ${#MISSING[@]} -gt 0 ]; then
    ok "${#MISSING[@]} new packages installed"
else
    ok "All apt packages already installed"
fi

# pipes.sh (not in apt)
if ! command -v pipes.sh &>/dev/null; then
    cd /tmp
    rm -rf pipes.sh
    git clone --depth 1 https://github.com/pipeseroni/pipes.sh.git
    cd pipes.sh
    make install
    cd /tmp && rm -rf pipes.sh
    ok "pipes.sh installed from source"
else
    ok "pipes.sh already installed"
fi

# asciiquarium (not in apt on 22.04)
if ! command -v asciiquarium &>/dev/null; then
    cd /tmp
    rm -rf asciiquarium
    git clone --depth 1 https://github.com/cmatsuoka/asciiquarium.git
    cp asciiquarium/asciiquarium /usr/local/bin/
    chmod +x /usr/local/bin/asciiquarium
    rm -rf asciiquarium
    # Perl deps
    apt-get install -y libcurses-perl 2>&1 | tail -1
    cpan -fi Term::Animation 2>&1 | tail -1
    ok "asciiquarium installed from source"
else
    ok "asciiquarium already installed"
fi
