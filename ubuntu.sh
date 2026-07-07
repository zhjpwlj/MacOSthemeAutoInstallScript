#!/bin/bash

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

    #================================================#
    #              Check Firefox Status              #
    #================================================#

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

    
}



