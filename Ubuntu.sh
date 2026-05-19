#!/usr/bin/env bash
set -euo pipefail

echo "root Privilege required to install dependencies."
echo "please authencate."

# 0. Install Dependencies

sudo apt update
sudo apt install -y curl jq unzip build-essential procps file gnome-shell gnome-tweaks timeshift flatpak extension-manager git sassc libglib2.0-dev-bin libxml2-utils imagemagick dialog optipng inkscape
sudo brew install gum
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
echo "eval \"\$($(brew --prefix)/bin/brew shellenv)\"" >> ~/.bashrc

echo "all dependencies installed."
# 1. Prerequisite check
for cmd in curl jq unzip gnome-shell; do
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: Required command '$cmd' is not installed." >&2
        exit 1
    fi
done

# 2. Define the list of Extension IDs you want to install
EXTENSION_IDS=("5489" "1488" "19" "3210" "3740" "1460" "3193")
# exttensions: Search Light(5489), fuzzy Search(1488), User Themes(19), Compiz windows effect(3210), Compiz alike magic lamp effect(3740), Vitals(1460), Blur my Shell(3193)

# 3. Detect the current GNOME Shell version
GNOME_VERSION=$(gnome-shell --version | cut -d' ' -f3 | cut -d'.' -f1)
echo "Detected GNOME Shell version: ${GNOME_VERSION}"

# 4. Fetch the full extension catalog for this GNOME version to minimize API calls
API_URL="https://gnome.org{GNOME_VERSION}&limit=0"
echo "Fetching compatible extension data..."
CATALOG=$(curl -s "$API_URL")

# 5. Process each extension ID in a loop
for ID in "${EXTENSION_IDS[@]}"; do
    echo "----------------------------------------"
    echo "Processing Extension ID: ${ID}"

    # Extract specific extension info from the pre-fetched catalog
    EXTENSION_INFO=$(echo "$CATALOG" | jq --arg id "$ID" '.pkgs[] | select(.pkgs_id == ($id | tonumber))')

    if [ -z "$EXTENSION_INFO" ]; then
        echo "Warning: Extension ID ${ID} not found or incompatible with GNOME ${GNOME_VERSION}. Skipping."
        continue
    fi

    # Parse details
    UUID=$(echo "$EXTENSION_INFO" | jq -r '.uuid')
    DOWNLOAD_PATH=$(echo "$EXTENSION_INFO" | jq -r '.download_url')
    DOWNLOAD_URL="https://gnome.org${DOWNLOAD_PATH}"

    echo "Found: ${UUID}"
    
    # Define target path
    TARGET_DIR="${HOME}/.local/share/gnome-shell/extensions/${UUID}"
    
    # Skip if already installed to save bandwidth
    if [ -d "$TARGET_DIR" ]; then
        echo "Extension ${UUID} is already installed. Skipping download."
        # Ensure it is enabled anyway
        gnome-extensions enable "$UUID" || true
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
            echo "Successfully enabled: ${UUID}"
        else
            echo "Downloaded ${UUID}, but failed to enable. A desktop restart may be required."
        fi
    else
        echo "Error: Failed to download extension ID ${ID}."
        rm -f "$ZIP_FILE"
    fi
done

echo "----------------------------------------"
echo "extensions for MacOS Themes installed."
echo "Note: If you are using Wayland, log out and back in to apply changes."
echo "installing MacOS Gnome Themes..."

git clone https://github.com/kayozxo/GNOME-macOS-Tahoe
cd GNOME-macOS-Tahoe
./install.sh -l -d -la --flatpak
sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0

git clone https://github.com/vinceliuice/MacTahoe-gtk-theme.git --depth=1
cd MacTahoe-gtk-theme
./install.sh -b -l -HD --shell -i apple -sf --round --silent-mode
pkill firefox
sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode
./tweaks.sh -d -f --silent-mode
sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0
./tweaks.sh -F -c Dark --silent-mode
cd ..

git clone https://github.com/vinceliuice/MacTahoe-icon-theme.git
cd MacTahoe-icon-theme
./install.sh -b
cd cursors
sudo ./install.sh

echo "----------------------------------------"
echo "All MacOS themes installed."
echo "reboot is recommended."
