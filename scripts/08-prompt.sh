#!/bin/bash
# Configure bash prompt with emoji and machine name
# Idempotent — uses marker block so re-runs replace cleanly.
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

USER_HOME=$(eval echo "~$SETUP_USER")
BASHRC="${USER_HOME}/.bashrc"
COLOR="${PROMPT_COLOR:-1;36m}"
EMOJI="${PROMPT_EMOJI:-🖥️}"
NAME="${MACHINE_NAME,,}"

MARKER_START="# >>> loco-base prompt >>>"
MARKER_END="# <<< loco-base prompt <<<"

# Remove any previous loco-base prompt block (marker-based)
if grep -q "$MARKER_START" "$BASHRC" 2>/dev/null; then
    sed -i "/${MARKER_START}/,/${MARKER_END}/d" "$BASHRC"
fi

# Also remove legacy (non-marker) prompt lines from older installs
sed -i '/__git_branch/d' "$BASHRC" 2>/dev/null || true
sed -i '/┌.*::.*git_branch/d' "$BASHRC" 2>/dev/null || true

# Clean up consecutive blank lines
sed -i '/^$/N;/^\n$/d' "$BASHRC"

# Append new marker-wrapped block
cat >> "$BASHRC" <<EOF

${MARKER_START}
__git_branch() { git branch 2>/dev/null | grep "^\*" | sed "s/* / /"; }
PS1='\[\033[0;37m\]┌ ${EMOJI} \[\033[${COLOR}\]${NAME}\[\033[0m\] :: \[\033[${COLOR}\]\w\[\033[1;32m\]\$(__git_branch)\[\033[0m\]\n\[\033[0;37m\]└ \[\033[1;32m\]❯\[\033[0m\] '
${MARKER_END}
EOF

chown "${SETUP_USER}:${SETUP_USER}" "$BASHRC"
ok "Prompt set: ${EMOJI} ${NAME}"
