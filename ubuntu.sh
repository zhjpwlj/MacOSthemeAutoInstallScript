#!/bin/bash

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

