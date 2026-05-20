#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# 🍏 macOS Liquid-Glass Installer for Ubuntu/GNOME
# ============================================================================
# Compatible with: Ubuntu 22.04+, GNOME 42+
# ============================================================================

# ============================================================================
# Logging / Colors
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!] WARNING:${NC} $*"; }
log_error() { echo -e "${RED}[✗] ERROR:${NC} $*" >&2; }

log_header() {
    echo -e "\n${BLUE}========================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================================${NC}\n"
}

# ============================================================================
# Safe append (idempotent)
# ============================================================================

append_once() {
    local line="$1"
    local file="$2"

    touch "$file"

    if ! grep -Fxq "$line" "$file"; then
        echo "$line" >> "$file"
    fi
}

# ============================================================================
# Rollback Helper
# ============================================================================

rollback() {
    log_warn "Attempting rollback guidance..."

    if command -v timeshift &> /dev/null; then
        LAST_SNAPSHOT=$(sudo timeshift --list 2>/dev/null | tail -n 1 | awk '{print $3}' || true)

        if [ -n "${LAST_SNAPSHOT:-}" ]; then
            log_warn "Latest snapshot detected:"
            echo "$LAST_SNAPSHOT"
            echo
            echo "To restore manually:"
            echo "sudo timeshift --restore --snapshot '$LAST_SNAPSHOT'"
        else
            log_warn "No Timeshift snapshot found."
        fi
    else
        log_warn "Timeshift not installed."
    fi
}

trap '
log_error "Script failed at line $LINENO"
rollback
exit 1
' ERR

# ============================================================================
# Cleanup
# ============================================================================

WORK_DIR="/tmp/macos-themes-$$"
mkdir -p "$WORK_DIR"

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$WORK_DIR"
}

trap cleanup EXIT

# ============================================================================
# Agreement Screen
# ============================================================================

clear

cat << 'EOF'
========================================================
🍏 macOS Liquid-Glass Installer
========================================================

WARNING:

This script will:

- Install GNOME extensions
- Modify GTK themes
- Install packages via apt and flatpak
- Apply desktop configuration changes
- Install third-party themes and extensions
- Create a Timeshift restore snapshot

This software is provided AS-IS without warranty.

Proceed only if you understand the risks.

========================================================
EOF

read -rp "Do you agree and want to continue? (yes/no): " AGREE

if [[ "$AGREE" != "yes" ]]; then
    echo "Installation cancelled."
    exit 0
fi

# ============================================================================
# Firefox Check
# ============================================================================

if ! command -v firefox &> /dev/null && \
   ! { command -v snap &> /dev/null && snap list | grep -qi "firefox"; } && \
   ! { command -v flatpak &> /dev/null && flatpak list | grep -qi "firefox"; } && \
   ! { dpkg -l | grep -E "^ii" | grep -qi "firefox"; }; then

    log_info "Firefox not found. Installing..."

    sudo apt-get update
    sudo apt-get install -y firefox

else
    log_info "Firefox already installed."
fi

nohup firefox > /dev/null 2>&1 &

# ============================================================================
# Header
# ============================================================================

log_header "🍏 macOS Liquid-Glass Theme Installer for Ubuntu/GNOME"

# ============================================================================
# Distro Check
# ============================================================================

if [ -f /etc/os-release ]; then
    source /etc/os-release

    if [[ "${ID:-}" != "ubuntu" ]]; then
        log_warn "This script is optimized for Ubuntu."
        log_warn "Detected distro: ${ID:-unknown}"
    fi
fi

# ============================================================================
# Create Restore Point
# ============================================================================

log_header "Creating Restore Point"

if command -v timeshift &> /dev/null; then
    log_info "Creating Timeshift snapshot..."

    sudo timeshift --create \
        --comments "Before macOS theme install" \
        --tags D || log_warn "Timeshift snapshot failed"
else
    log_warn "Timeshift not installed yet. Snapshot skipped."
fi

# ============================================================================
# Step 0
# ============================================================================

log_header "Step 0/7: Installing Dependencies"

if ! command -v apt &> /dev/null; then
    log_error "apt package manager not found."
    exit 1
fi

sudo apt update

