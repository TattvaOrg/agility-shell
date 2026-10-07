#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Updater
#  Updates system-wide Agility Shell installation while preserving user configs.
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/TattvaOrg/agility-shell.git"
SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_LIB="/usr/lib/agility-shell"
SYSTEM_VENV="$SYSTEM_LIB/venv"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
USER_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agility-shell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

# -- Colours -------------------------------------------------------------------
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
        read -rp "$prompt_msg" input < /dev/tty 2>/dev/tty || true
    else
        input="$default_val"
    fi
    input="${input:-$default_val}"
    printf -v "$var_name" '%s' "$input"
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        die "Please run this script as a regular user, not root."
    fi
}

check_arch() {
    if ! command -v pacman &>/dev/null; then
        die "This updater is designed for Arch Linux."
    fi
}

# -- Dependencies definitions --------------------------------------------------
PACMAN_DEPS=(
    gtk3
    cairo
    libgirepository
    gobject-introspection
    gtk-layer-shell
    libdbusmenu-gtk3
    cinnamon-desktop
    gnome-bluetooth-3.0
    gtk-session-lock
    matugen
    playerctl
    brightnessctl
    wf-recorder
    upower
    swayidle
    networkmanager
    bluez
    python
    python-pip
    python-gobject
    python-cairo
    python-pillow
    python-psutil
    python-cffi
    python-click
    python-loguru
    python-setproctitle
    python-rapidfuzz
    python-pam
    wayland
    pkgconf
    awww
    base-devel
    git
    make
    gcc
    niri
)

AUR_DEPS=(
    fabric-cli-git
)

is_pkg_installed() {
    local pkg="$1"
    if pacman -Qq "$pkg" &>/dev/null; then
        return 0
    fi
    if pacman -T "$pkg" &>/dev/null; then
        return 0
    fi
    if command -v "$pkg" &>/dev/null; then
        return 0
    fi
    return 1
}

is_pkg_outdated() {
    local pkg="$1"
    if pacman -Qu "$pkg" 2>/dev/null | grep -q "^$pkg "; then
        return 0
    fi
    if command -v yay &>/dev/null; then
        if yay -Qu "$pkg" 2>/dev/null | grep -q "^$pkg "; then
            return 0
        fi
    elif command -v paru &>/dev/null; then
        if paru -Qu "$pkg" 2>/dev/null | grep -q "^$pkg "; then
            return 0
        fi
    fi
    return 1
}

