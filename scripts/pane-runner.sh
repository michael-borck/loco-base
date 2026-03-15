#!/bin/bash
# pane-runner.sh — Run one or more commands in a tmux pane with rotation
# Usage: pane-runner.sh <interval_seconds> <cmd1> [cmd2] [cmd3] ...
#
# If only one command is provided (or only one is available), it runs directly.
# If multiple commands are available, it cycles through them every <interval> seconds.
# If a command's binary is not found, a fallback message is displayed instead.

set -u

INTERVAL="${1:-300}"
shift
COMMANDS=("$@")

CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
RESET='\033[0m'

# Extract the base binary name from a command string (first word, basename)
get_binary() {
    local cmd="$1"
    local first_word="${cmd%% *}"
    basename "$first_word"
}

# Check if a command's binary is available
is_available() {
    local bin
    bin=$(get_binary "$1")
    command -v "$bin" &>/dev/null
}

# Show a "not available" message using toilet/figlet or plain text
show_unavailable() {
    local bin
    bin=$(get_binary "$1")
    clear
    echo ""
    if command -v toilet &>/dev/null; then
        toilet -f future "N/A" | while IFS= read -r line; do
            echo -e "${CYAN}${BOLD}  ${line}${RESET}"
        done
    elif command -v figlet &>/dev/null; then
        figlet "N/A" | while IFS= read -r line; do
            echo -e "${CYAN}${BOLD}  ${line}${RESET}"
        done
    else
        echo -e "${CYAN}${BOLD}  ═══ NOT AVAILABLE ═══${RESET}"
    fi
    echo ""
    echo -e "${DIM}  ──────────────────────────────────────────────${RESET}"
    echo -e "  ${CYAN}${bin}${RESET} is not installed on this system."
    echo -e "  Install it or remove from dashboard config."
    echo -e "${DIM}  ──────────────────────────────────────────────${RESET}"
}

# Filter to only available commands, keeping order; track unavailable for display
AVAILABLE=()
UNAVAILABLE=()
for cmd in "${COMMANDS[@]}"; do
    if is_available "$cmd"; then
        AVAILABLE+=("$cmd")
    else
        UNAVAILABLE+=("$cmd")
    fi
done

# If nothing is available, show message and wait forever
if [ ${#AVAILABLE[@]} -eq 0 ] && [ ${#UNAVAILABLE[@]} -gt 0 ]; then
    show_unavailable "${UNAVAILABLE[0]}"
    # Sleep forever — tmux will kill us when session ends
    while true; do sleep 3600; done
fi

# If exactly one command (available), just exec it — no rotation overhead
if [ ${#AVAILABLE[@]} -eq 1 ] && [ ${#UNAVAILABLE[@]} -eq 0 ]; then
    exec bash -c "${AVAILABLE[0]}"
fi

# Multiple commands — rotate through them
# Include unavailable ones in the rotation so the user sees the N/A message
ALL_ROTATION=()
for cmd in "${COMMANDS[@]}"; do
    ALL_ROTATION+=("$cmd")
done

IDX=0
COUNT=${#ALL_ROTATION[@]}

cleanup() {
    [ -n "${CMD_PID:-}" ] && kill "$CMD_PID" 2>/dev/null
    exit 0
}
trap cleanup EXIT INT TERM

while true; do
    cmd="${ALL_ROTATION[$IDX]}"

    if is_available "$cmd"; then
        bash -c "$cmd" &
        CMD_PID=$!
        sleep "$INTERVAL"
        kill "$CMD_PID" 2>/dev/null
        wait "$CMD_PID" 2>/dev/null
    else
        show_unavailable "$cmd"
        CMD_PID=""
        sleep "$INTERVAL"
    fi

    IDX=$(( (IDX + 1) % COUNT ))
done
