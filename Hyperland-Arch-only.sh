#!/bin/bash
set -e

echo "=========================================================="
echo " 🍏 Universal Arch + Hyprland macOS Liquid-Glass Installer "
echo "=========================================================="

# 1. System Upgrade
echo ">> Syncing repositories and upgrading system..."
sudo pacman -Syu --noconfirm

# 2. Base & Tooling Dependencies
echo ">> Installing base system packages..."
sudo pacman -S --needed --noconfirm \
    git base-devel xorg-xwayland cmake meson ninja \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    polkit-gnome qt5-wayland qt6-wayland xdg-desktop-portal-hyprland \
    rofi-wayland kitty brightnessctl playerctl

# 3. Installing AUR Helper (yay) if missing
if ! command -v yay &> /dev/null; then
    echo ">> Building AUR helper (yay)..."
    cd /tmp && git clone https://archlinux.org && cd yay
    makepkg -si --noconfirm && cd ~
fi

# 4. Installing Theming, Dock, & Touch Gestures
echo ">> Fetching macOS UX packages & Crystal Dock..."
# crystal-dock-git provides the macOS style parabolic magnification + glass tray
# swww handles glass-smooth animated transitions for wallpapers
yay -S --needed --noconfirm \
    hyprland crystal-dock-git swww waybar-git \
    grimblast-git dunst libinput xf86-input-libinput

# 5. Dynamic GPU Driver Layer
echo ">> Optimizing graphics layer..."
GPU=$(lspci | grep -E "(VGA|3D)")
if echo "$GPU" | grep -iq "nvidia"; then
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils
    mkdir -p ~/.config/hypr
    {
        echo "env = LIBVA_DRIVER_NAME,nvidia"
        echo "env = XDG_SESSION_TYPE,wayland"
        echo "env = __GLX_VENDOR_LIBRARY_NAME,nvidia"
    } > ~/.config/hypr/nvidia.conf
    echo "source = ~/.config/hypr/nvidia.conf" >> ~/.config/hypr/hyprland.conf
elif echo "$GPU" | grep -iq "amd"; then
    sudo pacman -S --needed --noconfirm xf86-video-amdgpu mesa
elif echo "$GPU" | grep -iq "intel"; then
    sudo pacman -S --needed --noconfirm xf86-video-intel mesa
fi

# 6. Structuring macOS Liquid-Glass Environment Files
echo ">> Generating configurations..."
mkdir -p ~/.config/hypr ~/.config/waybar ~/.config/crystal-dock

# --- HYPRLAND CONFIGURATION ---
cat << 'EOF' > ~/.config/hypr/hyprland.conf
# Monitor Setup
monitor=,preferred,auto,1

# Execute macOS Elements on Boot
exec-once = swww-cache || swww init
exec-once = waybar
exec-once = crystal-dock
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1

# Core Look & Feel (Liquid Glass Theme)
general {
    gaps_in = 6
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(ffffff4d) rgba(ffffff1a) 45deg # Soft white reflection ring
    col.inactive_border = rgba(0000001a)
    layout = dwindle
}

decoration {
    rounding = 14 # Rounded window corners like macOS
    
    # Frosted/Liquid Glass Setup via Hardware Backdrop Blur
    blur {
        enabled = true
        size = 12
        passes = 4        # High passes create rich fluid light dispersion
        new_optimizations = true
        xray = false
        noise = 0.02      # Subdued grain reflection
        contrast = 1.1
        brightness = 1.15
        vibrancy = 0.25   # Bleeds background colors into element borders
    }

    # Soft ambient drop shadows
    drop_shadow = true
    shadow_range = 25
    shadow_render_power = 4
    col.shadow = rgba(00000033)
}

# Window Rules for Blurring Panels and Bars
layerrule = blur, waybar
layerrule = ignorezero, waybar
layerrule = blur, crystal-dock
layerrule = ignorezero, crystal-dock
layerrule = blur, rofi
layerrule = ignorezero, rofi

# Fluid macOS Animations
animations {
    enabled = true
    bezier = appleEase, 0.25, 1, 0.5, 1
    animation = windows, 1, 5, appleEase, slide
    animation = windowsOut, 1, 5, appleEase, slide
    animation = border, 1, 10, default
    animation = fade, 1, 4, default
    animation = workspaces, 1, 5, appleEase, slidefade 20%
}

# Touchscreen and Touchpad Gestures
gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_cancel_ratio = 0.5
}

# Essential Apple-style Keybinds
$mainMod = SUPER
bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive, 
bind = $mainMod, M, exit, 
bind = $mainMod, E, exec, dolphin
bind = $mainMod, Space, exec, rofi -show drun
bind = $mainMod, V, togglefloating, 

# Media and Brightness Touch Binds
bindle = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindle = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindle = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindle = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
EOF

# --- MACOS TOP WAYBAR CONFIGURATION ---
cat << 'EOF' > ~/.config/waybar/config
{
    "layer": "top",
    "position": "top",
    "height": 32,
    "margin-top": 6,
    "margin-left": 12,
    "margin-right": 12,
    "modules-left": ["custom/apple", "hyprland/workspaces"],
    "modules-center": ["clock"],
    "modules-right": ["network", "pulseaudio", "battery"],
    
    "custom/apple": {
        "format": "🍏",
        "tooltip": false
    },
    "clock": {
        "format": "{:%a %b %d  %H:%M}"
    },
    "pulseaudio": {
        "format": "   {volume}%"
    },
    "battery": {
        "format": "   {capacity}%"
    },
    "network": {
        "format-wifi": "  "
    }
}
EOF

# --- WAYBAR LIQUID GLASS STYLE ---
cat << 'EOF' > ~/.config/waybar/style.css
* {
    font-family: "SF Pro Display", "Ubuntu", sans-serif;
    font-size: 14px;
    font-weight: 600;
}
window#waybar {
    background: rgba(255, 255, 255, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 12px;
    color: #ffffff;
}
#workspaces button {
    padding: 0 8px;
    color: rgba(255, 255, 255, 0.4);
}
#workspaces button.active {
    color: #ffffff;
}
#custom-apple {
    padding-left: 12px;
    padding-right: 10px;
    font-size: 16px;
}
#clock, #pulseaudio, #battery, #network {
    padding: 0 12px;
}
EOF

# 7. Apply a beautiful default background for the light bleeding effect
echo ">> Downloading crisp default background asset..."
mkdir -p ~/Pictures/Wallpapers
curl -s -o ~/Pictures/Wallpapers/mac_bg.jpg https://unsplash.com

# Append background init to config
echo "exec-once = sleep 1 && swww img ~/Pictures/Wallpapers/mac_bg.jpg" >> ~/.config/hypr/hyprland.conf

echo "=========================================================="
echo " 🎉 Setup completed successfully!"
echo " Log out to TTY and run: Hyprland"
echo "=========================================================="
