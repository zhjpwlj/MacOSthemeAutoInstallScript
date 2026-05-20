#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# 🍏 macOS Liquid-Glass Installer for Ubuntu/GNOME
# ============================================================================
# Compatible with: Ubuntu 22.04+, GNOME 42+
# ============================================================================

# Check if Firefox is missing across all formats (PATH, Snap, Flatpak, APT)
if ! command -v firefox &> /dev/null && \
   ! { command -v snap &> /dev/null && snap list | grep -qi "firefox"; } && \
   ! { command -v flatpak &> /dev/null && flatpak list | grep -qi "firefox"; } && \
   ! { dpkg -l | grep -E "^ii" | grep -qi "firefox"; }; then
    
    echo "Firefox not found. Installing..."
    
    # Your installation commands here
    sudo apt-get update
    sudo apt-get install -y firefox

else
    echo "Firefox is already installed. Skipping installation."
fi

nohup firefox > /dev/null 2>&1 &

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!] WARNING:${NC} $*"; }
log_error() { echo -e "${RED}[✗] ERROR:${NC} $*" >&2; }
log_header() { echo -e "\n${BLUE}========================================================${NC}\n${BLUE}$1${NC}\n${BLUE}========================================================${NC}\n"; }

# Exit handler for cleanup
trap 'log_error "Script failed at line $LINENO"; exit 1' ERR

# Working directory for theme clones
WORK_DIR="/tmp/macos-themes-$$"
mkdir -p "$WORK_DIR"

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

log_header "🍏 macOS Liquid-Glass Theme Installer for Ubuntu/GNOME"

log_info "Root privilege required to install dependencies."
log_info "Please authenticate."

# ============================================================================
# Step 0: Install Dependencies
# ============================================================================
log_header "Step 0/7: Installing System Dependencies"

log_info "Installing system dependencies..."

# Check if apt is available
if ! command -v apt &> /dev/null; then
    log_error "apt package manager not found. This script is designed for Debian/Ubuntu-based systems."
    exit 1
fi

sudo apt update
sudo apt install -y curl jq unzip build-essential procps file gnome-shell gnome-tweaks \
    timeshift flatpak git sassc libglib2.0-dev-bin libxml2-utils \
    imagemagick dialog optipng inkscape dconf-cli

# Install Homebrew first
log_info "Installing Homebrew..."
if ! command -v brew &> /dev/null; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Set up Homebrew environment
    if [ -d ~/.linuxbrew ]; then
        eval "$(~/.linuxbrew/bin/brew shellenv)"
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    elif [ -d /home/linuxbrew/.linuxbrew ]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
        echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc
    fi
else
    log_warn "Homebrew is already installed"
fi

# Now install gum via Homebrew
brew install gum

# Setup Flatpak
sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

sudo flatpak install -y flathub com.mattjakeman.ExtensionManager

log_success "All dependencies installed."

# ============================================================================
# Step 1: Prerequisite Check
# ============================================================================
log_header "Step 1/7: Checking Prerequisites"

log_info "Checking prerequisites..."
for cmd in curl jq unzip gnome-shell; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command '$cmd' is not installed."
        exit 1
    fi
done

log_success "All prerequisites met"

# ============================================================================
# Step 2: Install GNOME Extensions
# ============================================================================
log_header "Step 2/7: Installing GNOME Extensions"

# Define the list of Extension IDs
EXTENSION_IDS=("5489" "1488" "19" "3210" "3740" "1460" "3193")
# Extensions: Search Light(5489), fuzzy Search(1488), User Themes(19), Compiz windows effect(3210), 
# Compiz alike magic lamp effect(3740), Vitals(1460), Blur my Shell(3193)

# Detect the current GNOME Shell version
GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)
log_info "Detected GNOME Shell version: ${GNOME_VERSION}"

# Fetch the full extension catalog for this GNOME version
API_URL="https://gnome.org/extensions/gnome/${GNOME_VERSION}/extensions.json?limit=0"
log_info "Fetching compatible extension data..."
CATALOG=$(curl -s "$API_URL")

