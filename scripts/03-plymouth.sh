#!/bin/bash
# Install Plymouth boot splash theme
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

THEME_NAME=$(echo "$MACHINE_NAME" | tr '[:upper:]' '[:lower:]')
THEME_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
FONT="${PLYMOUTH_FONT:-future}"
FG="${PLYMOUTH_FG_COLOR:-cyan}"

# Skip if theme already installed and active
CURRENT_DEFAULT=$(update-alternatives --query default.plymouth 2>/dev/null | grep '^Value:' | awk '{print $2}')
if [ "$CURRENT_DEFAULT" = "${THEME_DIR}/${THEME_NAME}.plymouth" ] && [ -f "${THEME_DIR}/${THEME_NAME}.png" ]; then
    ok "Plymouth theme '${THEME_NAME}' already installed and active"
    exit 0
fi

# Generate splash PNG
HEADER_TEXT=$(echo "$MACHINE_NAME" | tr '[:lower:]' '[:upper:]')
if command -v toilet &>/dev/null; then
    SPLASH_TEXT=$(toilet -f "$FONT" "$HEADER_TEXT" 2>/dev/null || echo "$HEADER_TEXT")
else
    SPLASH_TEXT=$(figlet "$HEADER_TEXT" 2>/dev/null || echo "$HEADER_TEXT")
fi

convert -size 800x200 xc:black -fill "$FG" \
    -font "DejaVu-Sans-Mono" -pointsize 40 \
    -gravity center -annotate 0 "$SPLASH_TEXT" \
    /tmp/${THEME_NAME}-splash.png

ok "Generated splash PNG"

# Install theme files
mkdir -p "$THEME_DIR"
cp /tmp/${THEME_NAME}-splash.png "${THEME_DIR}/${THEME_NAME}.png"

# Plymouth script
cat > "${THEME_DIR}/${THEME_NAME}.script" <<SCRIPT
// ${MACHINE_NAME} Plymouth boot splash script
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

logo = Image("${THEME_NAME}.png");
logo_sprite = Sprite(logo);
logo_sprite.SetX(Window.GetWidth() / 2 - logo.GetWidth() / 2);
logo_sprite.SetY(Window.GetHeight() / 2 - logo.GetHeight() / 2);
logo_sprite.SetZ(10);

fun message_callback(text) { }
Plymouth.SetMessageFunction(message_callback);

fun display_normal_callback() { }

fun display_password_callback(prompt, bullets) {
    password_dialog = Image.Text(prompt, 0, 0.8, 0.8);
    password_sprite = Sprite(password_dialog);
    password_sprite.SetX(Window.GetWidth() / 2 - password_dialog.GetWidth() / 2);
    password_sprite.SetY(Window.GetHeight() / 2 + logo.GetHeight() / 2 + 50);
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
SCRIPT

# Plymouth theme descriptor
cat > "${THEME_DIR}/${THEME_NAME}.plymouth" <<PLYM
[Plymouth Theme]
Name=${MACHINE_NAME}
Description=${MACHINE_NAME} boot splash
ModuleName=script

[script]
ImageDir=${THEME_DIR}
ScriptFile=${THEME_DIR}/${THEME_NAME}.script
PLYM

ok "Theme files installed to ${THEME_DIR}"

# Set as default
update-alternatives --install \
    /usr/share/plymouth/themes/default.plymouth default.plymouth \
    "${THEME_DIR}/${THEME_NAME}.plymouth" 200

update-alternatives --set default.plymouth "${THEME_DIR}/${THEME_NAME}.plymouth"

update-initramfs -u
ok "Plymouth theme '${THEME_NAME}' set as default"
