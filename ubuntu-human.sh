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
}