if [ -z "$CATALOG" ]; then
    log_error "Failed to fetch extension catalog from API"
    exit 1
fi

# Process each extension ID
for ID in "${EXTENSION_IDS[@]}"; do
    echo "----------------------------------------"
    log_info "Processing Extension ID: ${ID}"

    # Extract specific extension info from catalog
    EXTENSION_INFO=$(echo "$CATALOG" | jq --arg id "$ID" '.extensions[] | select(.pk == ($id | tonumber))' 2>/dev/null || echo "")

    if [ -z "$EXTENSION_INFO" ]; then
        log_warn "Extension ID ${ID} not found or incompatible with GNOME ${GNOME_VERSION}. Skipping."
        continue
    fi

    # Parse details
    UUID=$(echo "$EXTENSION_INFO" | jq -r '.uuid')
    DOWNLOAD_URL=$(echo "$EXTENSION_INFO" | jq -r '.download_url')

    log_info "Found: ${UUID}"
    
    # Define target path
    TARGET_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"
    
    # Skip if already installed
    if [ -d "$TARGET_DIR" ]; then
        log_info "Extension ${UUID} is already installed. Skipping download."
        gnome-extensions enable "$UUID" || log_warn "Failed to enable existing extension ${UUID}"
        continue
    fi

    # Download and extract
    mkdir -p "$TARGET_DIR"
    ZIP_FILE=$(mktemp)
    if curl -sL -o "$ZIP_FILE" "$DOWNLOAD_URL"; then
        unzip -oq "$ZIP_FILE" -d "$TARGET_DIR"
        rm -f "$ZIP_FILE"
        
        # Compile schemas
        if [ -d "${TARGET_DIR}/schemas" ]; then
            glib-compile-schemas "${TARGET_DIR}/schemas"
        fi

        # Enable extension
        if gnome-extensions enable "$UUID"; then
            log_success "Successfully enabled: ${UUID}"
        else
            log_warn "Downloaded ${UUID}, but failed to enable. A desktop restart may be required."
        fi
    else
        log_error "Failed to download extension ID ${ID}."
        rm -f "$ZIP_FILE"
    fi
done

echo "----------------------------------------"
log_success "Extensions for macOS themes installed."
log_info "Note: If you are using Wayland, log out and back in to apply changes."

# ============================================================================
# Step 3: Install Rounded Corners Extension
# ============================================================================
log_header "Step 3/7: Installing macOS-Style Rounded Corners Extension"

log_info "Installing GNOME Rounded Corners extension..."
ROUNDED_CORNER_ID="7986"
if ! grep -q "$ROUNDED_CORNER_ID" <<< "${EXTENSION_IDS[@]}"; then
    echo "----------------------------------------"
    EXTENSION_INFO=$(echo "$CATALOG" | jq --arg id "$ROUNDED_CORNER_ID" '.extensions[] | select(.pk == ($id | tonumber))' 2>/dev/null || echo "")
    
    if [ -n "$EXTENSION_INFO" ]; then
        UUID=$(echo "$EXTENSION_INFO" | jq -r '.uuid')
        DOWNLOAD_URL=$(echo "$EXTENSION_INFO" | jq -r '.download_url')
        TARGET_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"
        
        if [ ! -d "$TARGET_DIR" ]; then
            mkdir -p "$TARGET_DIR"
            ZIP_FILE=$(mktemp)
            if curl -sL -o "$ZIP_FILE" "$DOWNLOAD_URL"; then
                unzip -oq "$ZIP_FILE" -d "$TARGET_DIR"
                rm -f "$ZIP_FILE"
                
                if [ -d "${TARGET_DIR}/schemas" ]; then
                    glib-compile-schemas "${TARGET_DIR}/schemas"
                fi
                
                if gnome-extensions enable "$UUID"; then
                    log_success "Successfully installed Rounded Corners extension: ${UUID}"
                else
                    log_warn "Rounded Corners extension installed but failed to enable. Desktop restart may be required."
                fi
            fi
        else
            log_info "Rounded Corners extension already installed"
            gnome-extensions enable "$UUID" || log_warn "Failed to enable Rounded Corners extension"
        fi
    else
        log_warn "Rounded Corners extension not available for this GNOME version"
    fi
