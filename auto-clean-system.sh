#!/bin/bash

set -u

have() { command -v "$1" >/dev/null 2>&1; }
hr()  { echo; echo "==> $*"; }

# ---------------------------------------------------------------- Packages ---
if have apt; then
    hr "Updating packages"
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove --purge -y

    hr "Purging residual package configs (rc/~c state)"
    sudo apt purge '~c' -y

    hr "Cleaning apt archives cache"
    sudo apt-get clean
fi

# --------------------------------------------------------------- journald ---
if have journalctl; then
    hr "Trimming systemd journal to 100M"
    sudo journalctl --vacuum-size=100M
fi

# ------------------------------------------------------------ Crash dumps ---
hr "Removing crash dumps and coredumps"
sudo rm -f /var/crash/*.crash 2>/dev/null
if [ -d /var/lib/systemd/coredump ]; then
    sudo find /var/lib/systemd/coredump -type f -delete
fi

# ------------------------------------------------------------------- snap ---
if have snap; then
    hr "Removing disabled snap revisions"
    LANG=C snap list --all | awk '/disabled/{print $1, $3}' |
        while read -r name rev; do
            snap remove "$name" --revision="$rev"
        done
fi

# ---------------------------------------------------------------- flatpak ---
if have flatpak; then
    hr "Removing unused Flatpaks"
    sudo flatpak uninstall --unused -y
fi

# ------------------------------------------------------------------ docker ---
if have docker; then
    hr "Docker reclaimable space:"
    sudo docker system df
    hr "Pruning Docker build cache (safe to drop)"
    sudo docker builder prune -f
    # Full prune — removes stopped containers and unused images.
    # Intentionally NOT including --volumes; uncomment if you accept data loss risk.
    hr "Pruning stopped containers and unused images"
    sudo docker system prune -f
fi

# ------------------------------------------------------- Dev tool caches ---
hr "Clearing dev tool caches (run as regular user)"

if have pip;  then pip cache purge 2>/dev/null;                     fi
if have npm;  then npm cache clean --force 2>/dev/null;             fi
if have yarn; then yarn cache clean 2>/dev/null;                    fi
if have go;   then go clean -cache 2>/dev/null;                      fi
# cargo: only plain 'rm' possible without the cargo-cache extension
if [ -d "${CARGO_HOME:-$HOME/.cargo}/registry/cache" ]; then
    rm -rf "${CARGO_HOME:-$HOME/.cargo}/registry/cache"
fi

# ---------------------------------------------------------------- Tempdirs ---
hr "Deleting stale temp files"
find /tmp    -type f -mtime +3 -delete 2>/dev/null
find /var/tmp -type f -mtime +7 -delete 2>/dev/null

# ------------------------------------------------------------------ Trash ---
hr "Emptying user trash"
rm -rf "$HOME/.local/share/Trash/files/"* "$HOME/.local/share/Trash/info/"* 2>/dev/null

# ---------------------------------------------------------------- Survey ----
hr "Largest remaining consumers of disk space (top 15)"
sudo du -xh / --max-depth=2 2>/dev/null | sort -h | tail -15

echo
echo "==> Done."
