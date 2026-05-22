#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

create_temp_dir() {
  # Create a secure temporary directory and move into it
  TMP_DIR=$(mktemp -d)
  cd "$TMP_DIR"
}

install_dependencies() {
  # Set up Charm repository for 'gum'
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
  echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
  sudo apt update

  
  sudo apt install -y -qq \
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
    
  # Install GNOME extensions CLI
  pipx install gnome-extensions-cli --system-site-packages
  
  # Ensure pipx binary path is available in the current session
  export PATH="$HOME/.local/bin:$PATH"
}

install_extensions() {

  gext install 5489 1488 19 3740 1460 3193 1319 3843 5848 779 5090 4422 3986 3888 22 4451 3951 3990 4245 5387
  # Search light ,Fuzzy search ,User themes, Compiz alike magic lamp effect, Vitals, Blur my shell, Gsconnect, Just perfection, Notification banner position, Clipboard indicator, Space bar, Ubuntu tilting assistant, App menu is back, Fildem global menu, Coverflow alt+tab, Logo menu, Rounded corners, Dash2dock animated, Gesture improvements, Control center
  gext enable 5489 1488 19 3740 1460 3193 1319 3843 5848 779 5090 4422 3986 3888 22 4451 3951 3990 4245 5387
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
}

main() {
  echo "Installing dependencies and recommended packages..."
  install_dependencies

  pgrep firefox >/dev/null || firefox &
  
  echo "Creating a temporary directory..."
  create_temp_dir

  echo "Installing all Gnome Extensions required..."
  install_extensions

  echo "Installing MacOS Tahoe Themes for Gnome..."
  install_macos_theme
  
  # 一時ファイルの削除
  rm -rf "$TMP_DIR"
  echo "Setup completed successfully!"

# Execute the script
main
