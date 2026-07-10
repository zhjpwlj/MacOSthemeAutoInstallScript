#!/bin/bash
set -euo pipefail

# ============================================================#
#                   SAFETY WRAPPERS                           #
# ============================================================#

# Save the original working directory
ORIGINAL_DIR="$(pwd)"

# Trap to restore working directory and cleanup on exit
trap 'cd "$ORIGINAL_DIR" 2>/dev/null || true; rm -rf "${TMP:-}" 2>/dev/null || true' EXIT

# Wrapper for checking if previous function succeeded
check_previous_command() {
    if [ $? -ne 0 ]; then
        echo "ERROR: Previous command failed!" >&2
        exit 1
    fi
}

# ============================================================#
#                            TODO                             #
# ============================================================#

check_compatible() {
    #================================================#
    #           Check system compatibility           #
    #================================================#
    
    # Ensure the OS release file exists
    if [ ! -f /etc/os-release ]; then
        echo "Error: Cannot determine the operating system." >&2
        exit 1
    fi
    
    # Load OS variables
    . /etc/os-release

    # Strict check for Ubuntu
    if [ "$ID" != "ubuntu" ]; then    
        echo "Warning: This script is only intended for Ubuntu. Current OS: $NAME" >&2
        exit 1
    fi

    echo "Ubuntu detected. Proceeding with the script..."

    # Check for GNOME Desktop
    if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$XDG_CURRENT_DESKTOP" != "ubuntu:GNOME" ]; then
        echo "Warning: This script requires the GNOME desktop environment." >&2
        exit 1
    fi

    # Check for Wayland Display Server
    if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        echo "Warning: This script requires a Wayland session." >&2
        exit 1
    fi
    
    echo "Environment verified: GNOME on Wayland. Proceeding..."

    if ! curl --connect-timeout 3 -sI github.com &> /dev/null; then
        echo "This script requires an active internet connection."
        exit 1
    fi

    #make a temp dir
    TMP=$(mktemp -d)
    trap 'cd "$ORIGINAL_DIR" 2>/dev/null || true; rm -rf "$TMP" 2>/dev/null || true' EXIT
    cd "$TMP"

}


install_required_softs() {
    local REQUIRED_PACKAGES=(curl
        jq
        unzip
        build-essential
        procps
        file
        pipx
        python3-venv
        gnome-shell
        gnome-tweaks
        timeshift
        flatpak
        git
        sassc
        libglib2.0-dev-bin
        libxml2-utils
        imagemagick
        dialog
        optipng
        inkscape
        dconf-cli
        gnome-sushi
        )
    
    sudo apt -qq update
    
    for i in "${REQUIRED_PACKAGES[@]}"
    do
        echo "====> Installing $i..."
        sudo apt -qq install -y "$i" || {
            echo "ERROR: Failed to install $i" >&2
            exit 1
        }
        echo "====> $i is installed."
    done

    pipx ensurepath
    source ~/.bashrc
    export PATH="$PATH:$HOME/.local/bin"
    

    if ! command -v gext &> /dev/null; then
        echo "gext not found. Installing..."
        pipx install gnome-extensions-cli --system-site-packages || {
            echo "ERROR: gext installation failed!" >&2
            exit 1
        }
        sleep 2  # wait for install to settle
    
        if command -v gext &> /dev/null; then
            echo "gext installed successfully."
        else
            echo "ERROR: gext installation failed!" >&2
            exit 1
        fi
    fi
}

