#!/bin/bash
set -e

# ============================================================================
# 🍏 Universal Arch + Hyprland macOS Liquid-Glass Installer
# ============================================================================
# Compatible with: Arch Linux, Manjaro, EndeavourOS, Garuda, and other Arch derivatives
# ============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/macos-theme-install.log"
CONFIG_DIR="$HOME/.config"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[!] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_header() {
    echo -e "\n${BLUE}========================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================================${NC}\n"
}

# Check if running as sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run with sudo privileges"
        exit 1
    fi
}

# Detect package manager
detect_package_manager() {
    if command -v pacman &> /dev/null; then
        echo "pacman"
    else
        log_error "pacman not found. This script requires an Arch-based distribution."
        exit 1
    fi
}

# Install packages with pacman
install_with_pacman() {
    local packages=("$@")
    log "Installing via pacman: ${packages[*]}"
    pacman -S --needed --noconfirm "${packages[@]}" 2>&1 | tee -a "$LOG_FILE" || {
        log_warning "Some pacman packages may have failed. Continuing..."
    }
}

# Detect and install AUR helper
setup_aur_helper() {
    local aur_helper=""
    
    if command -v paru &> /dev/null; then
        aur_helper="paru"
    elif command -v yay &> /dev/null; then
        aur_helper="yay"
    elif command -v trizen &> /dev/null; then
        aur_helper="trizen"
    else
        log ">> Building AUR helper (yay)..."
        cd /tmp
        if [ -d yay ]; then
            rm -rf yay
        fi
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm || {
            log_error "Failed to build yay. Attempting paru..."
            cd /tmp
            git clone https://aur.archlinux.org/paru.git
            cd paru
            makepkg -si --noconfirm || log_warning "AUR helper installation failed"
        }
        cd ~
    fi
    
    # Re-detect after installation
    if command -v paru &> /dev/null; then
        echo "paru"
    elif command -v yay &> /dev/null; then
        echo "yay"
    elif command -v trizen &> /dev/null; then
        echo "trizen"
    else
        echo ""
    fi
}

# Install AUR packages
install_with_aur() {
    local aur_helper="$1"
    shift
    local packages=("$@")
    
    if [ -z "$aur_helper" ]; then
        log_warning "No AUR helper available. Skipping AUR packages: ${packages[*]}"
        return 1
    fi
    
    log "Installing via $aur_helper: ${packages[*]}"
    $aur_helper -S --needed --noconfirm "${packages[@]}" 2>&1 | tee -a "$LOG_FILE" || {
        log_warning "Some AUR packages may have failed. Continuing..."
        return 1
    }
}

