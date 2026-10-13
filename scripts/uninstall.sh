#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Uninstaller
#  Cleanly terminates running processes and totally removes Agility Shell.
# =============================================================================

set -euo pipefail

SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_LIB="/usr/lib/agility-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
USER_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agility-shell"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
NIRI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/niri/config.kdl"
HYPR_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.conf"
MATUGEN_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/matugen/config.toml"
SUDOERS_FILE="/etc/sudoers.d/agility-battery"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# -- Colors --------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[agility]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[  ok  ]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[ warn ]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[ err  ]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# -- Banner --------------------------------------------------------------------
show_banner() {
    local subtitle="${1:-Uninstaller}"
    if [[ -n "${SCRIPT_DIR:-}" && -f "$SCRIPT_DIR/banner.sh" ]]; then
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/banner.sh"
        show_agility_banner "$subtitle"
    else
        echo ""
        echo -e "                                    ${BLUE}~${RESET}"
        echo -e "                                   ${BLUE}x:${RESET}"
        echo -e "                                  ${BLUE}*#${RESET}"
        echo -e "                                  ${BLUE}##:${RESET}"
        echo -e "                                  ${BLUE}*##~${RESET}"
        echo -e "                            ${BLUE}:${RESET}      ${BLUE}x##x+${RESET}"
        echo -e "                          ${BLUE}:x${RESET}        ${BLUE}+####*.${RESET}"
        echo -e "                          ${BLUE}#x${RESET}          ${BLUE}*####~${RESET}"
        echo -e "                         ${BLUE}:##*.${RESET}         ${BLUE}:####.${RESET}     ${BLUE}*${RESET}"
        echo -e "                          ${BLUE}x###x+.${RESET}       ${BLUE}+###.${RESET}     ${BLUE}x*${RESET}"
        echo -e "                          ${BLUE}.x#####*.${RESET}     ${BLUE}~##+${RESET}     ${BLUE}~#x${RESET}"
        echo -e "                    ${CYAN}=+${RESET}      ${BLUE}:*#####${RESET}     ${BLUE}xx:${RESET}    ${BLUE}.*##*${RESET}"
        echo -e "                    ${CYAN}%%${RESET}         ${BLUE}+###~${RESET}   ${BLUE}::${RESET}    ${BLUE}~*###x${RESET}"
        echo -e "                    ${CYAN}%@%=${RESET}        ${BLUE}.x#.${RESET}       ${BLUE}+####x~${RESET}   ${CYAN}+${RESET}"
        echo -e "                    ${CYAN}+@@@@#+:${RESET}      ${BLUE}+${RESET}      ${BLUE}+####*~${RESET}    ${CYAN}#@${RESET}"
        echo -e "                     ${CYAN}+@@@@@@@#+${RESET}         ${BLUE}*###*.${RESET}  ${CYAN}.=#@@*${RESET}"
        echo -e "                       ${CYAN}+%@@@@@@@*${RESET}      ${BLUE}*##x:${CYAN}:+#@@@@@#${RESET}"
        echo -e "                         ${CYAN}:+#@@@@@#${RESET}    ${BLUE}:##*${CYAN}+%@@@@@@#:${RESET}"
        echo -e "                             ${CYAN}+%@@@=${RESET}   ${BLUE}~+${CYAN}*%@@@@#+:${RESET}"
        echo -e "                               ${CYAN}=@@*${RESET}   ${CYAN}#@@@#+:${RESET}"
        echo -e "                                .%*${RESET}   ${CYAN}#@#:${RESET}"
        echo -e "                                 .+${RESET}   ${CYAN}*:${RESET}"
        echo ""
        echo -e "                     ${CYAN}${BOLD}Agility Shell${RESET} ${BLUE}--${RESET} ${BOLD}${subtitle}${RESET}"
        echo ""
    fi
}

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
            echo "  --purge        Completely remove user configurations, styles, and cached states"
            echo "  -y, --yes      Do not prompt for confirmation"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
    esac
done

show_banner "Uninstaller"
echo -e "  ${YELLOW}${BOLD}This will completely remove Agility Shell from your system.${RESET}"
echo ""

prompt_user() {
    local prompt_msg="$1"
    local var_name="$2"
    local default_val="${3:-}"

    local input=""
    if [ -t 0 ]; then
        read -rp "$prompt_msg" input || true
    elif [ -r /dev/tty ]; then
        read -rp "$prompt_msg" input < /dev/tty || true
    else
        input="$default_val"
    fi
    input="${input:-$default_val}"
    printf -v "$var_name" '%s' "$input"
}

if [[ "$FORCE" == "false" ]]; then
    prompt_user "  Are you sure you want to completely uninstall Agility Shell? [y/N]: " confirm "n"
    case "$confirm" in
        [yY]|[yY][eE][sS]) ;;
        *)
            info "Uninstallation cancelled."
            exit 0
            ;;
    esac
fi

# 1. Stopping running processes and services
info "Stopping running processes and services..."
if command -v systemctl &>/dev/null; then
    systemctl --user stop agility-shell.service 2>/dev/null || true
    systemctl --user disable agility-shell.service 2>/dev/null || true
    systemctl --user reset-failed agility-shell.service 2>/dev/null || true
fi

