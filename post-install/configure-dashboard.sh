#!/bin/bash
# ══════════════════════════════════════════════
# Post-Install: Reconfigure tmux dashboard
# Interactive tool to change panes, layout, and rotation interval.
# Re-runs 07-dashboard.sh after saving changes to config.env.
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/config.env"

G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; DIM='\033[2m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }

export MACHINE_NAME SETUP_USER PROMPT_EMOJI

step "Configure Dashboard"

echo ""
echo "  Current layout: ${DASHBOARD_LAYOUT}"
echo "  Rotation interval: ${DASHBOARD_ROTATE_INTERVAL}s"
echo ""
echo "  Current panes:"
for i in $(seq 1 8); do
    var="DASHBOARD_PANE_$i"
    val="${!var}"
    if [ -n "$val" ]; then
        echo -e "    ${G}Pane $i:${R} $val"
    fi
done
echo ""

# ── Layout ──
echo -e "  ${DIM}Layouts: tiled, even-horizontal, even-vertical, main-horizontal, main-vertical${R}"
read -rp "  New layout (Enter to keep '${DASHBOARD_LAYOUT}'): " new_layout
new_layout="${new_layout:-$DASHBOARD_LAYOUT}"

# ── Rotation interval ──
read -rp "  Rotation interval in seconds (Enter to keep '${DASHBOARD_ROTATE_INTERVAL}'): " new_interval
new_interval="${new_interval:-$DASHBOARD_ROTATE_INTERVAL}"

# ── Panes ──
echo ""
echo -e "  ${DIM}Configure panes 1-8. Use | to rotate commands. Leave blank to disable.${R}"
echo -e "  ${DIM}Examples: htop, cmatrix -C cyan | pipes.sh, watch -n2 -c nvidia-smi${R}"
echo ""

declare -a new_panes
for i in $(seq 1 8); do
    var="DASHBOARD_PANE_$i"
    current="${!var}"
    if [ -n "$current" ]; then
        read -rp "  Pane $i (Enter to keep '$current', 'x' to clear): " input
        if [ "$input" = "x" ]; then
            new_panes[$i]=""
        else
            new_panes[$i]="${input:-$current}"
        fi
    else
        read -rp "  Pane $i (Enter to skip): " input
        new_panes[$i]="$input"
        # Stop asking if they skip an empty pane
        if [ -z "$input" ]; then
            for j in $(seq $((i+1)) 8); do
                new_panes[$j]=""
            done
            break
        fi
    fi
done

# ── Update config.env ──
CONFIG="$SCRIPT_DIR/config.env"

# Update layout
sed -i "s|^DASHBOARD_LAYOUT=.*|DASHBOARD_LAYOUT=\"${new_layout}\"|" "$CONFIG"
sed -i "s|^DASHBOARD_ROTATE_INTERVAL=.*|DASHBOARD_ROTATE_INTERVAL=${new_interval}|" "$CONFIG"

# Update panes
for i in $(seq 1 8); do
    val="${new_panes[$i]}"
    sed -i "s|^DASHBOARD_PANE_${i}=.*|DASHBOARD_PANE_${i}=\"${val}\"|" "$CONFIG"
done

ok "Dashboard config updated"

# ── Preview ──
echo ""
echo "  New configuration:"
echo "    Layout: ${new_layout}"
echo "    Interval: ${new_interval}s"
for i in $(seq 1 8); do
    val="${new_panes[$i]}"
    [ -n "$val" ] && echo -e "    ${G}Pane $i:${R} $val"
done
echo ""

read -rp "  Apply now? (re-runs dashboard script) [Y/n]: " apply
if [[ ! "$apply" =~ ^[Nn] ]]; then
    # Re-source updated config
    source "$CONFIG"
    bash "$SCRIPT_DIR/scripts/07-dashboard.sh"
    ok "Dashboard reconfigured. Changes take effect on next login or: tmux kill-server"
fi