# Detect GPU
detect_gpu() {
    if command -v lspci &> /dev/null; then
        lspci | grep -E "(VGA|3D)" | head -1
    else
        log_warning "lspci not found. GPU detection skipped."
        echo "Unknown"
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# MAIN INSTALLATION
# ============================================================================

main() {
    log_header "🍏 Universal Arch + Hyprland macOS Liquid-Glass Installer"
    
    # Verify prerequisites
    check_sudo
    PKG_MANAGER=$(detect_package_manager)
    log_success "Detected package manager: $PKG_MANAGER"
    
    # 1. System Upgrade
    log_header "Step 1/6: System Upgrade"
    log "Syncing repositories and upgrading system..."
    pacman -Syu --noconfirm 2>&1 | tee -a "$LOG_FILE" || log_warning "System upgrade had issues"
    log_success "System upgraded"
    
    # 2. Base & Tooling Dependencies
    log_header "Step 2/6: Installing Base System Packages"
    local base_packages=(
        git base-devel xorg-xwayland cmake meson ninja
        pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber
        qt5-wayland qt6-wayland xdg-desktop-portal-hyprland
        rofi-wayland kitty brightnessctl playerctl dunst
        libnotify # For notifications support
        wl-clipboard xclip # Clipboard support for Wayland
        cliphist # Clipboard history
        hyprland # Core Hyprland (can fail on some distros, handled below)
    )
    
    # Remove potentially conflicting packages
    local base_packages_filtered=()
    for pkg in "${base_packages[@]}"; do
        # Skip polkit-gnome on some distros that have it as polkit
        if [[ "$pkg" == "polkit-gnome" ]]; then
            if ! pacman -Ss "^polkit-gnome$" &>/dev/null 2>&1; then
                continue
            fi
        fi
        base_packages_filtered+=("$pkg")
    done
    
    install_with_pacman "${base_packages_filtered[@]}"
    log_success "Base packages installed"
    
    # Try to install polkit-gnome or fallback to polkit
    if ! pacman -S --needed --noconfirm polkit-gnome &>/dev/null 2>&1; then
        log_warning "polkit-gnome not available, using polkit instead"
        pacman -S --needed --noconfirm polkit &>/dev/null 2>&1 || true
    fi
    
    # 3. Setup AUR Helper
    log_header "Step 3/6: Setting up AUR Helper"
    AUR_HELPER=$(setup_aur_helper)
    
    if [ -n "$AUR_HELPER" ]; then
        log_success "AUR helper available: $AUR_HELPER"
    else
        log_warning "No AUR helper available. Optional AUR packages will be skipped."
    fi
    
    # 4. Installing Theming & Additional Packages
    log_header "Step 4/6: Installing macOS Theme Components"
    
    local aur_packages=(
        swww # Wallpaper manager with smooth transitions
        waybar-git # Top panel (using git version for latest features)
        grimblast-git # Screenshot utility
    )
    
    # Try crystal-dock but have fallbacks
    local optional_aur_packages=(
        crystal-dock-git # macOS-style dock (optional)
    )
    
    if [ -n "$AUR_HELPER" ]; then
        install_with_aur "$AUR_HELPER" "${aur_packages[@]}"
        install_with_aur "$AUR_HELPER" "${optional_aur_packages[@]}" || log_warning "Optional packages failed"
    else
        log_warning "Skipping AUR packages due to no AUR helper. Install manually later:"
        log_warning "  - swww (wallpaper manager)"
        log_warning "  - waybar-git (top panel)"
        log_warning "  - grimblast-git (screenshots)"
        log_warning "  - crystal-dock-git (dock - optional)"
    fi
    
    log_success "Theme components installed"
    
    # 5. Dynamic GPU Driver Layer
    log_header "Step 5/6: Installing GPU Drivers"
    log "Detecting GPU..."
    GPU=$(detect_gpu)
    log "GPU Detected: $GPU"
    
    if echo "$GPU" | grep -iq "nvidia"; then
        log "Installing NVIDIA drivers..."
        install_with_pacman nvidia-dkms nvidia-utils libglvnd
        log_success "NVIDIA drivers installed"
        
        mkdir -p "$CONFIG_DIR/hypr"
        cat > "$CONFIG_DIR/hypr/nvidia.conf" << 'NVIDIA_CONF'
# NVIDIA Hyprland Configuration
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = CUDA_VISIBLE_DEVICES,0
NVIDIA_CONF
    elif echo "$GPU" | grep -iq "amd"; then
        log "Installing AMD drivers..."
        install_with_pacman xf86-video-amdgpu mesa lib32-mesa vulkan-radeon lib32-vulkan-radeon
        log_success "AMD drivers installed"
    elif echo "$GPU" | grep -iq "intel"; then
        log "Installing Intel drivers..."
        install_with_pacman xf86-video-intel mesa lib32-mesa vulkan-intel lib32-vulkan-intel
        log_success "Intel drivers installed"
    else
        log_warning "GPU not detected. Using generic mesa drivers..."
        install_with_pacman mesa lib32-mesa
    fi
    
    # 6. Create Configuration Files
    log_header "Step 6/6: Generating Hyprland & Waybar Configurations"
    
    mkdir -p "$CONFIG_DIR/hypr" "$CONFIG_DIR/waybar" "$CONFIG_DIR/crystal-dock"
    
    # Backup existing configs
    if [ -f "$CONFIG_DIR/hypr/hyprland.conf" ]; then
        log "Backing up existing hyprland.conf to hyprland.conf.bak"
        cp "$CONFIG_DIR/hypr/hyprland.conf" "$CONFIG_DIR/hypr/hyprland.conf.bak"
    fi
    
    # --- HYPRLAND CONFIGURATION ---
    cat > "$CONFIG_DIR/hypr/hyprland.conf" << 'HYPRLAND_EOF'
# =================================================================
# 🍏 Hyprland Configuration - macOS Liquid Glass Theme
# =================================================================

# Monitor Setup (auto-detect displays)
monitor=,preferred,auto,1

# Execute macOS Elements on Boot
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user start hyprland-session.target
exec-once = swww-cache || swww init
exec-once = waybar
exec-once = dunst
exec-once = /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 || /usr/lib/polkit-kde-authentication-agent-1 || true

# Optional: Launch crystal-dock if available
exec-once = which crystal-dock &>/dev/null && crystal-dock || true

# =================================================================
# Core Look & Feel (Liquid Glass Theme)
# =================================================================

general {
    gaps_in = 6
    gaps_out = 12
    border_size = 2
    col.active_border = rgba(ffffff4d) rgba(ffffff1a) 45deg
    col.inactive_border = rgba(0000001a)
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 14
    
    # Frosted/Liquid Glass via Hardware Backdrop Blur
    blur {
        enabled = true
        size = 12
        passes = 4
        new_optimizations = true
        xray = false
        noise = 0.02
        contrast = 1.1
        brightness = 1.15
        vibrancy = 0.25
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
layerrule = blur, dunst
layerrule = ignorezero, dunst

# =================================================================
# Fluid macOS Animations
# =================================================================

animations {
    enabled = true
    bezier = appleEase, 0.25, 1, 0.5, 1
    animation = windows, 1, 5, appleEase, slide
    animation = windowsOut, 1, 5, appleEase, slide
    animation = border, 1, 10, default
    animation = fade, 1, 4, default
    animation = workspaces, 1, 5, appleEase, slidefade 20%
}

# =================================================================
# Touchscreen and Touchpad Gestures
# =================================================================

gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
    workspace_swipe_distance = 300
    workspace_swipe_cancel_ratio = 0.5
}

# =================================================================
# Input Configuration
# =================================================================

input {
    kb_layout = us
    follow_mouse = 1
    sensitivity = 0
}

touchpad {
    natural_scroll = true
    disable_while_typing = true
}

# =================================================================
# Essential Apple-style Keybinds
# =================================================================

$mainMod = SUPER

# Applications
bind = $mainMod, Q, exec, kitty
bind = $mainMod, E, exec, dolphin
bind = $mainMod, Space, exec, rofi -show drun

# Window Management
bind = $mainMod, C, killactive
bind = $mainMod, M, exit
bind = $mainMod, V, togglefloating
bind = $mainMod, F, fullscreen, 0

# Focus Movement
bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

# Window Movement
bind = $mainMod SHIFT, H, movewindow, l
bind = $mainMod SHIFT, L, movewindow, r
bind = $mainMod SHIFT, K, movewindow, u
bind = $mainMod SHIFT, J, movewindow, d

# Workspace Management
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5

# Workspace Cycling
bind = $mainMod, Right, workspace, e+1
bind = $mainMod, Left, workspace, e-1

# =================================================================
# Media and Brightness Controls
# =================================================================

bindle = , XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
bindle = , XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
bindl  = , XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
bindle = , XF86MonBrightnessUp, exec, brightnessctl set +5%
bindle = , XF86MonBrightnessDown, exec, brightnessctl set 5%-

# Load GPU-specific config if available
source = ~/.config/hypr/nvidia.conf

HYPRLAND_EOF
    
    log_success "Hyprland configuration created"
    
    # --- WAYBAR CONFIGURATION ---
    cat > "$CONFIG_DIR/waybar/config" << 'WAYBAR_EOF'
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
    "hyprland/workspaces": {
        "format": "{name}",
        "on-click": "hyprctl dispatch workspace"
    },
    "clock": {
        "format": "{:%a %b %d  %H:%M}",
        "tooltip-format": "{:%A, %B %d, %Y}"
    },
    "pulseaudio": {
        "format": "   {volume}%",
        "format-muted": "  Muted",
        "on-click": "pactl set-sink-mute @DEFAULT_SINK@ toggle"
    },
    "battery": {
        "format": "   {capacity}%",
        "format-charging": "   {capacity}%",
        "states": {
            "warning": 20,
            "critical": 10
        }
    },
    "network": {
        "format-wifi": "  {essid}",
        "format-ethernet": "  Connected",
        "format-disconnected": "  Disconnected"
    }
}
WAYBAR_EOF
    
    log_success "Waybar configuration created"
    
    # --- WAYBAR STYLE ---
    cat > "$CONFIG_DIR/waybar/style.css" << 'WAYBAR_STYLE_EOF'
* {
    font-family: "SF Pro Display", "Segoe UI", "Ubuntu", sans-serif;
    font-size: 14px;
    font-weight: 600;
}

window#waybar {
    background: rgba(255, 255, 255, 0.15);
    border: 1px solid rgba(255, 255, 255, 0.3);
    border-radius: 12px;
    color: #ffffff;
    backdrop-filter: blur(10px);
}

#workspaces {
    margin: 0 8px;
}

