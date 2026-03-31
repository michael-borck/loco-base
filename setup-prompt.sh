#!/bin/bash
# ══════════════════════════════════════════════
# Setup loco-base prompt for the current user
# No sudo required. Reads machine identity from .machine
# Auto-detects bash or zsh.
#
# Usage: ./setup-prompt.sh
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

COLOR="${PROMPT_COLOR:-1;36m}"
EMOJI="${PROMPT_EMOJI:-🖥️}"
NAME="${MACHINE_NAME,,}"

# ── Detect shell ──
USER_SHELL="$(basename "${SHELL:-/bin/bash}")"

case "$USER_SHELL" in
    zsh)  RC_FILE="$HOME/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    *)    RC_FILE="$HOME/.bashrc"; USER_SHELL="bash" ;;
esac

echo -e "\n${C}══════════════════════════════════════════════${R}"
echo -e "${C}  Setup Prompt (${USER_SHELL}): ${NAME} ${EMOJI}${R}"
echo -e "${C}══════════════════════════════════════════════${R}"
echo ""

touch "$RC_FILE"

MARKER_START="# >>> loco-base prompt >>>"
MARKER_END="# <<< loco-base prompt <<<"

# Remove any previous loco-base prompt block
if grep -q "$MARKER_START" "$RC_FILE" 2>/dev/null; then
    sed -i'' -e "/${MARKER_START}/,/${MARKER_END}/d" "$RC_FILE"
    ok "Removed old prompt block"
fi

# Remove legacy (non-marker) prompt lines
sed -i'' -e '/__git_branch/d' "$RC_FILE" 2>/dev/null || true
sed -i'' -e '/┌.*::.*git_branch/d' "$RC_FILE" 2>/dev/null || true
sed -i'' -e '/^$/N;/^\n$/d' "$RC_FILE"

# ── Write shell-specific prompt ──
if [[ "$USER_SHELL" == "zsh" ]]; then
    cat >> "$RC_FILE" <<'BLOCK_STATIC'

# >>> loco-base prompt >>>
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats ' %F{green}%b%f'
setopt PROMPT_SUBST
BLOCK_STATIC

    cat >> "$RC_FILE" <<EOF
PROMPT='%F{white}┌ ${EMOJI} %F{cyan}${NAME}%f :: %F{cyan}%~%f\${vcs_info_msg_0_}
%F{white}└ %F{green}❯%f '
# <<< loco-base prompt <<<
EOF

else
    cat >> "$RC_FILE" <<EOF

${MARKER_START}
__git_branch() { git branch 2>/dev/null | grep "^\*" | sed "s/* / /"; }
PS1='\[\033[0;37m\]┌ ${EMOJI} \[\033[${COLOR}\]${NAME}\[\033[0m\] :: \[\033[${COLOR}\]\w\[\033[1;32m\]\$(__git_branch)\[\033[0m\]\n\[\033[0;37m\]└ \[\033[1;32m\]❯\[\033[0m\] '
${MARKER_END}
EOF
fi

ok "Prompt set: ${EMOJI} ${NAME} → ${RC_FILE}"
echo ""
echo "  Run 'source ${RC_FILE}' or open a new terminal to see the change."
echo ""
