#!/bin/bash
# Install tmux dashboard script + pane-runner + bash_profile hook
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_HOME=$(eval echo "~$SETUP_USER")
TTY="${AUTOLOGIN_TTY:-tty1}"
DASHBOARD="${USER_HOME}/${MACHINE_NAME,,}-dashboard.sh"
RUNNER_DEST="${USER_HOME}/.local/bin/pane-runner.sh"
DEFAULT_INTERVAL="${DASHBOARD_ROTATE_INTERVAL:-300}"

# Install pane-runner helper
mkdir -p "${USER_HOME}/.local/bin"
cp "${SCRIPT_DIR}/pane-runner.sh" "$RUNNER_DEST"
chmod +x "$RUNNER_DEST"
chown "${SETUP_USER}:${SETUP_USER}" "$RUNNER_DEST"
ok "Pane runner installed at ${RUNNER_DEST}"

# Build pane config block and interval block
PANE_LINES=""
INTERVAL_LINES=""
for i in $(seq 1 8); do
    var="DASHBOARD_PANE_$i"
    val="${!var}"
    int_var="DASHBOARD_PANE_${i}_INTERVAL"
    int_val="${!int_var:-}"
    if [ -n "$val" ]; then
        PANE_LINES+="PANE_${i}=\"${val}\"\n"
    else
        PANE_LINES+="PANE_${i}=\"\"\n"
    fi
    if [ -n "$int_val" ]; then
        INTERVAL_LINES+="PANE_${i}_INTERVAL=\"${int_val}\"\n"
    else
        INTERVAL_LINES+="PANE_${i}_INTERVAL=\"\"\n"
    fi
done

cat > "$DASHBOARD" <<DASH
#!/bin/bash
# ${MACHINE_NAME} TTY Dashboard — configurable tmux panes with rotation
# Edit pane assignments below to customize.
# Use | to separate multiple commands that rotate in the same pane.
# e.g. PANE_2="cmatrix -C cyan | pipes.sh | cbonsai --live --infinite"

SESSION="dashboard"
RUNNER="${RUNNER_DEST}"

# LAYOUT: tiled, even-horizontal, even-vertical, main-horizontal, main-vertical
LAYOUT="${DASHBOARD_LAYOUT:-tiled}"

# Default rotation interval in seconds (used when pane has multiple commands)
DEFAULT_INTERVAL=${DEFAULT_INTERVAL}

# PANES: Set to "" to disable a slot. Use | to rotate multiple commands.
$(echo -e "$PANE_LINES")
# Per-pane interval overrides (seconds). Leave "" to use DEFAULT_INTERVAL.
$(echo -e "$INTERVAL_LINES")

# ──────────────────────────────────────────────

# Build the command to run in a pane, using pane-runner for rotation/availability
build_pane_cmd() {
    local pane_spec="\$1"
    local interval="\$2"

    # Split on | into array
    IFS='|' read -ra cmds <<< "\$pane_spec"

    # Trim whitespace from each command
    local trimmed=()
    for c in "\${cmds[@]}"; do
        c="\$(echo "\$c" | sed 's/^[[:space:]]*//;s/[[:space:]]*\$//')"
        [ -n "\$c" ] && trimmed+=("\$c")
    done

    if [ \${#trimmed[@]} -eq 0 ]; then
        return 1
    fi

    # Always use pane-runner — it handles single commands efficiently too
    local runner_cmd="\$RUNNER \$interval"
    for c in "\${trimmed[@]}"; do
        runner_cmd+=" \"\$c\""
    done
    echo "\$runner_cmd"
}

# Collect enabled panes
PANE_CMDS=()
for i in \$(seq 1 8); do
    var="PANE_\$i"
    spec="\${!var}"
    int_var="PANE_\${i}_INTERVAL"
    interval="\${!int_var:-\$DEFAULT_INTERVAL}"
    if [ -n "\$spec" ]; then
        cmd=\$(build_pane_cmd "\$spec" "\$interval")
        [ -n "\$cmd" ] && PANE_CMDS+=("\$cmd")
    fi
done

if [ \${#PANE_CMDS[@]} -eq 0 ]; then
    echo "No panes configured. Edit ${DASHBOARD}"
    exit 1
fi

tmux kill-session -t "\$SESSION" 2>/dev/null
tmux new-session -d -s "\$SESSION" "\${PANE_CMDS[0]}"

for ((i=1; i<\${#PANE_CMDS[@]}; i++)); do
    tmux split-window -t "\$SESSION" "\${PANE_CMDS[\$i]}"
    tmux select-layout -t "\$SESSION" "\$LAYOUT"
done

tmux select-layout -t "\$SESSION" "\$LAYOUT"
tmux attach-session -t "\$SESSION"
DASH

chmod +x "$DASHBOARD"
chown "${SETUP_USER}:${SETUP_USER}" "$DASHBOARD"
ok "Dashboard script at ${DASHBOARD}"

# Hook into .bash_profile
BASH_PROFILE="${USER_HOME}/.bash_profile"

# Create .bash_profile if it doesn't exist
if [ ! -f "$BASH_PROFILE" ]; then
    cat > "$BASH_PROFILE" <<'BP'
# Source .bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    . "$HOME/.bashrc"
fi
BP
    chown "${SETUP_USER}:${SETUP_USER}" "$BASH_PROFILE"
fi

# Add dashboard hook if not already present
if ! grep -q "${MACHINE_NAME,,}-dashboard" "$BASH_PROFILE" 2>/dev/null; then
    cat >> "$BASH_PROFILE" <<EOF

# Auto-start ${MACHINE_NAME} dashboard on ${TTY}
if [ "\$(tty)" = "/dev/${TTY}" ] && command -v tmux &>/dev/null && [ -z "\$TMUX" ]; then
    exec ~/${MACHINE_NAME,,}-dashboard.sh
fi
EOF
    ok "Dashboard auto-start added to .bash_profile"
else
    ok "Dashboard hook already in .bash_profile"
fi