audit_and_update_dependencies() {
    info "Synchronizing package databases to audit dependencies..."
    sudo pacman -Sy --noconfirm 2>/dev/null || sudo pacman -Sy || true

    local missing_pacman=()
    local outdated_pacman=()
    local missing_aur=()
    local outdated_aur=()

    for pkg in "${PACMAN_DEPS[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            missing_pacman+=("$pkg")
        elif is_pkg_outdated "$pkg"; then
            outdated_pacman+=("$pkg")
        fi
    done

    for pkg in "${AUR_DEPS[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            missing_aur+=("$pkg")
        elif is_pkg_outdated "$pkg"; then
            outdated_aur+=("$pkg")
        fi
    done

    local pacman_targets=("${missing_pacman[@]}" "${outdated_pacman[@]}")
    if [[ ${#pacman_targets[@]} -gt 0 ]]; then
        info "Updating system pacman dependencies (${pacman_targets[*]})..."
        sudo pacman -S --needed --noconfirm "${pacman_targets[@]}"
        if [[ ${#outdated_pacman[@]} -gt 0 ]]; then
            sudo pacman -S --noconfirm "${outdated_pacman[@]}" || true
        fi
        success "Pacman dependencies up to date."
    fi

    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    local aur_targets=("${missing_aur[@]}" "${outdated_aur[@]}")
    if [[ ${#aur_targets[@]} -gt 0 && -n "$aur_helper" ]]; then
        info "Updating AUR dependencies via $aur_helper (${aur_targets[*]})..."
        "$aur_helper" -S --needed --noconfirm "${aur_targets[@]}"
        if [[ ${#outdated_aur[@]} -gt 0 ]]; then
            "$aur_helper" -S --noconfirm "${outdated_aur[@]}" || true
        fi
        success "AUR dependencies up to date."
    fi
}

seed_user_configuration() {
    info "Ensuring user configuration is up to date..."
    mkdir -p "$USER_CONFIG/config" "$USER_CONFIG/style" "$USER_STATE"

    local src_data="$SYSTEM_DATA"
    if [[ ! -d "$src_data" && -d "$SCRIPT_DIR/.." ]]; then
        src_data="$SCRIPT_DIR/.."
    fi

    if [[ ! -f "$USER_CONFIG/config/config.json" && -f "$src_data/config/config.json" ]]; then
        cp "$src_data/config/config.json" "$USER_CONFIG/config/config.json"
        info "Seeded default config.json"
    fi

    if [[ ! -f "$USER_CONFIG/config/suits.json" && -f "$src_data/config/suits.json" ]]; then
        cp "$src_data/config/suits.json" "$USER_CONFIG/config/suits.json"
        info "Seeded default suits.json"
    fi

    mkdir -p "$USER_CONFIG/custom_style"
    for tpl in border.css font.css color.css README.md; do
        if [[ ! -f "$USER_CONFIG/custom_style/$tpl" && -f "$src_data/custom_style/$tpl" ]]; then
            cp "$src_data/custom_style/$tpl" "$USER_CONFIG/custom_style/$tpl"
        fi
    done

    # Clean legacy style directory
    if [[ -d "$USER_CONFIG/style" ]]; then
        rm -rf "$USER_CONFIG/style"
    fi

    success "User configuration verified."
}

do_update() {
    local target_channel=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --main|-m|main)
                target_channel="main"
                shift
                ;;
            --release|-r|--stable|release|stable)
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

    # Discover latest release tag and current checkout state
    local latest_tag
    latest_tag=$(git tag -l --sort=-v:refname | grep -E '^[0-9]+(\.[0-9]+)+' | head -n 1 || true)
    if [[ -z "$latest_tag" ]]; then
        latest_tag=$(git tag -l --sort=-v:refname | head -n 1 || true)
    fi
    latest_tag="${latest_tag:-1.0.2}"

    local current_desc
    current_desc=$(git describe --tags --always 2>/dev/null || echo "unknown")

    local main_hash
    main_hash=$(git rev-parse --short origin/main 2>/dev/null || echo "head")

    echo ""
    echo -e "  ${BOLD}Current local version:${RESET} ${CYAN}$current_desc${RESET}"
    echo -e "  ${BOLD}Latest release tag:${RESET}   ${GREEN}v$latest_tag${RESET}"
    echo -e "  ${BOLD}Main branch head:${RESET}     ${CYAN}$main_hash${RESET}"
    echo ""

    if [[ -z "$target_channel" ]]; then
        echo -e "${BOLD}Select update channel:${RESET}"
        echo -e "  ${GREEN}[1]${RESET} Latest Release (${GREEN}v$latest_tag${RESET}) - ${DIM}Tested, stable version${RESET}"
        echo -e "  ${CYAN}[2]${RESET} Main branch (${CYAN}latest development${RESET}) - ${DIM}Newest features & bug fixes (Recommended)${RESET}"
        echo ""
        prompt_user "  Enter choice [1/2] (default: 2): " channel_choice "2"
        case "$channel_choice" in
            1|[rR]|[rR][eE][lL]*)
                target_channel="release"
                ;;
            *)
                target_channel="main"
                ;;
        esac
    fi

    # Stash uncommitted changes safely if in a git tree
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        info "Stashing local working tree modifications for safety..."
        git stash push -m "agl-update-autostash-$(date +%s)" 2>/dev/null || true
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
        target_ref="$latest_tag"
        target_name="Release v$latest_tag (stable)"
        info "Switching to $target_name..."
        git checkout -f "$target_ref" 2>/dev/null || git checkout -f "tags/$target_ref"
    fi

    local updated_desc
    updated_desc=$(git describe --tags --always 2>/dev/null || git rev-parse --short HEAD)
    success "Repository switched to: $updated_desc"

    # Audit and update all system & AUR dependencies if older
    audit_and_update_dependencies

    local is_pacman=false
    if pacman -Q agility-shell-git &>/dev/null || pacman -Q agility-shell &>/dev/null; then
        is_pacman=true
    fi

    if [[ "$is_pacman" == "true" ]]; then
        info "Updating native Arch pacman package via makepkg..."
        makepkg -sf --noconfirm
        local pkg_file
        pkg_file="$(ls -t agility-shell-git-*.pkg.tar.* 2>/dev/null | head -n 1 || true)"
        if [[ -n "$pkg_file" && -f "$pkg_file" ]]; then
            sudo pacman -U --needed --noconfirm --overwrite "*" "$pkg_file"
            success "Pacman package updated successfully."
        else
            warn "Built package file not found; falling back to direct system installation..."
            make
            sudo make PREFIX="/usr" install
        fi
        sudo make PREFIX="/usr" install-venv
    else
        info "Compiling native snippet libraries..."
        make
        info "Updating system files via make install..."
        sudo make PREFIX="/usr" install

        local venv_python="/usr/lib/agility-shell/venv/bin/python3"
        local venv_pip="/usr/lib/agility-shell/venv/bin/pip"
        if [[ -x "$venv_pip" ]] && "$venv_python" -c "import sys" &>/dev/null; then
            info "Synchronizing runtime Python dependencies and Fabric..."
            sudo "$venv_pip" install --upgrade pip -q
            sudo "$venv_pip" install --upgrade --no-deps "fabric @ git+https://github.com/Fabric-Development/fabric.git" -q
            sudo "$venv_pip" install --upgrade -r requirements.txt -q
        else
            info "Re-provisioning dedicated virtual environment..."
            sudo rm -rf "/usr/lib/agility-shell/venv"
            sudo make PREFIX="/usr" install-venv
        fi
    fi

    seed_user_configuration

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

    exit 0
}

show_banner "Updater"
check_arch
check_not_root
do_update "$@"
