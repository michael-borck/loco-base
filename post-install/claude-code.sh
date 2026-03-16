#!/bin/bash
# ══════════════════════════════════════════════
# Post-Install: Install Claude Code CLI
# Optionally saves Anthropic API key to ~/.env.keys.
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
BASHRC="${USER_HOME}/.bashrc"

MARKER_START="# >>> loco-base keys >>>"
MARKER_END="# <<< loco-base keys <<<"

ensure_keys_sourced() {
    if ! grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
        cat >> "$BASHRC" <<EOF

${MARKER_START}
[[ -f ~/.env.keys ]] && source ~/.env.keys
${MARKER_END}
EOF
        chown "${SETUP_USER}:${SETUP_USER}" "$BASHRC"
    fi
}

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

step "Install Claude Code"

# ── Install Claude Code CLI ──
if su - "$SETUP_USER" -c "command -v claude" &>/dev/null; then
    ok "Claude Code already installed"
else
    echo "  Installing Claude Code..."
    su - "$SETUP_USER" -c "curl -fsSL https://claude.ai/install.sh | bash" 2>&1 | tail -3
    ok "Claude Code installed"
fi

# ── Prompt for Anthropic API key ──
echo ""
echo -e "  ${DIM}You can skip this if you log in via Anthropic subscription instead.${R}"
echo ""
read -rsp "  Anthropic API key (Enter to skip): " API_KEY
echo ""

if [ -n "$API_KEY" ]; then
    save_key "ANTHROPIC_API_KEY" "$API_KEY"
    ensure_keys_sourced
    ok "Anthropic API key saved to ~/.env.keys"
else
    warn "Skipped API key. You can log in interactively with: claude"
fi

echo ""
echo "  Claude Code ready. Start with:"
echo "    claude"
echo ""
