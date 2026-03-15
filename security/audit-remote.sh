#!/bin/bash
# ══════════════════════════════════════════════
# Remote Security Scan
# Scans lab machines from the outside using nmap.
# Usage: ./audit-remote.sh [host1 host2 ...] or reads from hosts.txt
# ══════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPORT_DIR="/var/log/security-audit"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
HOSTS_FILE="$SCRIPT_DIR/hosts.txt"

mkdir -p "$REPORT_DIR"

G='\033[1;32m'; Y='\033[1;33m'; RED='\033[1;31m'; C='\033[1;36m'; DIM='\033[2m'; R='\033[0m'

# Get hosts from args or file
if [ $# -gt 0 ]; then
    HOSTS=("$@")
elif [ -f "$HOSTS_FILE" ]; then
    mapfile -t HOSTS < <(grep -v '^#\|^$' "$HOSTS_FILE")
else
    echo "Usage: $0 [host1 host2 ...]"
    echo "  or create $HOSTS_FILE with one host per line"
    exit 1
fi

if ! command -v nmap &>/dev/null; then
    echo "nmap is required: sudo apt install nmap"
    exit 1
fi

TOTAL_ISSUES=0

for HOST in "${HOSTS[@]}"; do
    echo -e "\n${C}══ Scanning: ${HOST} ══${R}"
    REPORT_FILE="$REPORT_DIR/nmap-${HOST}-${TIMESTAMP}.txt"

    # ── TCP SYN scan (top 1000 ports) ──
    echo -e "${DIM}  Running TCP scan...${R}"
    SCAN=$(nmap -sS -sV --top-ports 1000 -T4 "$HOST" 2>/dev/null)
    echo "$SCAN" > "$REPORT_FILE"

    # Parse open ports
    OPEN_PORTS=$(echo "$SCAN" | grep '^[0-9]' | grep 'open' || true)
    OPEN_COUNT=$(echo "$OPEN_PORTS" | grep -c 'open' 2>/dev/null || echo 0)

    if [ -z "$OPEN_PORTS" ]; then
        echo -e "  ${G}PASS${R}  No open ports detected (host may be down or fully filtered)"
    else
        echo -e "  Open ports: ${OPEN_COUNT}"
        echo "$OPEN_PORTS" | while read -r line; do
            PORT=$(echo "$line" | awk -F/ '{print $1}')
            SERVICE=$(echo "$line" | awk '{print $3, $4, $5}')
            if [ "$PORT" = "22" ]; then
                echo -e "    ${G}✓${R}  $line"
            else
                echo -e "    ${Y}!${R}  $line  ${Y}← unexpected${R}"
                ((TOTAL_ISSUES++)) || true
            fi
        done
    fi

    # ── Check SSH specifically ──
    SSH_LINE=$(echo "$OPEN_PORTS" | grep '22/tcp' || true)
    if [ -n "$SSH_LINE" ]; then
        SSH_VER=$(echo "$SSH_LINE" | awk '{for(i=3;i<=NF;i++) printf "%s ", $i; print ""}')
        echo -e "  ${DIM}SSH version: ${SSH_VER}${R}"
    fi

    # ── UDP scan (common dangerous services) ──
    echo -e "${DIM}  Running UDP scan (common services)...${R}"
    UDP_SCAN=$(nmap -sU --top-ports 20 -T4 "$HOST" 2>/dev/null)
    UDP_OPEN=$(echo "$UDP_SCAN" | grep '^[0-9]' | grep -E 'open[^|]' | grep -v 'open|filtered' || true)
    if [ -z "$UDP_OPEN" ]; then
        echo -e "  ${G}PASS${R}  No open UDP services"
    else
        echo -e "  ${Y}WARN${R}  Open UDP:"
        echo "$UDP_OPEN" | while read -r line; do
            echo -e "    ${Y}!${R}  $line"
        done
    fi

    # ── Drift: compare with previous scan ──
    BASELINE="$REPORT_DIR/nmap-baseline-${HOST}.txt"
    PREV_PORTS="$REPORT_DIR/ports-${HOST}-prev.txt"
    CURR_PORTS="$REPORT_DIR/ports-${HOST}-curr.txt"

    echo "$OPEN_PORTS" | sort > "$CURR_PORTS"
    if [ -f "$PREV_PORTS" ]; then
        NEW_PORTS=$(comm -13 "$PREV_PORTS" "$CURR_PORTS" 2>/dev/null)
        CLOSED_PORTS=$(comm -23 "$PREV_PORTS" "$CURR_PORTS" 2>/dev/null)
        if [ -n "$NEW_PORTS" ]; then
            echo -e "  ${RED}ALERT${R}  New ports since last scan:"
            echo "$NEW_PORTS" | while read -r line; do
                echo -e "    ${RED}+${R}  $line"
            done
            ((TOTAL_ISSUES++)) || true
        fi
        if [ -n "$CLOSED_PORTS" ]; then
            echo -e "  ${DIM}Ports closed since last scan:${R}"
            echo "$CLOSED_PORTS" | while read -r line; do
                echo -e "    ${DIM}-  $line${R}"
            done
        fi
        if [ -z "$NEW_PORTS" ] && [ -z "$CLOSED_PORTS" ]; then
            echo -e "  ${G}PASS${R}  No port changes since last scan"
        fi
    else
        echo -e "  ${DIM}First scan — baseline saved${R}"
    fi
    cp "$CURR_PORTS" "$PREV_PORTS"

    echo -e "  ${DIM}Full report: ${REPORT_FILE}${R}"
done

# ── Summary ──
echo -e "\n${C}══ Scan Complete ══${R}"
echo "  Hosts scanned: ${#HOSTS[@]}"
echo "  Reports in: $REPORT_DIR"
if [ "$TOTAL_ISSUES" -gt 0 ]; then
    echo -e "  ${Y}Issues found: review output above${R}"
fi