sudo apt install -y \
    curl \
    jq \
    unzip \
    build-essential \
    procps \
    file \
    gnome-shell \
    gnome-tweaks \
    timeshift \
    flatpak \
    git \
    sassc \
    libglib2.0-dev-bin \
    libxml2-utils \
    imagemagick \
    dialog \
    optipng \
    inkscape \
    dconf-cli

# gum install without Homebrew
log_info "Installing gum..."

if ! command -v gum &> /dev/null; then
    if apt-cache search "^gum$" | grep -q gum; then
        sudo apt install -y gum
    else
        log_warn "gum package unavailable in apt repositories."
    fi
else
    log_info "gum already installed."
fi

# Flatpak setup
sudo flatpak remote-add --if-not-exists flathub \
https://flathub.org/repo/flathub.flatpakrepo

sudo flatpak install -y flathub com.mattjakeman.ExtensionManager

log_success "Dependencies installed."

# ============================================================================
# Step 1
# ============================================================================

log_header "Step 1/7: Checking Prerequisites"

for cmd in curl jq unzip gnome-shell; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Missing required command: $cmd"
        exit 1
    fi
done

GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)

log_success "GNOME version detected: ${GNOME_VERSION}"

# ============================================================================
# Step 2
# ============================================================================

log_header "Step 2/7: Installing GNOME Extensions"

EXTENSION_IDS=("5489" "1488" "19" "3210" "3740" "1460" "3193")

API_URL="https://extensions.gnome.org/extension-query/?shell_version=${GNOME_VERSION}"

log_info "Fetching extension data..."

CATALOG=$(curl -fsSL "$API_URL" || true)

if [ -z "$CATALOG" ]; then
    log_error "Failed to fetch extension catalog."
    exit 1
fi

if ! echo "$CATALOG" | jq empty >/dev/null 2>&1; then
    log_error "Invalid JSON received from GNOME Extensions API."
    exit 1
fi

for ID in "${EXTENSION_IDS[@]}"; do

    echo "----------------------------------------"

    log_info "Processing Extension ID: ${ID}"

    EXTENSION_INFO=$(echo "$CATALOG" | jq --arg id "$ID" '.extensions[]? | select(.pk == ($id | tonumber))' 2>/dev/null || true)

    if [ -z "$EXTENSION_INFO" ]; then
        log_warn "Extension ID ${ID} unavailable or incompatible."
        continue
    fi

    UUID=$(echo "$EXTENSION_INFO" | jq -r '.uuid')
    DOWNLOAD_URL=$(echo "$EXTENSION_INFO" | jq -r '.download_url')

    TARGET_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"

    if [ -d "$TARGET_DIR" ]; then
        log_info "Extension already installed: ${UUID}"

        gnome-extensions enable "$UUID" || true
        continue
    fi

    mkdir -p "$TARGET_DIR"

    ZIP_FILE=$(mktemp)

    if curl -fsSL -o "$ZIP_FILE" "https://extensions.gnome.org${DOWNLOAD_URL}"; then

        unzip -oq "$ZIP_FILE" -d "$TARGET_DIR"

        rm -f "$ZIP_FILE"

        if [ -d "${TARGET_DIR}/schemas" ]; then
            glib-compile-schemas "${TARGET_DIR}/schemas"
        fi

        if gnome-extensions enable "$UUID"; then
            log_success "Enabled extension: ${UUID}"
        else
            log_warn "Installed but failed to enable: ${UUID}"
        fi

    else
        log_warn "Download failed for extension ${ID}"
    fi
done

SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"

if [[ "$SESSION_TYPE" == "wayland" ]]; then
    log_warn "Wayland detected."
    log_warn "Alt+F2 -> r does NOT work on Wayland."
    log_info "Please log out and back in after installation."
else
    log_info "You can restart GNOME Shell using Alt+F2 -> r"
fi

# ============================================================================
# Step 3
# ============================================================================

log_header "Step 3/7: Installing Rounded Corners"

ROUNDED_CORNER_ID="7986"

EXTENSION_INFO=$(echo "$CATALOG" | jq --arg id "$ROUNDED_CORNER_ID" '.extensions[]? | select(.pk == ($id | tonumber))' 2>/dev/null || true)