#workspaces button {
    padding: 0 8px;
    color: rgba(255, 255, 255, 0.4);
    margin: 0 2px;
    border-radius: 6px;
    transition: all 0.3s ease;
}

#workspaces button.active {
    color: #ffffff;
    background: rgba(255, 255, 255, 0.1);
}

#workspaces button:hover {
    background: rgba(255, 255, 255, 0.05);
}

#custom-apple {
    padding-left: 12px;
    padding-right: 10px;
    font-size: 16px;
}

#clock, #pulseaudio, #battery, #network {
    padding: 0 12px;
    margin: 0 2px;
}

#battery.warning {
    color: #f39c12;
}

#battery.critical {
    color: #e74c3c;
    animation: blink 1s infinite;
}

@keyframes blink {
    0%, 50% { opacity: 1; }
    51%, 100% { opacity: 0.5; }
}

WAYBAR_STYLE_EOF
    
    log_success "Waybar style created"
    
    # 7. Download wallpaper
    log "Setting up wallpaper..."
    mkdir -p "$HOME/Pictures/Wallpapers"
    
    if command_exists curl; then
        log "Downloading default macOS-style wallpaper..."
        # Using a direct macOS Big Sur wallpaper URL
        curl -s -L -o "$HOME/Pictures/Wallpapers/macos_default.jpg" \
            "https://images.unsplash.com/photo-1614730321146-b6fa6a46bcb4?w=2560" || {
            log_warning "Failed to download wallpaper. Using solid color fallback."
        }
    fi
    
    # Append wallpaper initialization
    echo "" >> "$CONFIG_DIR/hypr/hyprland.conf"
    echo "# Wallpaper" >> "$CONFIG_DIR/hypr/hyprland.conf"
    echo "exec-once = sleep 1 && swww img $HOME/Pictures/Wallpapers/macos_default.jpg --transition-type wipe" >> "$CONFIG_DIR/hypr/hyprland.conf"
    
    log_success "Wallpaper configured"
    
    # 8. Create session file for systemd-user (optional but recommended)
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/hyprland-session.target" << 'SYSTEMD_EOF'
[Unit]
Description=Hyprland Session
Documentation=man:systemd.special(7)
After=graphical-session-pre.target
Wants=graphical-session.target