configure_firefox() {

    #================================================#
    #              Check Firefox Status              #
    #================================================#

    if command -v firefox &> /dev/null; then
        echo "Firefox is found. preceeding..."
    else
        echo "Firefox is not installed."
        exit 1
    fi

    PROFILE_DIR="$HOME/snap/firefox/common/.mozilla/firefox"

    # Fallback for classic APT installation if Snap directory doesn't exist
    if [ ! -d "$PROFILE_DIR" ]; then
        PROFILE_DIR="$HOME/.mozilla/firefox"
    fi

    # 2. Locate the primary user profile folder dynamically
    # (Looks for folders ending in .default-release or .default)
    USER_PROFILE=$(find "$PROFILE_DIR" -maxdepth 1 -type d \( -name "*.default-release" -o -name "*.default" \) | head -n 1)    

    # 3. Verify the profile and check the onboarding status
    if [ -z "$USER_PROFILE" ] || [ ! -f "$USER_PROFILE/prefs.js" ]; then
        echo "Firefox profile has not been created yet. Launch Firefox once first."
        exit 1
    fi

    # Search for the disabled flag inside prefs.js
    if grep -q 'user_pref("browser.aboutwelcome.enabled", false);' "$USER_PROFILE/prefs.js"; then
        echo "SUCCESS: Initialized Firefox Detected."
    else
        echo "Firefox onboarding process is not finished yet. Please initialize firefox first."
        exit 1
    fi

    echo "Configuring required Firefox flags..."

    # Define the flags you want to enable
    declare -A FIREFOX_FLAGS=(
        ["layers.acceleration.force-enabled"]="true"
        ["toolkit.legacyUserProfileCustomizations.stylesheets"]="true"
        ["browser.tabs.allowTabCloseOnMiddleClick"]="false"
    )

    for flag in "${!FIREFOX_FLAGS[@]}"; do
        value="${FIREFOX_FLAGS[$flag]}"

        # Check if flag already exists
        if grep -q "^user_pref(\"$flag\"" "$USER_PROFILE/prefs.js"; then
            # Update existing flag
            sed -i "s/^user_pref(\"$flag\", .*);/user_pref(\"$flag\", $value);/" "$USER_PROFILE/prefs.js" || {
                echo "ERROR: Failed to update Firefox flag $flag" >&2
                exit 1
            }
        else
            # Append new flag
            echo "user_pref(\"$flag\", $value);" >> "$USER_PROFILE/prefs.js" || {
                echo "ERROR: Failed to append Firefox flag $flag" >&2
                exit 1
            }
        fi
    done
    
}

install_gnome_extensions(){
    extensions=(
        1488
        19
        3740
        3193
        3843
        4105
        779
        5090
        4158
        3733
        6433
        4114
        97
        2524
        4994
        4245
        8267
      )
        #Fuzzy search, User themes, Compiz alike magic lamp effect, Blur my shell, Just perfection, Notification banner position, Clipboard indicator, Space bar, gnome 4x 5x improvement, Ubuntu tiltin[...]
  
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

install_theme(){
    # Save current directory and use subshell to prevent directory pollution
    local theme_work_dir
    theme_work_dir="$TMP/theme_install_$$"
    mkdir -p "$theme_work_dir"
    
    (
        cd "$theme_work_dir" || exit 1
        
        git clone https://github.com/vinceliuice/MacTahoe-gtk-theme.git --depth=1 || {
            echo "ERROR: Failed to clone MacTahoe-gtk-theme" >&2
            exit 1
        }
        cd MacTahoe-gtk-theme || exit 1
        sudo ./install.sh -o normal -b --shell -i apple -h smaller -sf --round --silent-mode || {
            echo "ERROR: Failed to install MacTahoe-gtk-theme" >&2
            exit 1
        }
        ./install.sh -l -o normal -b --shell -i apple -h smaller -sf --round || {
            echo "ERROR: Failed to configure MacTahoe-gtk-theme for user" >&2
            exit 1
        }
        ./tweaks.sh -g -sf -nd -nb || {
            echo "ERROR: Failed to apply tweaks (step 1)" >&2
            exit 1
        }
        ./tweaks.sh -f || {
            echo "ERROR: Failed to apply tweaks (step 2)" >&2
            exit 1
        }
        ./tweaks.sh -f adaptive || {
            echo "ERROR: Failed to apply tweaks (step 3)" >&2
            exit 1
        }
        ./tweaks.sh -F -c Dark || {
            echo "ERROR: Failed to apply tweaks (step 4)" >&2
            exit 1
        }
        cd ..

        git clone https://github.com/vinceliuice/MacTahoe-icon-theme.git --depth=1 || {
            echo "ERROR: Failed to clone MacTahoe-icon-theme" >&2
            exit 1
        }
        cd MacTahoe-icon-theme || exit 1
        ./install.sh -b || {
            echo "ERROR: Failed to install MacTahoe-icon-theme" >&2
            exit 1
        }

        cd cursors || exit 1
        sudo ./install.sh || {
            echo "ERROR: Failed to install cursors" >&2
            exit 1
        }

        cd "$ORIGINAL_DIR" || true
    ) || exit 1
}

main() {
    check_compatible
    install_required_softs
    configure_firefox
    install_gnome_extensions
    install_theme
}

main
