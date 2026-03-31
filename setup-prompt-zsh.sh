#!/bin/bash
# ══════════════════════════════════════════════
# Setup loco-base prompt for the current user (zsh)
# No sudo required. Reads machine identity from .machine
#
# Usage: bash setup-prompt-zsh.sh
# ══════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MACHINE_FILE="$SCRIPT_DIR/.machine"

G='\033[1;32m'; R='\033[0m'; C='\033[1;36m'
ok() { echo -e "  ${G}✓${R} $1"; }

if [[ ! -f "$MACHINE_FILE" ]]; then
    echo "  No .machine file found. Run install.sh first to set the machine identity."
    exit 1
fi

source "$MACHINE_FILE"
source "$SCRIPT_DIR/config.env"

ZSHRC="$HOME/.zshrc"
EMOJI="${PROMPT_EMOJI:-🖥️}"
NAME="${MACHINE_NAME,,}"

echo -e "\n${C}══════════════════════════════════════════════${R}"
echo -e "${C}  Setup Prompt (zsh): ${NAME} ${EMOJI}${R}"
echo -e "${C}══════════════════════════════════════════════${R}"
echo ""

# Create .zshrc if it doesn't exist
touch "$ZSHRC"

MARKER_START="# >>> loco-base prompt >>>"
MARKER_END="# <<< loco-base prompt <<<"

# Remove any previous loco-base prompt block
if grep -q "$MARKER_START" "$ZSHRC" 2>/dev/null; then
    sed -i'' -e "/${MARKER_START}/,/${MARKER_END}/d" "$ZSHRC"
    ok "Removed old prompt block"
fi

# Append new prompt
cat >> "$ZSHRC" <<'BLOCK_START'

# >>> loco-base prompt >>>
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{green}%b%f'
setopt PROMPT_SUBST
BLOCK_START

cat >> "$ZSHRC" <<EOF
PROMPT='%F{white}┌ ${EMOJI} %F{cyan}${NAME}%f :: %F{cyan}%~%f\${vcs_info_msg_0_}
%F{white}└ %F{green}❯%f '
# <<< loco-base prompt <<<
EOF

ok "Prompt set: ${EMOJI} ${NAME}"
echo ""
echo "  Run 'source ~/.zshrc' or open a new terminal to see the change."
echo ""
