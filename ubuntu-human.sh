#!/usr/bin/env bash
set -euo pipefail

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug)
      set -x
      shift
      ;;
    *)
      shift
      ;;
  esac
done

TMP_DIR=""

# Check if GNOME is installed
if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
  echo "This installer requires GNOME"
  exit 1
fi

# Check internet connection
if ! curl -fsSL https://github.com >/dev/null; then
  echo "No internet connection"
  exit 1
fi

echo "Requesting sudo permissions..."
sudo -v

# Open Firefox to keep it warm during installation
if command -v firefox >/dev/null; then
  pgrep firefox >/dev/null || firefox >/dev/null 2>&1 &
fi

# ============================================================================
# Helper Functions
# ============================================================================

create_temp_dir() {
  TMP_DIR="$(mktemp -d)"
  cd "$TMP_DIR" || exit 1
}

install_dependencies() {
  sudo mkdir -p /etc/apt/keyrings
  
  # Setup Charm repository for gum
  if [ ! -f /etc/apt/keyrings/charm.gpg ]; then
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/charm.gpg
  fi
  if [ ! -f /etc/apt/sources.list.d/charm.list ]; then
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list >/dev/null
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
  
  # Setup Flatpak
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  
  # Install GNOME Extensions CLI
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
  extensions=(
    5489
    1488
    19
    3740
    1460
    3193
    1319
    3843
    5848
    779
    5090
    4422
    3986
    3888
    22
    4451
    3951
    3990
    4245
    5387
  )
  # Search light ,Fuzzy search ,User themes, Compiz alike magic lamp effect, Vitals, Blur my shell, Gsconnect, Just perfection, Notification banner position, Clipboard indicator, Space bar, Ubuntu tilting assistant, App menu is back, Fildem global menu, Coverflow alt+tab, Logo menu, Rounded corners, Dash2dock animated, Gesture improvements, Control center
  
  for ext in "${extensions[@]}"; do
    echo "Installing extension $ext..."
    gext install "$ext" || {
      echo "Warning: Failed to install extension $ext"
      continue
    }
    gext enable "$ext" || {
      echo "Warning: Failed to enable extension $ext"
    }
  done
}

install_macos_gtk_theme() {
  # Clone and install GTK theme
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git
  cd "$TMP_DIR/MacTahoe-gtk-theme" || exit 1
  sudo ./install.sh -b -HD --shell -i apple -sf --round --silent-mode
  ./install.sh -l
  pkill firefox || true
  sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode
  ./tweaks.sh -f -e
  sudo ./tweaks.sh -F -c Dark --silent-mode
  cd "$TMP_DIR" || exit 1
}

install_gnome_macos_tahoe_theme() {
  # Clone and install GNOME macOS Tahoe shell theme
  git clone --depth=1 https://github.com/kayozxo/GNOME-macOS-Tahoe.git
  cd "$TMP_DIR/GNOME-macOS-Tahoe" || exit 1
  sudo ./install.sh -l -d -la --flatpak
  cd "$TMP_DIR" || exit 1
}

install_icon_and_cursor_theme() {
  # Clone and install Icon and Cursor themes
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git
  cd "$TMP_DIR/MacTahoe-icon-theme" || exit 1
  ./install.sh -b
  
  # Install cursor theme
  cd "$TMP_DIR/MacTahoe-icon-theme/cursor" || exit 1
  sudo ./install.sh
  
  cd "$TMP_DIR" || exit 1
}

install_fonts() {
  # Font installation can be added here
  :
}

apply_settings() {
  # Apply GTK, Icon, and Cursor themes
  gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe"
  gsettings set org.gnome.desktop.interface icon-theme "MacTahoe"
  gsettings set org.gnome.desktop.interface cursor-theme "MacTahoe"
  
  # Override Flatpak configuration for GTK theming
  flatpak override --user --filesystem=xdg-config/gtk-3.0
  flatpak override --user --filesystem=xdg-config/gtk-4.0
}

cleanup() {
  [ -n "${TMP_DIR:-}" ] && rm -rf "$TMP_DIR"
}

# ============================================================================
# Main Installation Flow
# ============================================================================

main() {
  gum spin --title "[1/6] Installing dependencies..." -- install_dependencies
  
  gum spin --title "[2/6] Creating temporary workspace..." -- create_temp_dir
  
  gum spin --title "[3/6] Installing GNOME extensions..." -- install_extensions
  
  gum spin --title "[4/6] Installing macOS GTK theme..." -- install_macos_gtk_theme
  
  gum spin --title "[5/6] Installing GNOME macOS shell theme..." -- install_gnome_macos_tahoe_theme
  
  gum spin --title "[6/6] Installing icon and cursor themes..." -- install_icon_and_cursor_theme
  
  gum spin --title "Applying settings..." -- apply_settings
  
  echo ""
  echo "Setup completed successfully!"
}

trap cleanup EXIT
main