# Terminate running Agility Shell instances
pkill -TERM -x agilityd 2>/dev/null || true
pkill -TERM -x agl 2>/dev/null || true
pkill -TERM -x agility-shell 2>/dev/null || true
pkill -TERM -f "quickshell.*agility" 2>/dev/null || true
sleep 0.5 2>/dev/null || true
pkill -KILL -x agilityd 2>/dev/null || true
pkill -KILL -x agl 2>/dev/null || true
pkill -KILL -x agility-shell 2>/dev/null || true
pkill -KILL -f "quickshell.*agility" 2>/dev/null || true
success "All running processes and services stopped."

# 2. Removing native pacman package if tracked
if pacman -Qq agility-shell-git &>/dev/null || pacman -Qq agility-shell &>/dev/null; then
    info "Removing native pacman package..."
    sudo pacman -R --noconfirm agility-shell-git 2>/dev/null || sudo pacman -R --noconfirm agility-shell 2>/dev/null || true
    success "Native pacman package removed."
fi

# 3. Removing system-installed binaries and files
info "Removing system-installed files and binaries..."
sudo rm -f /usr/bin/agility-shell /usr/bin/agilityd /usr/bin/agl \
           /usr/local/bin/agility-shell /usr/local/bin/agilityd /usr/local/bin/agl \
           /usr/lib/systemd/user/agility-shell.service \
           /usr/share/applications/agility-shell.desktop \
           /usr/share/applications/minflair-*.desktop \
           /etc/systemd/user/agility-shell.service \
           "$SUDOERS_FILE" 2>/dev/null || true
sudo rm -rf "$SYSTEM_DATA" "$SYSTEM_LIB" 2>/dev/null || true

# User-level binary, service, and desktop links cleanup
rm -f "$HOME/.local/bin/agl" "$HOME/.local/bin/agilityd" "$HOME/.local/bin/agility-shell" \
      "$HOME/.local/share/applications/agility-shell.desktop" \
      "$HOME/.local/share/applications/minflair-"*.desktop \
      "$HOME/.config/systemd/user/agility-shell.service" \
      "$HOME/.config/systemd/user/default.target.wants/agility-shell.service" \
      "$HOME/.config/systemd/user/graphical-session.target.wants/agility-shell.service" 2>/dev/null || true

if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload || true
fi
success "System files, binaries, systemd units, and sudoers rules removed."

# 4. Cleaning compositor configurations
info "Cleaning compositor configurations..."
if [[ -f "$NIRI_CONFIG" ]]; then
    info "Cleaning Niri configuration ($NIRI_CONFIG)..."
    sed -i '/agility-shell/d' "$NIRI_CONFIG" 2>/dev/null || true
    sed -i '/caffyne-shell/d' "$NIRI_CONFIG" 2>/dev/null || true
    sed -i '/spawn-at-startup.*agility/d' "$NIRI_CONFIG" 2>/dev/null || true
    success "Niri config cleaned."
fi

if [[ -f "$HYPR_CONFIG" ]]; then
    info "Cleaning Hyprland configuration ($HYPR_CONFIG)..."
    sed -i '/agility-shell/d' "$HYPR_CONFIG" 2>/dev/null || true
    sed -i '/agilityd/d' "$HYPR_CONFIG" 2>/dev/null || true
    success "Hyprland config cleaned."
fi

# 5. Cleaning Matugen templates
if [[ -f "$MATUGEN_CONFIG" ]]; then
    info "Cleaning Matugen template configurations ($MATUGEN_CONFIG)..."
    sed -i '/# Agility Shell Colors/d' "$MATUGEN_CONFIG" 2>/dev/null || true
    # Remove [templates.agility] block up to next section
    sed -i '/\[templates\.agility\]/,/^[[:space:]]*\[/{/^[[:space:]]*\[templates\.agility\]/d; /^[[:space:]]*\[/!d}' "$MATUGEN_CONFIG" 2>/dev/null || true
    success "Matugen config cleaned."
fi

# 6. Cleaning cache and user configuration
rm -rf "$CACHE_DIR"

if [[ "$PURGE" == "false" && "$FORCE" == "false" ]]; then
    echo ""
    echo -e "  ${BOLD}User Configuration Handling:${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Keep user configurations & custom styles in ~/.config/agility-shell (Default)"
    echo -e "  ${RED}[2]${RESET} Purge everything (delete ~/.config/agility-shell, runtime states & backups)"
    echo ""
    prompt_user "  Enter choice [1/2] (default: 1): " purge_choice "1"
    case "$purge_choice" in
        2|[pP]|[yY]*)
            PURGE=true
            ;;
        *)
            PURGE=false
            ;;
    esac
fi

if [[ "$PURGE" == "true" ]]; then
    info "Purging all user configurations, states, and backups..."
    rm -rf "$USER_CONFIG" "$USER_STATE" 2>/dev/null || true
    rm -rf "$HOME/.config/agility-shell.backup-"* 2>/dev/null || true
    success "All user configurations, styles, states, and backups purged."
else
    info "Preserved user configurations in $USER_CONFIG"
    info "(To delete them, pass --purge or remove manually: rm -rf $USER_CONFIG)"
fi

echo ""
success "Agility Shell has been completely removed from your system."