fi

echo "----------------------------------------"
log_success "Rounded Corners extension installed"

# ============================================================================
# Step 4: Install macOS Themes
# ============================================================================
log_header "Step 4/7: Installing macOS GTK Themes"

cd "$WORK_DIR"

# Clone and install GNOME-macOS-Tahoe
log_info "Installing GNOME-macOS-Tahoe theme..."
if git clone https://github.com/kayozxo/GNOME-macOS-Tahoe; then
    cd GNOME-macOS-Tahoe
    if [ -f install.sh ]; then
        ./install.sh -l -d -la --flatpak || log_warn "GNOME-macOS-Tahoe installation had issues"
        sudo flatpak override --filesystem=xdg-config/gtk-3.0 || true
        sudo flatpak override --filesystem=xdg-config/gtk-4.0 || true
    else
        log_warn "install.sh not found in GNOME-macOS-Tahoe"
    fi
    cd "$WORK_DIR"
else
    log_warn "Failed to clone GNOME-macOS-Tahoe"
fi

# Clone and install MacTahoe-gtk-theme
log_info "Installing MacTahoe-gtk-theme..."
if git clone https://github.com/vinceliuice/MacTahoe-gtk-theme.git --depth=1; then
    cd MacTahoe-gtk-theme
    if [ -f install.sh ]; then
        sudo ./install.sh -b -l -HD --shell -i apple -sf --round --silent-mode || log_warn "MacTahoe-gtk-theme installation had issues"
        ./install.sh -l

        # Kill only if Firefox exists
        if command -v firefox &> /dev/null; then
            pkill firefox || true
        fi
        
        sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode || log_warn "tweaks.sh had issues"
        sudo ./tweaks.sh -d -f --silent-mode || log_warn "tweaks.sh had issues"
        sudo flatpak override --filesystem=xdg-config/gtk-3.0 || true
        sudo flatpak override --filesystem=xdg-config/gtk-4.0 || true
        sudo ./tweaks.sh -F -c Dark --silent-mode || log_warn "tweaks.sh had issues"
    else
        log_warn "install.sh not found in MacTahoe-gtk-theme"
    fi
    cd "$WORK_DIR"
else
    log_warn "Failed to clone MacTahoe-gtk-theme"
fi

# Clone and install MacTahoe-icon-theme
log_info "Installing MacTahoe-icon-theme..."
if git clone https://github.com/vinceliuice/MacTahoe-icon-theme.git; then
    cd MacTahoe-icon-theme
    if [ -f install.sh ]; then
        ./install.sh -b || log_warn "MacTahoe-icon-theme installation had issues"
        
        if [ -d cursors ] && [ -f cursors/install.sh ]; then
            cd cursors
            sudo ./install.sh || log_warn "Cursor installation had issues"
            cd ..
        fi
    else
        log_warn "install.sh not found in MacTahoe-icon-theme"
    fi
    cd "$WORK_DIR"
else
    log_warn "Failed to clone MacTahoe-icon-theme"
fi

echo "----------------------------------------"
log_success "All macOS GTK themes installed"

# ============================================================================
# Step 5: Configure Rounded Corners Settings
# ============================================================================
log_header "Step 5/7: Configuring macOS-Style Rounded Corners (16px radius)"

log_info "Applying rounded corner settings..."

# Create configuration directory
mkdir -p "$HOME/.config/gnome"

# Apply dconf settings for rounded corners
if command -v dconf &> /dev/null; then
    # Set rounded corner preferences (16px radius like macOS)
    dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16 2>/dev/null || log_warn "Could not configure corner radius via dconf"
    dconf write /org/gnome/shell/extensions/rounded-corners/panel-corners true 2>/dev/null || log_warn "Could not enable panel corners"
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 8 2>/dev/null || log_warn "Could not set padding"
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 8 2>/dev/null || log_warn "Could not set padding"
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 8 2>/dev/null || log_warn "Could not set padding"
    dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 8 2>/dev/null || log_warn "Could not set padding"
    log_success "Rounded corners configuration applied"
