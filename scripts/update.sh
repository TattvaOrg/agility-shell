#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Updater
#  Updates system-wide Agility Shell installation while preserving user configs.
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/AbsolOrg/agility-shell.git"
SYSTEM_DATA="/usr/share/agility-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"

# -- Colours -------------------------------------------------------------------
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
die()     { error "$*"; exit 1; }

prompt_user() {
    local prompt_msg="$1"
    local var_name="$2"
    local default_val="${3:-}"

    if [ -t 0 ]; then
        read -rp "$prompt_msg" "$var_name"
    elif [ -r /dev/tty ]; then
        read -rp "$prompt_msg" "$var_name" < /dev/tty
    else
        eval "$var_name=\"$default_val\""
    fi
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        die "Please run this script as a regular user, not root."
    fi
}

do_update() {
    info "Checking for Agility Shell updates..."
    local tmp_clone
    tmp_clone="$(mktemp -d)"
    trap 'rm -rf "$tmp_clone"' EXIT

    info "Cloning latest sources from $REPO_URL..."
    git clone --depth 1 "$REPO_URL" "$tmp_clone/repo"

    cd "$tmp_clone/repo"

    local is_pacman=false
    if pacman -Q agility-shell-git &>/dev/null || pacman -Q agility-shell &>/dev/null; then
        is_pacman=true
    fi

    if [[ "$is_pacman" == "true" ]]; then
        info "Updating native Arch pacman package via makepkg..."
        makepkg -si --noconfirm
    else
        info "Rebuilding and updating system files via make install..."
        make
        sudo make PREFIX="/usr" install
        sudo make PREFIX="/usr" install-venv
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload || true
    fi

    echo
    success "Agility Shell updated successfully!"
    echo
    prompt_user "  Would you like to restart Agility Shell now? [Y/n]: " restart_choice "y"
    case "$restart_choice" in
        [nN]|[nN][oO])
            info "Restart skipped. Run 'agl restart' when ready."
            ;;
        *)
            if command -v agl &>/dev/null; then
                exec agl restart
            else
                systemctl --user restart agility-shell || true
            fi
            ;;
    esac
}

check_not_root
do_update "$@"
