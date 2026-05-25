#!/usr/bin/env bash

set -euo pipefail

TMP_DIR=""

if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
    echo "This installer requires GNOME"
    exit 1
fi

if ! curl -fsSL https://github.com >/dev/null; then
    echo "No internet connection"
    exit 1
fi

echo "Requesting sudo permissions..."
sudo -v

if command -v firefox >/dev/null; then
    pgrep firefox >/dev/null || firefox >/dev/null 2>&1 &
fi

create_temp_dir() {
    TMP_DIR="$(mktemp -d)"
    cd "$TMP_DIR"
}

install_dependencies() {

    sudo mkdir -p /etc/apt/keyrings

    if [ ! -f /etc/apt/keyrings/charm.gpg ]; then
        curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg
    fi

    if [ ! -f /etc/apt/sources.list.d/charm.list ]; then
        echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" \
            | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
    fi

    sudo apt update

    sudo apt install -y -qq \
        curl \
        jq \
        unzip \
        build-essential \
        procps \
        file \
        pipx \
        gnome-shell \
        gnome-tweaks \
        timeshift \
        flatpak \
        gum \
        git \
        sassc \
        libglib2.0-dev-bin \
        libxml2-utils \
        imagemagick \
        dialog \
        optipng \
        inkscape \
        dconf-cli \
        gnome-sushi

    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    pipx ensurepath

    pipx install gnome-extensions-cli \
        --system-site-packages \
        || true

    export PATH="$HOME/.local/bin:$PATH"

    hash -r

    command -v gext >/dev/null || {
        echo "Failed to install gnome-extensions-cli (gext)"
        exit 1
    }
}

install_extensions() {

    extensions=( 5489 1488 19 3740 1460 3193 1319 3843 5848 779 5090 4422 3986 3888 22 4451 3951 3990 4245 5387)
    	
  # Search light ,Fuzzy search ,User themes, Compiz alike magic lamp effect, Vitals, Blur my shell, Gsconnect, Just perfection, Notification banner position, Clipboard indicator, Space bar, Ubuntu tilting assistant, App menu is back, Fildem global menu, Coverflow alt+tab, Logo menu, Rounded corners, Dash2dock animated, Gesture improvements, Control center

    for ext in "${extensions[@]}"; do
        echo "Installing extension $ext..."

        gext install "$ext" || {
            echo "Failed to install extension $ext"
            continue
        }

        gext enable "$ext" || {
            echo "Failed to enable extension $ext"
        }
    done
}

install_macos_theme() {
  # Clone and install GTK theme
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git
  cd MacTahoe-gtk-theme
  sudo ./install.sh -b -HD --shell -i apple -sf --round --silent-mode
  ./install.sh -l
  pkill firefox || true
  sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode
  ./tweaks.sh -f -e
  sudo ./tweaks.sh -F -c Dark --silent-mode
  cd ..

  # Clone and install GNOME macOS Tahoe
  git clone --depth=1 https://github.com/kayozxo/GNOME-macOS-Tahoe.git
  cd GNOME-macOS-Tahoe
  sudo ./install.sh -l -d -la --flatpak
  flatpak override --user --filesystem=xdg-config/gtk-3.0
  flatpak override --user --filesystem=xdg-config/gtk-4.0
  cd ..
  
  # Clone and install Icon theme
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git
  cd MacTahoe-icon-theme
  ./install.sh -b
  cd cursor
  sudo ./install.sh
  cd .. 
  cd .. 

  gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe"

  gsettings set org.gnome.desktop.interface icon-theme "MacTahoe"

  gsettings set org.gnome.desktop.interface cursor-theme "MacTahoe"
}

cleanup() {
    [ -n "${TMP_DIR:-}" ] && rm -rf "$TMP_DIR"
}

main() {

    echo "[1/4] Installing dependencies..."
    install_dependencies

    echo "[2/4] Creating temporary workspace..."
    create_temp_dir

    echo "[3/4] Installing GNOME extensions..."
    install_extensions

    echo "[4/4] Installing macOS Tahoe theme..."
    install_macos_theme

    echo
    echo "Setup completed successfully!"
}

trap cleanup EXIT

main
