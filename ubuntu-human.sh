create_temp_dir() {
  
}

install_depedencies() {
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
    pipx \
    gun \
    git \
    sassc \
    libglib2.0-dev-bin \
    libxml2-utils \
    imagemagick \
    dialog \
    optipng \
    inkscape \
    dconf-cli \
    gnome-sushi \
  pipx install gnome-extensions-cli --system-site-packages
}

install_extensions() {
  gext innstall
  gext enable
}

install_macos_theme() {
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-gtk-theme.git
  cd MacTahoe-gtk-theme
  sudo ./install.sh -b -HD --shell -i apple -sf --round --silent-mode
  ./install.sh -l
  pkill firefox
  sudo ./tweaks.sh -g -i apple -h smaller -sf -nd -nb --silent-mode
  ./tweaks.sh -f -e
  sudo ./tweaks.sh -F -c Dark --silent-mode
  cd..

  
  git clone --depth=1 https://github.com/kayozxo/GNOME-macOS-Tahoe.git
  cd GNOME-macOS-Tahoe
  sudo ./install.sh -l -d -la --flatpak
  flatpak override --user --filesystem=xdg-config/gtk-3.0
  flatpak override --user --filesystem=xdg-config/gtk-4.0
  cd..
  
  
  git clone --depth=1 https://github.com/vinceliuice/MacTahoe-icon-theme.git
  cd MacTahoe-icon-theme
  ./install.sh -b
  cd cursor
  sudo ./install.sh
  cd..
  cd..
}

main() {
  gum spin --spinner dot --title "Installing dependencies and recommended packages..." -- install_dependencies
  gum spin --spinner dot --title "Creating a temporary directory..." -- create_temp_dir
  gum spin --spinner dot --title "Installing all Gnome Extensions required..." -- install_extensions
  gum spin --spinner dot --title "Installing MacOS Tahoe Themes for Gnome..." -- install_macos_theme
}