else
    log_warn "dconf not found. Rounded corners may need manual configuration."
fi

# Create configuration documentation
mkdir -p "$HOME/.config/gnome/corner-rounding"
cat > "$HOME/.config/gnome/corner-rounding/README.md" << 'CORNERS_README'
# macOS-Style Screen Corner Rounding Configuration for GNOME

## Overview
This directory contains the macOS-style rounded corner configuration for GNOME.

## Current Settings
- **Corner Radius**: 16 pixels (macOS standard)
- **Panel Corners**: Enabled
- **Padding**: 8px (bottom, left, right, top)
- **Extension**: GNOME Rounded Corners

## Configuration Files
Settings are applied via dconf configuration.

## Adjusting Corner Radius

### Increase Roundness (more pronounced curves)
```bash
dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 20
```

### Decrease Roundness (more subtle corners)
```bash
dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 12
```

### Adjust Padding
```bash
dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 10
dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 10
dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 10
dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 10
```

### Using GNOME Settings (GUI)
1. Open **Settings** > **Extensions**
2. Find **Rounded Corners** in the list
3. Click the gear icon to open preferences
4. Adjust "Border Radius" slider (default: 16px)
5. Enable/disable "Panel Corners"
6. Adjust padding values

## Restart GNOME Shell
After making changes, restart GNOME Shell:
```bash
# Method 1: Keyboard shortcut
Alt+F2, then type 'r' and press Enter

# Method 2: Restart GNOME Shell
gnome-shell --replace

# Method 3: Log out and back in
```

## Troubleshooting
- **Corners not visible?** Ensure GPU drivers are properly installed
- **Performance issues?** The extension uses minimal resources; check other extensions
- **Settings not applying?** Try restarting GNOME Shell or the system
- **Reset to defaults?** Set border-radius back to 16 and padding to 8

## References
- GNOME Rounded Corners Extension: https://extensions.gnome.org/extension/7986/rounded-corners/
- macOS corner radius: ~16-18 pixels on 1x scale
CORNERS_README

# Create quick configuration script
cat > "$HOME/.config/gnome/corner-rounding/apply-config.sh" << 'APPLY_SCRIPT'
#!/bin/bash
# Quick script to apply macOS-style corner settings

echo "Applying macOS-style rounded corners (16px)..."
dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16
dconf write /org/gnome/shell/extensions/rounded-corners/panel-corners true
dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 8
dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 8

echo "✓ Configuration applied!"
echo "Restart GNOME Shell with: Alt+F2, then 'r'"
APPLY_SCRIPT

chmod +x "$HOME/.config/gnome/corner-rounding/apply-config.sh"

log_success "Rounded corners configuration created"

# ============================================================================
# Step 6: Create Configuration File
# ============================================================================
log_header "Step 6/7: Creating Configuration Reference File"

cat > "$HOME/.config/gnome/rounded-corners-config.txt" << 'CORNERS_CONFIG'
================================================================================
🍏 macOS-Style Rounded Corners Configuration for GNOME
================================================================================

INSTALLED EXTENSION:
  - GNOME Rounded Corners (ID: 7986)
  - Location: ~/.local/share/gnome-shell/extensions/

CURRENT SETTINGS:
  - Border Radius: 16 pixels (macOS standard)
  - Panel Corners: Enabled
  - Padding: 8px (all sides)

MANUAL CONFIGURATION OPTIONS:

1. Using GNOME Settings (Easiest):
   a. Open Settings > Extensions
   b. Find "Rounded Corners"
   c. Click the gear icon for preferences
   d. Adjust Border Radius slider
   e. Settings are applied immediately

