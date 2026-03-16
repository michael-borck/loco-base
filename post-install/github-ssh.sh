#!/bin/bash
# ══════════════════════════════════════════════
# Post-Install: GitHub CLI auth + SSH key setup
# Sets up gh auth, generates/uploads SSH key, switches repo remote to SSH.
# Saves GitHub token to ~/.env.keys (sourced from .bashrc).
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/config.env"

G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; DIM='\033[2m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }
step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }

USER_HOME=$(eval echo "~$SETUP_USER")
KEYS_FILE="${USER_HOME}/.env.keys"
SSH_KEY="${USER_HOME}/.ssh/id_ed25519"
BASHRC="${USER_HOME}/.bashrc"

MARKER_START="# >>> loco-base keys >>>"
MARKER_END="# <<< loco-base keys <<<"

# ── Ensure .env.keys is sourced from .bashrc ──
ensure_keys_sourced() {
    if ! grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" <<EOF

${MARKER_START}
[[ -f ~/.env.keys ]] && source ~/.env.keys
${MARKER_END}
EOF
        chown "${SETUP_USER}:${SETUP_USER}" "$BASHRC"
        ok "Added ~/.env.keys sourcing to .bashrc"
    fi
}

# ── Save a key=value to ~/.env.keys ──
save_key() {
    local key="$1" value="$2"
    touch "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
    if grep -q "^export ${key}=" "$KEYS_FILE" 2>/dev/null; then
        sed -i "s|^export ${key}=.*|export ${key}=\"${value}\"|" "$KEYS_FILE"
    else
        echo "export ${key}=\"${value}\"" >> "$KEYS_FILE"
    fi
    chown "${SETUP_USER}:${SETUP_USER}" "$KEYS_FILE"
}

step "GitHub & SSH Key Setup"

# ── Generate SSH key if needed ──
if [ ! -f "$SSH_KEY" ]; then
    echo "  Generating SSH key..."
    su - "$SETUP_USER" -c "ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N '' -C '${SETUP_USER}@${MACHINE_NAME}'" >/dev/null 2>&1
    ok "SSH key generated: ${SSH_KEY}"
else
    ok "SSH key already exists: ${SSH_KEY}"
fi

# ── Prompt for GitHub token ──
echo ""
echo -e "  ${DIM}Create a token at: https://github.com/settings/tokens${R}"
echo -e "  ${DIM}Required scopes: repo, admin:public_key${R}"
echo ""
read -rsp "  GitHub personal access token (Enter to skip): " GH_TOKEN
echo ""

if [ -z "$GH_TOKEN" ]; then
    warn "Skipped GitHub setup. Run this again when you have a token."
    exit 0
fi

# ── Authenticate with gh ──
echo "$GH_TOKEN" | su - "$SETUP_USER" -c "gh auth login --with-token" 2>/dev/null
ok "Authenticated with GitHub CLI"

# ── Upload SSH key ──
if su - "$SETUP_USER" -c "gh ssh-key list" 2>/dev/null | grep -q "${MACHINE_NAME}"; then
    ok "SSH key '${MACHINE_NAME}' already uploaded to GitHub"
else
    su - "$SETUP_USER" -c "gh ssh-key add ~/.ssh/id_ed25519.pub --title '${MACHINE_NAME}'" 2>/dev/null
    ok "SSH key uploaded to GitHub as '${MACHINE_NAME}'"
fi

# ── Switch repo remote to SSH ──
REPO_URL=$(cd "$SCRIPT_DIR" && git remote get-url origin 2>/dev/null || true)
if [[ "$REPO_URL" == https://github.com/* ]]; then
    SSH_URL=$(echo "$REPO_URL" | sed 's|https://github.com/|git@github.com:|')
    cd "$SCRIPT_DIR" && git remote set-url origin "$SSH_URL"
    ok "Repo remote switched to SSH: ${SSH_URL}"
elif [[ "$REPO_URL" == git@* ]]; then
    ok "Repo remote already using SSH"
else
    warn "Could not detect repo remote URL"
fi

# ── Save token ──
save_key "GITHUB_TOKEN" "$GH_TOKEN"
ensure_keys_sourced
ok "GitHub token saved to ~/.env.keys"

echo ""
echo "  GitHub setup complete. Test with:"
echo "    ssh -T git@github.com"
echo ""