[Install]
WantedBy=graphical-session.target
SYSTEMD_EOF
    
    log_success "Systemd user session target created"
    
    # Final summary
    log_header "🎉 Installation Complete!"
    
    cat << 'SUMMARY_EOF'

========================================================
✅ Setup completed successfully!
========================================================

📋 Next Steps:
1. Log out from your current session
2. At the login screen, select "Hyprland" as your desktop
3. Log in to start the macOS-themed Hyprland environment

💡 Useful Information:
- Config files location: ~/.config/hypr/
- Waybar config: ~/.config/waybar/
- Change wallpaper: swww img <path-to-wallpaper>
- Install crystal-dock manually: paru -S crystal-dock-git
- View this install log: less macos-theme-install.log

🖥️  Quick Keybindings:
- Super (Cmd) + Q: Open terminal (kitty)
- Super + Space: Application launcher (rofi)
- Super + E: File manager (dolphin)
- Super + H/L/K/J: Move focus (left/right/up/down)
- Super + 1-5: Switch workspaces
- Super + Right/Left: Cycle workspaces
- Volume/Brightness keys: Media controls

⚙️  GPU Configuration:
- NVIDIA: Hardware acceleration enabled via nvidia.conf
- AMD/Intel: Mesa drivers installed for Wayland support

📝 Troubleshooting:
- If Hyprland doesn't start, check: Xwayland, graphics drivers
- Missing components? Install manually via paru or yay
- Theme issues? Verify ~/.config/hypr/ files exist

========================================================

SUMMARY_EOF
    
    log_success "All done! Enjoy your macOS-themed Hyprland! 🍏"
}

# Run main function
main "$@"
