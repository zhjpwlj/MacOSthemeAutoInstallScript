#!/bin/bash
set -euo pipefail

set_variables(){
	N='\e[0m'           #reset all formattings
	R='\e[1;31m'        #red (bolded)
	O='\e[1;38;5;214m'  #orange (bolded)
	G='\e[1;32m'        #green (bolded)
}

safty_wrappers(){
	# Save the original dir
	ORIGINAL_DIR="$(pwd)"

	# Make a temp dir
	TMP=$(mktemp -d)
	cd "$TMP"

	# Trap to restore dir and cleanup on exit
	trap 'cd "$ORIGINAL_DIR" 2>/dev/null || true; rm -rf "${TMP:-}" 2>/dev/null || true' EXIT

	# Log file
	LOGFILE="$HOME/.MacOSthemeAutoInstallScript.log"
	# Append all stdout/stderr to the logfile while also showing it on the console
	exec > >(tee -a "$LOGFILE") 2>&1
}

check_compatible() {   
    # Ensure the OS release file exists
    if [ ! -f /etc/os-release ]; then
        echo -e "${R}[ ERROR ]${N} Could not determine the operating system." >&2
        exit 1
    fi
    
    # Load OS variables
    . /etc/os-release

    # Check for Ubuntu
    if [ "$ID" != "ubuntu" ]; then    
        echo -e "${R}[ ERROR ]${N} This script is only intended for Ubuntu. Current OS: $NAME" >&2
        exit 1
    fi

    # Check for GNOME
    if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$XDG_CURRENT_DESKTOP" != "ubuntu:GNOME" ]; then
        echo -e "${R}[ ERROR ]${N} This script requires the GNOME desktop environment." >&2
        exit 1
    fi

    # Check for Wayland
    if [ "$XDG_SESSION_TYPE" != "wayland" ]; then
        echo -e "${R}[ ERROR ]${N} This script requires a Wayland session." >&2
        exit 1
    fi
    
    echo "Environment verified: ubuntu with GNOME on Wayland. Proceeding..."

    if command -v curl &> /dev/null; then
		echo -e "curl exisists. Proceeding.."
	else
		echo -e "curl doesn't exsist. installing..."
		sudo apt -qq -y install curl
		echo -e "curl installed. Proceeding..."
	fi
	
	if ! curl --connect-timeout 5 -sI github.com &> /dev/null; then
        echo -e "${R}[ ERROR ]${N} This script requires an active internet connection."
        exit 1
    fi

}


install_required_softs() {

	local REPOS=(
		universe
		ppa:agornostal/ulauncher
	)

	  for repo in "${REPOS[@]}"; do
	  	if ! grep -q "$repo" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        	echo "Adding apt repository $repo..."
	        sudo add-apt-repository "$repo" -y -n || {
				echo "${R}[ ERROR ]${N} Failed to add repository $repo"
				echo "Continuing anyways..."
	    		continue
        	}
		fi
      done

    local REQUIRED_PACKAGES=(
    	curl
        appmenu-gtk3-module
        jq
        unzip
        build-essential
        procps
        file
        pipx
        bamfdaemon
        gir1.2-bamf-3
        libbamf3-2
        libkeybinder-3.0-0
        gir1.2-keybinder-3.0
        unity-gtk-module-common
        python3-pip
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
        ulauncher
        )
    
    sudo apt -q update
    
    for package in "${REQUIRED_PACKAGES[@]}"; do
        echo "Installing software $ext..."
        sudo apt -q -y install "$package" || {
          echo "${R}[ ERROR ]${N} Failed to install package $ext"
		  echo "Continuing anyways..."
          continue
        }
      done
    
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    
    flatpak install -y flathub com.mattjakeman.ExtensionManager || {
		echo "${R}[ ERROR ]${N} Failed to install ExtensionManager"
		echo "${R}[ ERROR ]${N} Continuing anyways..."



    pipx ensurepath
    source ~/.bashrc
    export PATH="$PATH:$HOME/.local/bin"

    sudo pip install future fuzzysearch --break-system-packages
    
    if ! command -v gext &> /dev/null; then
        echo "gext not found. Installing..."
        pipx install gnome-extensions-cli --system-site-packages || {
            echo "${R}[ ERROR ]${N} gext installation failed!" >&2
            exit 1
        }
        sleep 2  # wait for install to settle
    
        if command -v gext &> /dev/null; then
            echo "gext installed successfully."
        else
            echo "${R}[ ERROR ]${N} gext installation failed!" >&2
            echo "Restarting the terminal might help" >&2
            exit 1
        fi
    fi

}

configure_firefox() {

    #================================================#
    #              Check Firefox Status              #
    #================================================#
	
    pkill firefox || true
    
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
        echo "${R}[ ERROR ]${N} Firefox profile has not been created yet. Launch Firefox once first."
        exit 1
    fi

    echo "Configuring required Firefox flags..."

    # Define the flags to enable
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
                echo "${R}[ ERROR ]${N} Failed to update Firefox flag $flag" >&2
                exit 1
            }
        else
            # Append new flag
            echo "user_pref(\"$flag\", $value);" >> "$USER_PROFILE/prefs.js" || {
                echo "${R}[ ERROR ]${N} Failed to append Firefox flag $flag" >&2
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
        10288
      )
        #Fuzzy search, User themes, Compiz alike magic lamp effect, Blur my shell, Just perfection, Notification banner position, Clipboard indicator, Space bar, gnome 4x 5x improvement, Ubuntu tilting assistant, App menu is back, Fildem global menu, Coverflow alt+tab, Rounded corners, Dash2dock animated, Gesture improvements, Kiwi is not apple, Global Menu for Gnome
  
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
      
      gext disable ubuntu-dock@ubuntu.com 
}