2. Using Command Line (dconf):
   - Check current settings:
     dconf dump /org/gnome/shell/extensions/rounded-corners/
   
   - Set border radius:
     dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16
   
   - Set corner padding:
     dconf write /org/gnome/shell/extensions/rounded-corners/padding-bottom 8
     dconf write /org/gnome/shell/extensions/rounded-corners/padding-left 8
     dconf write /org/gnome/shell/extensions/rounded-corners/padding-right 8
     dconf write /org/gnome/shell/extensions/rounded-corners/padding-top 8

3. Using gsettings:
   gsettings set org.gnome.shell.extensions.rounded-corners border-radius 16
   gsettings set org.gnome.shell.extensions.rounded-corners panel-corners true

RECOMMENDED VALUES:
  - Subtle (12px):    For minimal visual change
  - Default (16px):   Matches macOS aesthetic (RECOMMENDED)
  - Pronounced (20px): More visible rounded effect

RESTART OPTIONS:
  - Alt+F2, type 'r', press Enter (Quick restart)
  - Log out and back in (Full restart)
  - Reboot system (Complete reset)

ADDITIONAL CONFIG FILE:
  - Helper script: ~/.config/gnome/corner-rounding/apply-config.sh
  - Documentation: ~/.config/gnome/corner-rounding/README.md

================================================================================
CORNERS_CONFIG

log_success "Configuration reference file created"

# ============================================================================
# Step 7: Final Summary
# ============================================================================
log_header "🎉 Installation Complete!"

cat << 'SUMMARY_EOF'

========================================================
✅ macOS Theme Installation Successfully Completed!
========================================================

🍏 FEATURES INSTALLED:
  ✓ GNOME Extensions (7 extensions)
    - Search Light, Fuzzy Search, User Themes
    - Compiz window effects, Magic Lamp effect
    - Vitals monitoring, Blur My Shell
  
  ✓ Rounded Corners Extension
    - 16px radius (matching macOS)
    - Panel corner rounding enabled
    - Smart padding configuration
  
  ✓ macOS Themes
    - GNOME-macOS-Tahoe theme
    - MacTahoe GTK theme
    - MacTahoe icon theme
    - macOS-style cursors

📋 NEXT STEPS:
  1. Restart GNOME Shell:
     - Press Alt+F2
     - Type: r
     - Press Enter
     
  2. Or log out and log back in for full effect

  3. Open Settings > Extensions to verify all extensions are enabled

  4. Configure additional preferences in:
     Settings > Extensions > Rounded Corners

💾 CONFIGURATION FILES:
  - Theme config: ~/.config/gnome/
  - Corners config: ~/.config/gnome/corner-rounding/
  - Settings reference: ~/.config/gnome/rounded-corners-config.txt
  - Quick apply script: ~/.config/gnome/corner-rounding/apply-config.sh

🖥️ QUICK CUSTOMIZATION:
  To adjust corner radius:
  dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 20

  To check current settings:
  dconf dump /org/gnome/shell/extensions/rounded-corners/

🎨 APPLIED STYLES:
  ✓ macOS Liquid Glass theme
  ✓ System-wide rounded corners (16px)
  ✓ Smooth animations
  ✓ Frosted glass effects (via Blur My Shell)
  ✓ macOS-inspired visual aesthetic

⚙️ SYSTEM INFO:
  - Desktop Environment: GNOME ${GNOME_VERSION}
  - Theme Framework: GTK
  - Display Server: Wayland/X11 (Auto-detected)

📝 TROUBLESHOOTING:
  - Extensions not loading? Check GNOME version compatibility
  - Rounded corners not visible? Ensure GPU drivers are updated
  - Settings not persisting? Try full system restart
  - Need to re-apply settings? Run: ~/.config/gnome/corner-rounding/apply-config.sh

💡 ADDITIONAL RESOURCES:
  - README: ~/.config/gnome/corner-rounding/README.md
  - GNOME Extensions: extensions.gnome.org
  - Rounded Corners: https://extensions.gnome.org/extension/7986/

========================================================
Enjoy your macOS-themed Ubuntu desktop! 🍎
========================================================

SUMMARY_EOF

log_success "Script completed successfully!"
log_info "Reboot is recommended for full effect."

