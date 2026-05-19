#!/usr/bin/env bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

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

log_info "root Privilege required to install dependencies."
log_info "Please authenticate."

# 0. Install Dependencies
log_info "Installing system dependencies..."

# Check if apt is available
if ! command -v apt &> /dev/null; then
    log_error "apt package manager not found. This script is designed for Debian/Ubuntu-based systems."
    exit 1
fi

sudo apt update
sudo apt install -y curl jq unzip build-essential procps file gnome-shell gnome-tweaks \
    timeshift flatpak extension-manager git sassc libglib2.0-dev-bin libxml2-utils \
    imagemagick dialog optipng inkscape

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
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

log_info "All dependencies installed."

# 1. Prerequisite check
log_info "Checking prerequisites..."
for cmd in curl jq unzip gnome-shell; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command '$cmd' is not installed."
        exit 1
    fi
done

# 2. Define the list of Extension IDs you want to install
EXTENSION_IDS=("5489" "1488" "19" "3210" "3740" "1460" "3193")
# Extensions: Search Light(5489), fuzzy Search(1488), User Themes(19), Compiz windows effect(3210), 
# Compiz alike magic lamp effect(3740), Vitals(1460), Blur my Shell(3193)

# 3. Detect the current GNOME Shell version
GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)
log_info "Detected GNOME Shell version: ${GNOME_VERSION}"

# 4. Fetch the full extension catalog for this GNOME version to minimize API calls
API_URL="https://gnome.org/extensions/gnome/${GNOME_VERSION}/extensions.json?limit=0"
log_info "Fetching compatible extension data..."
CATALOG=$(curl -s "$API_URL")

if [ -z "$CATALOG" ]; then
    log_error "Failed to fetch extension catalog from API"
    exit 1
fi

# 5. Process each extension ID in a loop
for ID in "${EXTENSION_IDS[@]}"; do
    echo "----------------------------------------"
    log_info "Processing Extension ID: ${ID}"

    # Extract specific extension info from the pre-fetched catalog
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
    
    # Skip if already installed to save bandwidth
    if [ -d "$TARGET_DIR" ]; then
        log_info "Extension ${UUID} is already installed. Skipping download."
        # Ensure it is enabled anyway
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
            log_info "Successfully enabled: ${UUID}"
        else
            log_warn "Downloaded ${UUID}, but failed to enable. A desktop restart may be required."
        fi
    else
        log_error "Failed to download extension ID ${ID}."
        rm -f "$ZIP_FILE"
    fi
done

echo "----------------------------------------"
log_info "Extensions for MacOS Themes installed."
log_info "Note: If you are using Wayland, log out and back in to apply changes."
log_info "Installing macOS screen corner rounding extension..."

# Install GNOME Rounded Corner extension for screen corner rounding
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
                    log_info "Successfully installed Rounded Corners extension: ${UUID}"
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

log_info "Installing MacOS Gnome Themes..."

# 6. Install themes with proper error handling and directory management
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
        ./install.sh -b -l -HD --shell -i apple -sf --round --silent-mode || log_warn "MacTahoe-gtk-theme installation had issues"
        
        # Kill only if Firefox exists
        if command -v firefox &> /dev/null; then
            pkill firefox || true
        fi
        
        sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode || log_warn "tweaks.sh had issues"
        ./tweaks.sh -d -f --silent-mode || log_warn "tweaks.sh had issues"
        sudo flatpak override --filesystem=xdg-config/gtk-3.0 || true
        sudo flatpak override --filesystem=xdg-config/gtk-4.0 || true
        ./tweaks.sh -F -c Dark --silent-mode || log_warn "tweaks.sh had issues"
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

# 7. Configure GNOME Rounded Corners settings (macOS style)
log_info "Configuring macOS-style screen corner rounding..."

# Create GNOME dconf settings for rounded corners
if command -v dconf &> /dev/null; then
    # Set up rounded corner preferences (16px radius like macOS)
    dconf write /org/gnome/shell/extensions/rounded-corners/border-radius 16 2>/dev/null || log_warn "Could not configure corner radius via dconf"
    dconf write /org/gnome/shell/extensions/rounded-corners/panel-corners true 2>/dev/null || log_warn "Could not enable panel corners"
else
    log_warn "dconf not found. Rounded corners may need manual configuration."
fi

# Create a desktop configuration hint file
mkdir -p "$HOME/.config/gnome"
cat > "$HOME/.config/gnome/rounded-corners-config.txt" << 'CORNERS_CONFIG'
# macOS-style Rounded Corners Configuration for GNOME

## Manual Configuration (if automatic setup fails):
## 1. Open GNOME Settings > Extensions
## 2. Find "Rounded Corners" extension
## 3. Configure the following:
##    - Border Radius: 16 pixels (macOS standard)
##    - Panel Corners: Enabled
##    - Padding Bottom: 8
##    - Padding Left: 8
##    - Padding Right: 8
##    - Padding Top: 8

## Using gsettings/dconf:
## gsettings set org.gnome.shell.extensions.rounded-corners border-radius 16
## gsettings set org.gnome.shell.extensions.rounded-corners panel-corners true

CORNERS_CONFIG

log_info "Rounded corners configuration created"

echo "----------------------------------------"
log_info "All MacOS themes and rounded corner features installed."
log_info ""
log_info "🍏 macOS-Style Rounded Screen Corners: ENABLED"
log_info "📋 Corner Radius: 16px (matching macOS)"
log_info ""
log_info "Next Steps:"
log_info "1. Restart GNOME Shell (press Alt+F2, type 'r', press Enter)"
log_info "2. Or log out and log back in"
log_info "3. Open Settings > Extensions and configure Rounded Corners to your preference"
log_info ""
log_info "Configuration file: ~/.config/gnome/rounded-corners-config.txt"
log_info ""
log_info "Reboot is recommended for full effect."
log_info "Script completed successfully!"