install_theme(){
    # Save current directory and use subshell to prevent directory pollution
    local theme_work_dir
    theme_work_dir="$TMP/theme_install_$$"
    mkdir -p "$theme_work_dir"
    
    (
        cd "$theme_work_dir" || exit 1
        
        git clone https://github.com/vinceliuice/MacTahoe-gtk-theme.git --depth=1 || {
            echo "${R}[ ERROR ]${N} Failed to clone MacTahoe-gtk-theme" >&2
            exit 1
        }
		
        sudo .$theme_work_dir/MacTahoe-gtk-theme/install.sh -o normal -b --shell -i apple -h smaller -sf --round --silent-mode || {
            echo "${R}[ ERROR ]${N} Failed to install MacTahoe-gtk-theme" >&2
            exit 1
        }
        .$theme_work_dir/MacTahoe-gtk-theme/install.sh -l -o normal -b --shell -i apple -h smaller -sf --round || {
            echo "${R}[ ERROR ]${N} Failed to configure MacTahoe-gtk-theme for libadwaita" >&2
            exit 1
        }
        sudo .$theme_work_dir/MacTahoe-gtk-theme/tweaks.sh -g -sf -nd -nb || {
            echo "${R}[ ERROR ]${N} Failed to apply tweaks (step 1)" >&2
            exit 1
        }
        .$theme_work_dir/MacTahoe-gtk-theme/tweaks.sh -f || {
            echo "${R}[ ERROR ]${N} Failed to apply tweaks (step 2)" >&2
            exit 1
        }
        .$theme_work_dir/MacTahoe-gtk-theme/tweaks.sh -f adaptive || {
            echo "${R}[ ERROR ]${N} Failed to apply tweaks (step 3)" >&2
            exit 1
        }
        sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0 || {
            echo "${R}[ ERROR ]${N} failed to override Flatpak theme"
            exit 1
        }
        .$theme_work_dir/MacTahoe-gtk-theme/tweaks.sh -F -c Dark || {
            echo "${R}[ ERROR ]${N} Failed to apply tweaks (step 4)" >&2
            exit 1
        }

        git clone https://github.com/vinceliuice/MacTahoe-icon-theme.git --depth=1 || {
            echo "${R}[ ERROR ]${N} Failed to clone MacTahoe-icon-theme" >&2
            exit 1
        }
		
        .$theme_work_dir/MacTahoe-icon-theme/install.sh -b || {
            echo "${R}[ ERROR ]${N} Failed to install MacTahoe-icon-theme" >&2
            exit 1
        }

        sudo .$theme_work_dir/MacTahoe-icon-theme/cursors/install.sh || {
            echo "${R}[ ERROR ]${N} Failed to install cursors" >&2
            exit 1
        }

        git clone https://github.com/kayozxo/GNOME-macOS-Tahoe.git --depth=1 || {
            echo "${R}[ ERROR ]${N} Failed to clone GNOME-macOS-Tahoe"
            exit 1
        }

        .$theme_work_dir/GNOME-macOS-Tahoe/install.sh -w || exit 1
        
        .$theme_work_dir/GNOME-macOS-Tahoe/install.sh -d -l || exit 1
        .$theme_work_dir/GNOME-macOS-Tahoe/install.sh -d -l -la || exit 1
        sudo flatpak override --filesystem=xdg-config/gtk-3.0 && sudo flatpak override --filesystem=xdg-config/gtk-4.0 || exit 1
        .$theme_work_dir/GNOME-macOS-Tahoe/install.sh --flatpak || exit 1

}


apply_settings(){
	#apply setting for gnome tweak managed settings
	gsettings set org.gnome.desktop.interface gtk-theme "MacTahoe-Dark"
	gsettings set org.gnome.desktop.interface icon-theme "MacTahoe-dark"
	gsettings set org.gnome.desktop.interface cursor-theme "MacTahoe-cursors"
	gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
	gsettings set org.gnome.desktop.wm.preferences button-layout 'close,maximize,minimize:'

	
	#apply user themes
	gsettings set org.gnome.shell.extensions.user-theme name "MacTahoe-Dark"
	
	
}

main() {
	set_variables
	safty_wrappers
    check_compatible
    install_required_softs
    configure_firefox
    install_gnome_extensions
    install_theme
    apply_settings
}

main