if [ -n "$EXTENSION_INFO" ]; then

    UUID=$(echo "$EXTENSION_INFO" | jq -r '.uuid')
    DOWNLOAD_URL=$(echo "$EXTENSION_INFO" | jq -r '.download_url')

    TARGET_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"

    if [ ! -d "$TARGET_DIR" ]; then

        mkdir -p "$TARGET_DIR"

        ZIP_FILE=$(mktemp)

        curl -fsSL -o "$ZIP_FILE" "https://extensions.gnome.org${DOWNLOAD_URL}"

        unzip -oq "$ZIP_FILE" -d "$TARGET_DIR"

        rm -f "$ZIP_FILE"

        if [ -d "${TARGET_DIR}/schemas" ]; then
            glib-compile-schemas "${TARGET_DIR}/schemas"
        fi

        gnome-extensions enable "$UUID" || true

        log_success "Rounded Corners installed."

    else
        log_info "Rounded Corners already installed."
    fi

else
    log_warn "Rounded Corners unavailable for this GNOME version."
fi

# ============================================================================
# Step 4
# ============================================================================

log_header "Step 4/7: Installing Themes"

cd "$WORK_DIR"

# GNOME-macOS-Tahoe
log_info "Installing GNOME-macOS-Tahoe..."

if git clone --depth=1 https://github.com/kayozxo/GNOME-macOS-Tahoe.git; then

    cd GNOME-macOS-Tahoe

    if [ -f install.sh ]; then

        ./install.sh -l -d -la --flatpak || true

        flatpak override --user --filesystem=xdg-config/gtk-3.0 || true
        flatpak override --user --filesystem=xdg-config/gtk-4.0 || true
    fi

    cd "$WORK_DIR"
fi

# MacTahoe GTK
log_info "Installing MacTahoe GTK..."

if git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git; then

    cd MacTahoe-gtk-theme

    if [ -f install.sh ]; then

        sudo ./install.sh -b -HD --shell -i apple -sf --round --silent-mode || true

        ./install.sh -l || true

        pkill firefox || true

        sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode || true

        sudo ./tweaks.sh -d -f --silent-mode || true

        flatpak override --user --filesystem=xdg-config/gtk-3.0 || true
        flatpak override --user --filesystem=xdg-config/gtk-4.0 || true

        sudo ./tweaks.sh -F -c Dark --silent-mode || true
    fi

    cd "$WORK_DIR"
fi

# Icons
log_info "Installing icon theme..."

if git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git; then

    cd MacTahoe-icon-theme

    if [ -f install.sh ]; then

        ./install.sh -b || true

        if [ -d cursors ] && [ -f cursors/install.sh ]; then
            cd cursors
            sudo ./install.sh || true
            cd ..
        fi
    fi

    cd "$WORK_DIR"
fi

log_success "Themes installed."

# ============================================================================
# Step 5
# ============================================================================

log_header "Step 5/7: Configuring Rounded Corners"

mkdir -p "$HOME/.config/gnome"

if command -v dconf &> /dev/null; then

    dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16 || true
    dconf write /org/gnome/shell/extensions/rounded-corners/panel-corners true || true

    dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 8 || true
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 8 || true
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 8 || true
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 8 || true

    log_success "Rounded corner configuration applied."

else
    log_warn "dconf unavailable."
fi

# ============================================================================
# Step 6
# ============================================================================

log_header "Step 6/7: Writing Config Files"

mkdir -p "$HOME/.config/gnome/corner-rounding"

cat > "$HOME/.config/gnome/corner-rounding/apply-config.sh" << 'EOF'
#!/bin/bash

dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16
dconf write /org/gnome/shell/extensions/rounded-corners/panel-corners true

dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 8

echo "Configuration applied."
EOF

chmod +x "$HOME/.config/gnome/corner-rounding/apply-config.sh"

log_success "Configuration files created."

# ============================================================================
# Step 7
# ============================================================================

log_header "🎉 Installation Complete!"

cat << EOF

========================================================
✅ Installation Completed
========================================================

GNOME Version:
  ${GNOME_VERSION}

Session Type:
  ${SESSION_TYPE}

Installed:
  ✓ GTK Themes
  ✓ Icon Themes
  ✓ Rounded Corners
  ✓ Blur Effects
  ✓ GNOME Extensions
  ✓ macOS-style Appearance

Restore:
  sudo timeshift --list

Quick Config:
  ~/.config/gnome/corner-rounding/apply-config.sh

========================================================
EOF

log_success "Done."
log_info "A reboot or logout is recommended."
