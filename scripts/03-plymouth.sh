#!/bin/bash
# Install Plymouth boot splash theme
source "$(dirname "$0")/../config.env"

G='\033[1;32m'; R='\033[0m'
ok() { echo -e "  ${G}✓${R} $1"; }

THEME_NAME=$(echo "$MACHINE_NAME" | tr '[:upper:]' '[:lower:]')
THEME_DIR="/usr/share/plymouth/themes/${THEME_NAME}"
FONT="${PLYMOUTH_FONT:-future}"
FG="${PLYMOUTH_FG_COLOR:-cyan}"
DOT_COUNT=5
DOT_SIZE=12

# Skip if theme already installed and active
CURRENT_DEFAULT=$(update-alternatives --query default.plymouth 2>/dev/null | grep '^Value:' | awk '{print $2}')
if [ "$CURRENT_DEFAULT" = "${THEME_DIR}/${THEME_NAME}.plymouth" ] && [ -f "${THEME_DIR}/${THEME_NAME}.png" ] && [ -f "${THEME_DIR}/dot-0.png" ]; then
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

# Generate dot PNGs (bright and dim versions)
for i in $(seq 0 $((DOT_COUNT - 1))); do
    convert -size ${DOT_SIZE}x${DOT_SIZE} xc:none \
        -fill "$FG" -draw "circle $((DOT_SIZE/2)),$((DOT_SIZE/2)) $((DOT_SIZE/2)),0" \
        /tmp/${THEME_NAME}-dot-${i}.png
    convert -size ${DOT_SIZE}x${DOT_SIZE} xc:none \
        -fill "gray30" -draw "circle $((DOT_SIZE/2)),$((DOT_SIZE/2)) $((DOT_SIZE/2)),0" \
        /tmp/${THEME_NAME}-dot-dim-${i}.png
done

ok "Generated dot PNGs"

# Install theme files
mkdir -p "$THEME_DIR"
cp /tmp/${THEME_NAME}-splash.png "${THEME_DIR}/${THEME_NAME}.png"
for i in $(seq 0 $((DOT_COUNT - 1))); do
    cp /tmp/${THEME_NAME}-dot-${i}.png "${THEME_DIR}/dot-${i}.png"
    cp /tmp/${THEME_NAME}-dot-dim-${i}.png "${THEME_DIR}/dot-dim-${i}.png"
done

# Plymouth script
cat > "${THEME_DIR}/${THEME_NAME}.script" <<SCRIPT
// ${MACHINE_NAME} Plymouth boot splash script
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

// Machine name logo — centred
logo = Image("${THEME_NAME}.png");
logo_sprite = Sprite(logo);
logo_sprite.SetX(Window.GetWidth() / 2 - logo.GetWidth() / 2);
logo_sprite.SetY(Window.GetHeight() / 2 - logo.GetHeight() / 2);
logo_sprite.SetZ(10);

// Animated dots — below the logo
dot_count = ${DOT_COUNT};
dot_spacing = ${DOT_SIZE} + 10;
dots_width = dot_count * dot_spacing - 10;
dot_y = Window.GetHeight() / 2 + logo.GetHeight() / 2 + 30;
dot_x_start = Window.GetWidth() / 2 - dots_width / 2;

// Load dot images
for (i = 0; i < dot_count; i++) {
    dot_image[i] = Image("dot-" + i + ".png");
    dot_dim_image[i] = Image("dot-dim-" + i + ".png");
    dot_sprite[i] = Sprite(dot_dim_image[i]);
    dot_sprite[i].SetX(dot_x_start + i * dot_spacing);
    dot_sprite[i].SetY(dot_y);
    dot_sprite[i].SetZ(10);
}

// Animation state
counter = 0;
active_dot = 0;
frames_per_step = 5;

fun refresh_callback() {
    global.counter++;
    if (Math.Int(global.counter % global.frames_per_step) == 0) {
        global.active_dot = Math.Int((global.active_dot + 1) % dot_count);
    }

    for (i = 0; i < dot_count; i++) {
        if (i == global.active_dot)
            dot_sprite[i].SetImage(dot_image[i]);
        else
            dot_sprite[i].SetImage(dot_dim_image[i]);
    }
}

Plymouth.SetRefreshFunction(refresh_callback);

fun message_callback(text) { }
Plymouth.SetMessageFunction(message_callback);

fun display_normal_callback() { }

fun display_password_callback(prompt, bullets) {
    password_dialog = Image.Text(prompt, 0, 0.8, 0.8);
    password_sprite = Sprite(password_dialog);
    password_sprite.SetX(Window.GetWidth() / 2 - password_dialog.GetWidth() / 2);
    password_sprite.SetY(dot_y + ${DOT_SIZE} + 30);
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
