#!/bin/bash
# Install custom MOTD
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

USER_HOME=$(eval echo "~$SETUP_USER")
HEADER_TEXT=$(echo "$MACHINE_NAME" | tr '[:lower:]' '[:upper:]')

# Disable default MOTD scripts
for f in /etc/update-motd.d/{00-header,10-help-text,50-motd-news,60-unminimize,85-fwupd,91-release-upgrade,92-unattended-upgrades,99-livepatch-kernel-upgrade-required}; do
    [ -f "$f" ] && chmod -x "$f"
done
ok "Disabled default MOTD scripts"

# Generate MOTD script from template
MOTD_SCRIPT="/etc/update-motd.d/01-${MACHINE_NAME,,}"

cat > "$MOTD_SCRIPT" <<'OUTER'
#!/bin/bash
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

ART_DIR="__ART_DIR__"
ART_GLOB="__ART_GLOB__"
HEADER="__HEADER__"

# Pick random art file
ART_FILES=("$ART_DIR"/$ART_GLOB)
ART_FILE="${ART_FILES[RANDOM % ${#ART_FILES[@]}]}"

# Header
echo ""
if command -v toilet &>/dev/null; then
    toilet -f future "$HEADER" | while IFS= read -r line; do
        echo -e "${CYAN}${BOLD}  ${line}${RESET}"
    done
elif command -v figlet &>/dev/null; then
    figlet "$HEADER" | while IFS= read -r line; do
        echo -e "${CYAN}${BOLD}  ${line}${RESET}"
    done
else
    echo -e "${CYAN}${BOLD}  ═══ ${HEADER} ═══${RESET}"
fi
echo ""

# ASCII art
if [ -f "$ART_FILE" ]; then
    while IFS= read -r line; do
        echo -e "${CYAN}  ${line}${RESET}"
    done < "$ART_FILE"
    echo ""
fi

echo -e "${DIM}  ──────────────────────────────────────────────${RESET}"

# GPU info
if command -v nvidia-smi &>/dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$GPU_INFO" ]; then
        GPU_NUM=0
        while IFS=', ' read -r name temp mem_used mem_total; do
            echo -e "${GREEN}  GPU ${GPU_NUM}:${RESET} ${name}  ${temp}°C  ${mem_used}/${mem_total} MiB"
            ((GPU_NUM++))
        done <<< "$GPU_INFO"
    fi
fi

# CPU
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
LOAD=$(cut -d' ' -f1-3 /proc/loadavg)
echo -e "${GREEN}  CPU:${RESET} ${CPU_MODEL}  Load: ${LOAD}"

# Memory
MEM_INFO=$(free -h | awk '/^Mem:/ {print $3 "/" $2}')
echo -e "${GREEN}  Mem:${RESET} ${MEM_INFO}"

# Disks
DISK_ROOT=$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
echo -e "${GREEN}  Disk /:${RESET} ${DISK_ROOT}"
if mountpoint -q /mnt/data 2>/dev/null; then
    DISK_DATA=$(df -h /mnt/data | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')
    echo -e "${GREEN}  Disk /mnt/data:${RESET} ${DISK_DATA}"
fi

# Uptime
UPTIME=$(uptime -p | sed 's/up //')
echo -e "${GREEN}  Uptime:${RESET} ${UPTIME}"

# Docker
if command -v docker &>/dev/null; then
    CONTAINERS=$(docker ps -q 2>/dev/null | wc -l)
    echo -e "${GREEN}  Docker:${RESET} ${CONTAINERS} containers running"
fi

echo -e "${DIM}  ──────────────────────────────────────────────${RESET}"
echo ""
OUTER

# Replace placeholders
sed -i "s|__ART_DIR__|${ART_DIR}|g" "$MOTD_SCRIPT"
sed -i "s|__ART_GLOB__|${ART_GLOB}|g" "$MOTD_SCRIPT"
sed -i "s|__HEADER__|${HEADER_TEXT}|g" "$MOTD_SCRIPT"

chmod 755 "$MOTD_SCRIPT"
ok "MOTD installed at ${MOTD_SCRIPT}"
