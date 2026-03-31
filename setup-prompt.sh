#!/bin/bash
# ══════════════════════════════════════════════
# Setup loco-base prompt for the current user
# No sudo required. Reads machine identity from .machine
#
# Usage: bash setup-prompt.sh
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

BASHRC="$HOME/.bashrc"
COLOR="${PROMPT_COLOR:-1;36m}"
EMOJI="${PROMPT_EMOJI:-🖥️}"
NAME="${MACHINE_NAME,,}"

echo -e "\n${C}══════════════════════════════════════════════${R}"
echo -e "${C}  Setup Prompt: ${NAME} ${EMOJI}${R}"
echo -e "${C}══════════════════════════════════════════════${R}"
echo ""

MARKER_START="# >>> loco-base prompt >>>"
MARKER_END="# <<< loco-base prompt <<<"

# Remove any previous loco-base prompt block
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    sed -i "/${MARKER_START}/,/${MARKER_END}/d" "$BASHRC"
    ok "Removed old prompt block"
fi

# Also remove legacy (non-marker) prompt lines
sed -i '/__git_branch/d' "$BASHRC" 2>/dev/null || true
sed -i '/┌.*::.*git_branch/d' "$BASHRC" 2>/dev/null || true
sed -i '/^$/N;/^\n$/d' "$BASHRC"

# Append new prompt
cat >> "$BASHRC" <<EOF

${MARKER_START}
__git_branch() { git branch 2>/dev/null | grep "^\*" | sed "s/* / /"; }
PS1='\[\033[0;37m\]┌ ${EMOJI} \[\033[${COLOR}\]${NAME}\[\033[0m\] :: \[\033[${COLOR}\]\w\[\033[1;32m\]\$(__git_branch)\[\033[0m\]\n\[\033[0;37m\]└ \[\033[1;32m\]❯\[\033[0m\] '
${MARKER_END}
EOF

ok "Prompt set: ${EMOJI} ${NAME}"
echo ""
echo "  Run 'source ~/.bashrc' or open a new terminal to see the change."
echo ""
