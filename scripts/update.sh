#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Updater
#  Updates system-wide Agility Shell installation while preserving user configs.
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/TattvaOrg/agility-shell.git"
SYSTEM_DATA="/usr/share/agility-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# -- Colours -------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}${BOLD}[agility]${RESET} $*"; }
success() { echo -e "${GREEN}${BOLD}[  ok  ]${RESET} $*"; }
warn()    { echo -e "${YELLOW}${BOLD}[ warn ]${RESET} $*"; }
error()   { echo -e "${RED}${BOLD}[ err  ]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# -- Banner --------------------------------------------------------------------
show_banner() {
    local subtitle="${1:-Updater}"
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
        echo -e "                                ${CYAN}.%*${RESET}   ${CYAN}#@#:${RESET}"
        echo -e "                                 ${CYAN}.+${RESET}   ${CYAN}*:${RESET}"
        echo ""
        echo -e "                     ${CYAN}${BOLD}Agility Shell${RESET} ${BLUE}--${RESET} ${BOLD}${subtitle}${RESET}"
        echo ""
    fi
}

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
    eval "$var_name=\"$input\""
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        die "Please run this script as a regular user, not root."
    fi
}

do_update() {
    local target_channel=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --main|-m)
                target_channel="main"
                shift
                ;;
            --release|-r|--stable)
                target_channel="release"
                shift
                ;;
            --help|-h)
                echo -e "${BOLD}Usage:${RESET} update.sh [options]"
                echo -e "  ${CYAN}--release, -r${RESET}  Update to latest stable release tag"
                echo -e "  ${CYAN}--main, -m${RESET}     Update to bleeding-edge main branch"
                echo -e "  ${CYAN}--help, -h${RESET}     Show this help message"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    info "Locating Agility Shell repository..."
    local repo_dir=""
    if [[ -d "$SCRIPT_DIR/../.git" ]]; then
        repo_dir="$(cd "$SCRIPT_DIR/.." && pwd)"
        info "Using in-tree repository at $repo_dir"
    else
        local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
        repo_dir="$cache_dir/repo"
        if [[ -d "$repo_dir/.git" ]]; then
            info "Reusing persistent repository cache at $repo_dir"
        else
            info "Initializing repository cache at $repo_dir..."
            mkdir -p "$cache_dir"
            git clone "$REPO_URL" "$repo_dir"
        fi
    fi

    cd "$repo_dir"
    info "Fetching delta changes and release tags from remote..."
    git remote set-url origin "$REPO_URL" 2>/dev/null || true
    git fetch --prune --tags origin

    # Discover available latest release tag and current checkout state
    local latest_tag
    latest_tag=$(git tag -l --sort=-v:refname | grep -E '^[0-9]+(\.[0-9]+)+' | head -n 1)
    if [[ -z "$latest_tag" ]]; then
        latest_tag=$(git tag -l --sort=-v:refname | head -n 1)
    fi
    latest_tag="${latest_tag:-1.0.1}"

    local current_desc
    current_desc=$(git describe --tags --always 2>/dev/null || echo "unknown")

    echo ""
    echo -e "  ${BOLD}Current local version:${RESET} ${CYAN}$current_desc${RESET}"
    echo -e "  ${BOLD}Latest release tag:${RESET}   ${GREEN}v$latest_tag${RESET}"
    echo ""

    if [[ -z "$target_channel" ]]; then
        echo -e "${BOLD}Select update channel:${RESET}"
        echo -e "  ${GREEN}[1]${RESET} Latest Release (${GREEN}v$latest_tag${RESET}) - ${DIM}Recommended: Tested, stable version${RESET}"
        echo -e "  ${CYAN}[2]${RESET} Main branch (${CYAN}bleeding edge${RESET}) - ${DIM}Latest commits & newest features${RESET}"
        echo ""
        prompt_user "  Enter choice [1/2] (default: 1): " channel_choice "1"
        case "$channel_choice" in
            2|[mM]|[mM][aA][iI][nN])
                target_channel="main"
                ;;
            *)
                target_channel="release"
                ;;
        esac
    fi

    local target_ref=""
    local target_name=""
    if [[ "$target_channel" == "main" ]]; then
        target_ref="origin/main"
        target_name="main (latest development)"
        info "Switching to $target_name..."
        git checkout -f main 2>/dev/null || git checkout -b main origin/main
        git reset --hard origin/main
    else
        target_ref="tags/$latest_tag"
        target_name="Release v$latest_tag (stable)"
        info "Switching to $target_name..."
        git checkout -f "$target_ref"
    fi

    local updated_desc
    updated_desc=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
    success "Repository updated to: $updated_desc"

    local is_pacman=false
    if pacman -Q agility-shell-git &>/dev/null || pacman -Q agility-shell &>/dev/null; then
        is_pacman=true
    fi

    if [[ "$is_pacman" == "true" ]]; then
        info "Updating native Arch pacman package via makepkg..."
        makepkg -sif --noconfirm
    else
        info "Compiling native snippet libraries..."
        make
        info "Updating system files via make install..."
        sudo make PREFIX="/usr" install

        local venv_pip="/usr/lib/agility-shell/venv/bin/pip"
        if [[ -x "$venv_pip" ]]; then
            info "Synchronizing runtime Python dependencies (delta only)..."
            sudo "$venv_pip" install -r requirements.txt -q
        else
            info "Provisioning virtual environment..."
            sudo make PREFIX="/usr" install-venv
        fi
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload || true
    fi

    echo
    success "Agility Shell successfully updated!"
    echo
    prompt_user "  Would you like to restart Agility Shell now? [Y/n]: " restart_choice "y"
    case "$restart_choice" in
        [nN]|[nN][oO])
            info "Restart skipped. Run 'agl restart' whenever you are ready."
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

show_banner "Updater"
check_not_root
do_update "$@"
