#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Uninstaller
#  Cleanly terminates running processes and uninstalls Agility Shell.
# =============================================================================

set -euo pipefail

SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_LIB="/usr/lib/agility-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
USER_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agility-shell"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
NIRI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
HYPR_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"

# -- Colors --------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[agility]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[  ok  ]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[ warn ]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[ err  ]${RESET} $*" >&2; }

PURGE=false
FORCE=false

for arg in "$@"; do
    case "$arg" in
        --purge)
            PURGE=true
            ;;
        -y|--yes)
            FORCE=true
            ;;
        -h|--help)
            echo "Usage: uninstall.sh [options]"
            echo ""
            echo "Options:"
            echo "  --purge        Completely remove user configurations and cached states"
            echo "  -y, --yes      Do not prompt for confirmation"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
    esac
done

echo ""
echo -e "${BOLD}${RED}Agility Shell Uninstaller${RESET}"
echo -e "This will remove Agility Shell from your system."
echo ""

if [[ "$FORCE" == "false" ]]; then
    read -rp "Are you sure you want to uninstall Agility Shell? [y/N]: " confirm
    case "$confirm" in
        [yY]|[yY][eE][sS]) ;;
        *)
            echo "Uninstall cancelled."
            exit 0
            ;;
    esac
fi

info "Stopping running processes and services..."
if command -v systemctl &>/dev/null; then
    systemctl --user stop agility-shell.service 2>/dev/null || true
    systemctl --user disable agility-shell.service 2>/dev/null || true
fi

pids=$(pgrep -x "agility-shell" 2>/dev/null || true)
pids+=" $(pgrep -f "python.*[m]ain\.py" 2>/dev/null || true)"
if [[ -n "${pids// /}" ]]; then
    kill -15 $pids 2>/dev/null || true
    sleep 0.5
    kill -9 $pids 2>/dev/null || true
fi

if pacman -Q agility-shell-git &>/dev/null || pacman -Q agility-shell &>/dev/null; then
    info "Removing native pacman package..."
    sudo pacman -R --noconfirm agility-shell-git 2>/dev/null || sudo pacman -R --noconfirm agility-shell 2>/dev/null || true
fi

info "Removing system-installed files..."
sudo rm -f /usr/bin/agility-shell /usr/bin/agl
sudo rm -f /usr/lib/systemd/user/agility-shell.service
sudo rm -f /usr/share/applications/agility-shell.desktop
sudo rm -rf "$SYSTEM_DATA" "$SYSTEM_LIB"
rm -f "$HOME/.local/bin/agl"

if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload || true
fi

info "Cleaning compositor configurations..."
if [[ -f "$NIRI_CONFIG" ]]; then
    sed -i '/agility-shell/d' "$NIRI_CONFIG" 2>/dev/null || true
fi
if [[ -f "$HYPR_CONFIG" ]]; then
    sed -i '/agility-shell/d' "$HYPR_CONFIG" 2>/dev/null || true
fi

rm -rf "$CACHE_DIR"

if [[ "$PURGE" == "true" ]]; then
    info "Purging user configuration and runtime state..."
    rm -rf "$USER_CONFIG" "$USER_STATE"
    success "All configurations and state purged."
else
    info "Preserved user configurations in $USER_CONFIG"
    info "(To delete them, pass --purge or remove manually: rm -rf $USER_CONFIG)"
fi

echo ""
success "Agility Shell has been successfully uninstalled."
