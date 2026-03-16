#!/bin/bash
# ══════════════════════════════════════════════
# Post-Install: Update MOTD ASCII art
# Copies art from ascii-art/<machine>/ to /etc/motd-art/
# and re-runs 04-motd.sh to regenerate the MOTD script.
# ══════════════════════════════════════════════
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/config.env"

G='\033[1;32m'; C='\033[1;36m'; Y='\033[1;33m'; R='\033[0m'
ok()   { echo -e "  ${G}✓${R} $1"; }
warn() { echo -e "  ${Y}!${R} $1"; }
step() { echo -e "\n${C}══════════════════════════════════════════════${R}"; echo -e "${C}  $1${R}"; echo -e "${C}══════════════════════════════════════════════${R}"; }

export MACHINE_NAME SETUP_USER PROMPT_EMOJI

ART_SRC="$SCRIPT_DIR/ascii-art/${MACHINE_NAME,,}"
ART_DEST="/etc/motd-art"

step "Update MOTD Art"

if [ ! -d "$ART_SRC" ]; then
    warn "No art folder found: $ART_SRC"
    echo "  Create the folder, add .txt files, and re-run this script."
    exit 1
fi

# Count art files
ART_COUNT=$(find "$ART_SRC" -maxdepth 1 -name '*.txt' -type f 2>/dev/null | wc -l)

if [ "$ART_COUNT" -eq 0 ]; then
    warn "Art folder is empty: $ART_SRC"
    echo "  Add .txt files to the folder and re-run this script."
    exit 1
fi

# Clear and re-copy
rm -rf "$ART_DEST"
mkdir -p "$ART_DEST"
cp "$ART_SRC"/*.txt "$ART_DEST/"
chmod 644 "$ART_DEST"/*.txt
ok "Copied ${ART_COUNT} art files to ${ART_DEST}"

# Re-run MOTD setup
echo ""
bash "$SCRIPT_DIR/scripts/04-motd.sh"
ok "MOTD updated with new art"

echo ""
echo "  Test with: run-parts /etc/update-motd.d/"
echo ""
