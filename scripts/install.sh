#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Installer
#  Arch Linux - Distributed System-Wide Installation
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/TattvaOrg/agility-shell.git"
SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_LIB="/usr/lib/agility-shell"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
USER_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/agility-shell"

SCRIPT_SRC="${BASH_SOURCE[0]:-}"
if [[ -n "$SCRIPT_SRC" && "$SCRIPT_SRC" != "bash" && "$SCRIPT_SRC" != "sh" && "$SCRIPT_SRC" != "/dev/stdin" && -f "$SCRIPT_SRC" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SRC")" 2>/dev/null && pwd || echo "")"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "")"
else
    SCRIPT_DIR=""
    REPO_ROOT=""
fi

IS_LOCAL_REPO=false
LOCAL_SRC_DIR=""
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/Cargo.toml" && -f "$REPO_ROOT/Makefile" && -d "$REPO_ROOT/quickshell" ]]; then
    IS_LOCAL_REPO=true
    LOCAL_SRC_DIR="$REPO_ROOT"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/Cargo.toml" && -f "$SCRIPT_DIR/Makefile" && -d "$SCRIPT_DIR/quickshell" ]]; then
    IS_LOCAL_REPO=true
    LOCAL_SRC_DIR="$SCRIPT_DIR"
fi

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
    local subtitle="${1:-Installer}"
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

show_banner "Installer"

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

check_arch() {
    if ! command -v pacman &>/dev/null; then
        die "This installer is designed for Arch Linux."
    fi
}

check_not_root() {
    if [[ "$EUID" -eq 0 ]]; then
        die "Please run this script as a regular user (sudo will be prompted when required)."
    fi
}

# -- Dependencies definitions --------------------------------------------------
# Core runtime dependencies for Agility Shell (Rust daemon + Quickshell)
PACMAN_DEPS=(
    wayland
    niri
    quickshell
    pam
    libpulse
    playerctl
    brightnessctl
    wf-recorder
    upower
    swayidle
    networkmanager
    bluez
    matugen
    jq
    curl
    tar
    gzip
    socat
    pamixer
    grim
    slurp
    cliphist
    wl-clipboard
    qt6-5compat
    qt6-imageformats
    python-pam
    pacman-contrib
)

# Build dependencies required ONLY when compiling from source
SOURCE_BUILD_DEPS=(
    base-devel
    git
    make
    gcc
    pkgconf
    rust
    cargo
)

AUR_DEPS=(
)

check_and_install_source_deps() {
    info "Verifying build dependencies required for compiling from source..."
    local missing_src=()
    for pkg in "${SOURCE_BUILD_DEPS[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            missing_src+=("$pkg")
        fi
    done
    if [[ ${#missing_src[@]} -gt 0 ]]; then
        info "Installing required build dependencies: ${missing_src[*]}..."
        sudo pacman -S --needed --noconfirm "${missing_src[@]}"
        success "Build dependencies installed."
    else
        success "All build dependencies are present."
    fi
}


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

get_pkg_update_info() {
    local pkg="$1"
    local info=""
    info="$(pacman -Qu "$pkg" 2>/dev/null | grep "^$pkg " || true)"
    if [[ -z "$info" ]]; then
        if command -v yay &>/dev/null; then
            info="$(yay -Qu "$pkg" 2>/dev/null | grep "^$pkg " || true)"
        elif command -v paru &>/dev/null; then
            info="$(paru -Qu "$pkg" 2>/dev/null | grep "^$pkg " || true)"
        fi
    fi
    echo "$info"
}

ensure_yay() {
    if command -v yay &>/dev/null; then
        success "yay is already installed."
        return
    elif command -v paru &>/dev/null; then
        success "paru is already installed."
        return
    fi

    info "AUR helper not found -- installing yay from AUR..."
    sudo pacman -S --needed --noconfirm git base-devel

    local tmp
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
    success "yay installed."
}

test_and_install_deps_step_by_step() {
    local standalone="${1:-true}"
    echo
    echo -e "${BOLD}${CYAN}+================================================+${RESET}"
    echo -e "${BOLD}${CYAN}|      Agility Shell - Dependency Doctor         |${RESET}"
    echo -e "${BOLD}${CYAN}+================================================+${RESET}"
    echo -e "Testing all required dependencies one-by-one..."
    echo

    check_arch

    info "Synchronizing Arch package databases..."
    sudo pacman -Sy --noconfirm 2>/dev/null || sudo pacman -Sy || true

    local missing_count=0
    local outdated_count=0
    local installed_count=0

    echo -e "${BOLD}--- [1/2] Official Arch Pacman Packages ---${RESET}"
    for pkg in "${PACMAN_DEPS[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            missing_count=$(( missing_count + 1 ))
            echo -e "  ${YELLOW}[ miss ]${RESET} ${BOLD}${pkg}${RESET} (not installed)"
            prompt_user "         -> Install '${pkg}' via pacman now? [Y/n]: " inst_choice "y"
            case "$inst_choice" in
                [nN]|[nN][oO])
                    echo -e "         ${DIM:-}Skipped ${pkg}.${RESET}"
                    ;;
                *)
                    info "Installing ${pkg}..."
                    if sudo pacman -S --needed --noconfirm "$pkg"; then
                        success "Installed ${pkg}"
                        installed_count=$(( installed_count + 1 ))
                        missing_count=$(( missing_count - 1 ))
                    else
                        error "Failed to install ${pkg}"
                    fi
                    ;;
            esac
        elif is_pkg_outdated "$pkg"; then
            outdated_count=$(( outdated_count + 1 ))
            local up_info
            up_info="$(get_pkg_update_info "$pkg")"
            echo -e "  ${YELLOW}[ update ]${RESET} ${BOLD}${pkg}${RESET} (outdated: ${up_info})"
            prompt_user "         -> Update '${pkg}' via pacman now? [Y/n]: " upd_choice "y"
            case "$upd_choice" in
                [nN]|[nN][oO])
                    echo -e "         ${DIM:-}Skipped update for ${pkg}.${RESET}"
                    ;;
                *)
                    info "Updating ${pkg}..."
                    if sudo pacman -S --noconfirm "$pkg"; then
                        success "Updated ${pkg}"
                        installed_count=$(( installed_count + 1 ))
                        outdated_count=$(( outdated_count - 1 ))
                    else
                        error "Failed to update ${pkg}"
                    fi
                    ;;
            esac
        else
            echo -e "  ${GREEN}[  ok  ]${RESET} ${pkg} (up to date)"
            installed_count=$(( installed_count + 1 ))
        fi
    done

    echo
    echo -e "${BOLD}--- [2/2] AUR Packages ---${RESET}"
    local aur_helper=""
    if command -v yay &>/dev/null; then
        aur_helper="yay"
    elif command -v paru &>/dev/null; then
        aur_helper="paru"
    fi

    for pkg in "${AUR_DEPS[@]}"; do
        if ! is_pkg_installed "$pkg"; then
            missing_count=$(( missing_count + 1 ))
            echo -e "  ${YELLOW}[ miss ]${RESET} ${BOLD}${pkg}${RESET} (AUR package - not installed)"
            if [[ -z "$aur_helper" ]]; then
                warn "AUR helper (yay or paru) is required to install ${pkg}."
                prompt_user "         -> Install yay from AUR now? [Y/n]: " yay_choice "y"
                case "$yay_choice" in
                    [yY]|[yY][eE][sS]|"")
                        ensure_yay
                        aur_helper="yay"
                        ;;
                    *)
                        warn "Cannot install ${pkg} without an AUR helper."
                        continue
                        ;;
                esac
            fi

            prompt_user "         -> Install '${pkg}' using ${aur_helper}? [Y/n]: " aur_choice "y"
            case "$aur_choice" in
                [nN]|[nN][oO])
                    echo -e "         ${DIM:-}Skipped ${pkg}.${RESET}"
                    ;;
                *)
                    info "Installing ${pkg} via ${aur_helper}..."
                    if "$aur_helper" -S --needed --noconfirm "$pkg"; then
                        success "Installed ${pkg}"
                        installed_count=$(( installed_count + 1 ))
                        missing_count=$(( missing_count - 1 ))
                    else
                        error "Failed to install ${pkg}"
                    fi
                    ;;
            esac
        elif is_pkg_outdated "$pkg"; then
            outdated_count=$(( outdated_count + 1 ))
            local up_info
            up_info="$(get_pkg_update_info "$pkg")"
            echo -e "  ${YELLOW}[ update ]${RESET} ${BOLD}${pkg}${RESET} (AUR package outdated: ${up_info})"
            prompt_user "         -> Update '${pkg}' using ${aur_helper}? [Y/n]: " aur_upd_choice "y"
            case "$aur_upd_choice" in
                [nN]|[nN][oO])
                    echo -e "         ${DIM:-}Skipped update for ${pkg}.${RESET}"
                    ;;
                *)
                    info "Updating ${pkg} via ${aur_helper}..."
                    if "$aur_helper" -S --noconfirm "$pkg"; then
                        success "Updated ${pkg}"
                        installed_count=$(( installed_count + 1 ))
                        outdated_count=$(( outdated_count - 1 ))
                    else
                        error "Failed to update ${pkg}"
                    fi
                    ;;
            esac
        else
            echo -e "  ${GREEN}[  ok  ]${RESET} ${pkg} (up to date)"
            installed_count=$(( installed_count + 1 ))
        fi
    done

    echo
    echo -e "${BOLD}--------------------------------------------------${RESET}"
    if [[ "$missing_count" -eq 0 && "$outdated_count" -eq 0 ]]; then
        success "All dependencies are satisfied and up to date!"
    else
        warn "$missing_count missing and $outdated_count outdated dependency/dependencies remain."
    fi
    echo

    if [[ "$standalone" == "true" ]]; then
        if [[ "$missing_count" -eq 0 ]]; then
            prompt_user "  All required dependencies are satisfied! Would you like to install Agility Shell now? [Y/n]: " install_now "y"
            case "$install_now" in
                [yY]|[yY][eE][sS]|"")
                    echo
                    main_menu_choice
                    ;;
                *)
                    echo
                    info "You can install Agility Shell whenever you are ready using:"
                    echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash${RESET}"
                    echo
                    ;;
            esac
        else
            info "You can re-run the dependency checker at any time using:"
            echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash -s -- --deps${RESET}"
            echo
            info "Once dependencies are installed, install the shell using:"
            echo -e "    ${CYAN}curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash${RESET}"
            echo
        fi
    fi
}

check_and_install_deps() {
    info "Synchronizing Arch package databases to inspect updates..."
    sudo pacman -Sy --noconfirm 2>/dev/null || sudo pacman -Sy || true

    info "Auditing system dependencies (checking missing or outdated packages)..."
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

    local need_yay=false
    if [[ (${#missing_aur[@]} -gt 0 || ${#outdated_aur[@]} -gt 0) ]] && ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        need_yay=true
    fi

    if [[ ${#missing_pacman[@]} -eq 0 && ${#outdated_pacman[@]} -eq 0 && ${#missing_aur[@]} -eq 0 && ${#outdated_aur[@]} -eq 0 && "$need_yay" == "false" ]]; then
        success "All required dependencies are already installed and up to date."
        return 0
    fi

    echo
    if [[ ${#missing_pacman[@]} -gt 0 || ${#missing_aur[@]} -gt 0 ]]; then
        warn "Missing dependencies detected:"
        [[ ${#missing_pacman[@]} -gt 0 ]] && echo -e "  ${BOLD}Missing Pacman:${RESET}   ${CYAN}${missing_pacman[*]}${RESET}"
        [[ ${#missing_aur[@]} -gt 0 ]] && echo -e "  ${BOLD}Missing AUR:${RESET}      ${CYAN}${missing_aur[*]}${RESET}"
    fi

    if [[ ${#outdated_pacman[@]} -gt 0 || ${#outdated_aur[@]} -gt 0 ]]; then
        warn "Outdated dependencies detected (updates available in repositories):"
        [[ ${#outdated_pacman[@]} -gt 0 ]] && echo -e "  ${BOLD}Outdated Pacman:${RESET}  ${YELLOW}${outdated_pacman[*]}${RESET}"
        [[ ${#outdated_aur[@]} -gt 0 ]] && echo -e "  ${BOLD}Outdated AUR:${RESET}     ${YELLOW}${outdated_aur[*]}${RESET}"
    fi

    if [[ "$need_yay" == "true" ]]; then
        echo -e "  ${BOLD}AUR Helper:${RESET}       ${CYAN}yay (will be bootstrapped)${RESET}"
    fi
    echo

    echo -e "  Installation options for dependencies:"
    echo -e "  ${BOLD}1)${RESET} Install missing and update outdated dependencies automatically ${GREEN}(Recommended)${RESET}"
    echo -e "  ${BOLD}2)${RESET} Audit and install/update dependencies step-by-step"
    echo -e "  ${BOLD}3)${RESET} Skip (proceed with existing dependencies as-is)"
    echo
    prompt_user "  Choice [1/2/3]: " dep_mode "1"
    case "$dep_mode" in
        1)
            local pacman_targets=("${missing_pacman[@]}" "${outdated_pacman[@]}")
            if [[ ${#pacman_targets[@]} -gt 0 ]]; then
                info "Installing and updating pacman packages (${pacman_targets[*]})..."
                sudo pacman -S --needed --noconfirm "${pacman_targets[@]}"
                if [[ ${#outdated_pacman[@]} -gt 0 ]]; then
                    sudo pacman -S --noconfirm "${outdated_pacman[@]}" || true
                fi
                success "Pacman dependencies installed and updated."
            fi

            if [[ "$need_yay" == "true" ]]; then
                ensure_yay
            fi

            local aur_helper=""
            if command -v yay &>/dev/null; then
                aur_helper="yay"
            elif command -v paru &>/dev/null; then
                aur_helper="paru"
            fi

            local aur_targets=("${missing_aur[@]}" "${outdated_aur[@]}")
            if [[ ${#aur_targets[@]} -gt 0 && -n "$aur_helper" ]]; then
                info "Installing and updating AUR packages via $aur_helper (${aur_targets[*]})..."
                "$aur_helper" -S --needed --noconfirm "${aur_targets[@]}"
                if [[ ${#outdated_aur[@]} -gt 0 ]]; then
                    "$aur_helper" -S --noconfirm "${outdated_aur[@]}" || true
                fi
                success "AUR dependencies installed and updated."
            fi
            ;;
        2)
            test_and_install_deps_step_by_step false
            ;;
        3|[sS][kK][iI][pP])
            warn "Dependency installation skipped by user."
            ;;
        *)
            warn "Invalid choice; skipping dependency installation."
            ;;
    esac
}

# -- Scan and Remove Old Shell from ~/.config -----------------------------------
scan_and_remove_old_shell() {
    local has_old_shell=false
    if [[ -f "$USER_CONFIG/main.py" || -f "$USER_CONFIG/bar.py" || -d "$USER_CONFIG/bar_widgets" || -d "$USER_CONFIG/venv" || -d "$USER_CONFIG/services" ]]; then
        has_old_shell=true
    fi
    if [[ -f "/usr/bin/agl" ]]; then
        if ! file -b "/usr/bin/agl" 2>/dev/null | grep -q "ELF" || [[ ! -f "/usr/bin/agilityd" ]]; then
            has_old_shell=true
        fi
    fi
    if [[ -f "$SYSTEM_DATA/main.py" || -f "$SYSTEM_DATA/bar.py" ]]; then
        has_old_shell=true
    fi

    if [[ "$has_old_shell" == "true" ]]; then
        echo
        info "Scanning system and ~/.config/agility-shell for legacy shell components..."
        warn "Legacy shell components detected!"
        info "Cleaning legacy shell components and transitioning to native architecture..."
        
        if [[ -d "$USER_CONFIG" ]]; then
            local timestamp
            timestamp="$(date +%Y%m%d_%H%M%S)"
            local backup_dir="$HOME/.config/agility-shell.backup-$timestamp"
            
            info "Creating safety backup of user configurations at $backup_dir..."
            cp -r "$USER_CONFIG" "$backup_dir"
            success "Backup created at $backup_dir"

            info "Removing obsolete shell runtime files from $USER_CONFIG while preserving all user configurations..."
            rm -rf "$USER_CONFIG/main.py" "$USER_CONFIG/bar.py" "$USER_CONFIG/bar_widgets" \
                   "$USER_CONFIG/venv" "$USER_CONFIG/services" "$USER_CONFIG/desktop_applets" \
                   "$USER_CONFIG/windows" "$USER_CONFIG/utils" "$USER_CONFIG/snippets" \
                   "$USER_CONFIG/quickshell" "$USER_CONFIG/scripts" "$USER_CONFIG/agility-shell" \
                   "$USER_CONFIG/requirements.txt" "$USER_CONFIG/Makefile" "$USER_CONFIG/PKGBUILD" 2>/dev/null || true
            success "Preserved user configs. ~/.config/agility-shell now cleanly holds configurations only."
        fi

        if [[ -f "/usr/bin/agl" ]]; then
            if ! file -b "/usr/bin/agl" 2>/dev/null | grep -q "ELF" || [[ ! -f "/usr/bin/agilityd" ]]; then
                info "Removing obsolete legacy /usr/bin/agl..."
                sudo rm -f "/usr/bin/agl" 2>/dev/null || true
            fi
        fi

        if [[ -f "$SYSTEM_DATA/main.py" || -f "$SYSTEM_DATA/bar.py" ]]; then
            info "Cleaning legacy files from $SYSTEM_DATA..."
            sudo rm -rf "$SYSTEM_DATA/main.py" "$SYSTEM_DATA/bar.py" "$SYSTEM_DATA/services" "$SYSTEM_DATA/bar_widgets" 2>/dev/null || true
        fi
    fi
}


# -- Prebuilt Binary Fetcher ---------------------------------------------------
download_and_extract_prebuilt() {
    local target_dir="$1"
    local tag="${2:-}"
    local arch
    arch="$(uname -m)"

    case "$arch" in
        x86_64|amd64) arch="x86_64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *)
            warn "Architecture '$arch' does not have official prebuilt binaries."
            return 1
            ;;
    esac

    local tarball_name="agility-shell-${arch}-linux.tar.gz"
    local base_url="https://github.com/TattvaOrg/agility-shell/releases"
    local download_url=""
    local checksum_url=""

    if [[ -n "$tag" && "$tag" != "latest" ]]; then
        local tag_ref="$tag"
        [[ "$tag_ref" =~ ^[0-9] ]] && tag_ref="v$tag_ref"
        download_url="${base_url}/download/${tag_ref}/${tarball_name}"
        checksum_url="${base_url}/download/${tag_ref}/${tarball_name}.sha256"
    else
        download_url="${base_url}/latest/download/${tarball_name}"
        checksum_url="${base_url}/latest/download/${tarball_name}.sha256"
    fi

    info "Fetching prebuilt release binaries for ${arch}..."
    info "URL: $download_url"

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    if ! curl -f -sSL -L "$download_url" -o "$tmp_dir/$tarball_name"; then
        warn "Could not download prebuilt release binaries from GitHub Releases."
        rm -rf "$tmp_dir"
        return 1
    fi

    # Optional SHA256 checksum verification
    if curl -f -sSL -L "$checksum_url" -o "$tmp_dir/${tarball_name}.sha256" 2>/dev/null; then
        info "Verifying SHA256 checksum..."
        local expected_sha actual_sha
        expected_sha="$(awk '{print $1}' "$tmp_dir/${tarball_name}.sha256" | head -n 1)"
        actual_sha="$(sha256sum "$tmp_dir/$tarball_name" | awk '{print $1}')"
        if [[ -n "$expected_sha" && "$expected_sha" != "$actual_sha" ]]; then
            warn "SHA256 checksum mismatch! Expected: $expected_sha, got: $actual_sha"
            rm -rf "$tmp_dir"
            return 1
        fi
        success "SHA256 checksum verified."
    fi

    mkdir -p "$target_dir/target/release"
    info "Extracting prebuilt binaries to $target_dir/target/release..."
    tar -xzf "$tmp_dir/$tarball_name" -C "$target_dir/target/release"
    chmod +x "$target_dir/target/release/agilityd" "$target_dir/target/release/agl" 2>/dev/null || true
    rm -rf "$tmp_dir"

    if [[ -x "$target_dir/target/release/agilityd" && -x "$target_dir/target/release/agl" ]]; then
        success "Prebuilt release binaries (agilityd, agl) ready."
        return 0
    else
        warn "Extracted binaries not found or not executable."
        return 1
    fi
}

# -- Build and Install System Files --------------------------------------------
install_system_files() {
    local src_dir="$1"
    local method="${2:-make}"
    local from_source="${3:-false}"
    local tag="${4:-}"

    cd "$src_dir"

    local used_prebuilt=false
    if [[ "$from_source" == "false" ]]; then
        if [[ -x "$src_dir/target/release/agilityd" && -x "$src_dir/target/release/agl" ]]; then
            info "Using prebuilt release binaries already present in target/release..."
            used_prebuilt=true
        elif download_and_extract_prebuilt "$src_dir" "$tag"; then
            used_prebuilt=true
        else
            warn "Prebuilt release binaries not found or download failed."
            echo ""
            prompt_user "  Would you like to compile Agility Shell from source using cargo? [Y/n]: " compile_choice "y"
            case "$compile_choice" in
                [nN]|[nN][oO])
                    die "Installation aborted: prebuilt binaries unavailable and source build declined."
                    ;;
                *)
                    info "Proceeding with source compilation..."
                    check_and_install_source_deps
                    ;;
            esac
        fi
    else
        info "Compiling Agility Shell from source as requested..."
        check_and_install_source_deps
    fi

    if [[ "$method" == "pacman" ]]; then
        info "Building native Arch pacman package (makepkg)..."
        makepkg -sf --noconfirm
        local pkg_file
        pkg_file="$(ls -t agility-shell-git-*.pkg.tar.* 2>/dev/null | head -n 1 || true)"
        if [[ -n "$pkg_file" && -f "$pkg_file" ]]; then
            info "Installing native Arch pacman package with overwrite protection ($pkg_file)..."
            sudo pacman -U --needed --noconfirm --overwrite "*" "$pkg_file"
            success "Pacman package installed successfully."
        else
            warn "Built package file not found; falling back to direct system installation..."
            if [[ "$used_prebuilt" == "true" ]]; then
                sudo make PREFIX="/usr" PREBUILT_DIR=target/release install-prebuilt
            else
                make
                sudo make PREFIX="/usr" install
            fi
        fi
    else
        if [[ "$used_prebuilt" == "true" ]]; then
            info "Installing prebuilt binaries and system files via Makefile..."
            sudo make PREFIX="/usr" PREBUILT_DIR=target/release install-prebuilt
            success "System files and prebuilt release binaries installed to /usr/bin and /usr/share."
        else
            info "Compiling Next-Gen Rust binaries and installing via root Makefile..."
            make
            sudo make PREFIX="/usr" install
            success "System files and compiled binaries installed to /usr/bin and /usr/share."
        fi
    fi
}


# -- Seed User Config ----------------------------------------------------------
seed_user_configuration() {
    info "Setting up user configuration and state directories..."
    mkdir -p "$USER_CONFIG/config" "$USER_CONFIG/style" "$USER_STATE"

    local src_data="$SYSTEM_DATA"
    if [[ ! -d "$src_data" && -n "$LOCAL_SRC_DIR" ]]; then
        src_data="$LOCAL_SRC_DIR"
    fi

    # Seed baseline config.json if not present
    if [[ ! -f "$USER_CONFIG/config/config.json" && -f "$src_data/config/config.json" ]]; then
        cp "$src_data/config/config.json" "$USER_CONFIG/config/config.json"
        info "Seeded default config.json"
    fi

    # Seed baseline suits.json if not present
    if [[ ! -f "$USER_CONFIG/config/suits.json" && -f "$src_data/config/suits.json" ]]; then
        cp "$src_data/config/suits.json" "$USER_CONFIG/config/suits.json"
        info "Seeded default suits.json"
    fi

    # Migrate or seed baseline styles into custom_style
    mkdir -p "$USER_CONFIG/custom_style"
    if [[ -d "$USER_CONFIG/style" ]]; then
        for f in "$USER_CONFIG/style"/*.css; do
            [[ -f "$f" ]] || continue
            local base_f
            base_f="$(basename "$f")"
            if [[ ! -f "$USER_CONFIG/custom_style/$base_f" ]]; then
                cp "$f" "$USER_CONFIG/custom_style/$base_f"
            fi
        done
    fi

    # Seed template custom_style files if missing
    for tpl in border.css font.css color.css README.md; do
        if [[ ! -f "$USER_CONFIG/custom_style/$tpl" && -f "$src_data/custom_style/$tpl" ]]; then
            cp "$src_data/custom_style/$tpl" "$USER_CONFIG/custom_style/$tpl"
        fi
    done

    # Clean up legacy user style dir to keep user config directory clean
    if [[ -d "$USER_CONFIG/style" ]]; then
        rm -rf "$USER_CONFIG/style"
    fi

    # Prune stale legacy component stylesheets in user custom_style dir
    if [[ -d "$USER_CONFIG/custom_style" ]]; then
        if [[ -f "$USER_CONFIG/custom_style/border.css" && -f "$USER_CONFIG/custom_style/borders.css" ]]; then
            rm -f "$USER_CONFIG/custom_style/borders.css"
        fi
        if [[ -f "$USER_CONFIG/custom_style/font.css" && -f "$USER_CONFIG/custom_style/fonts.css" ]]; then
            rm -f "$USER_CONFIG/custom_style/fonts.css"
        fi

        for f in "$USER_CONFIG/custom_style"/*.css; do
            [[ -f "$f" ]] || continue
            local fname
            fname="$(basename "$f")"
            case "$fname" in
                border.css|font.css|color.css|colors.css|agility-shell-colors.css|custom*.css)
                    ;;
                *)
                    if [[ -f "$src_data/style/$fname" ]]; then
                        rm -f "$f"
                    fi
                    ;;
            esac
        done
    fi

    # Seed baseline niri.kdl if not present
    if [[ -f "$src_data/config/niri.kdl" ]]; then
        mkdir -p "$USER_CONFIG/config"
        if [[ ! -f "$USER_CONFIG/config/niri.kdl" ]]; then
            cp "$src_data/config/niri.kdl" "$USER_CONFIG/config/niri.kdl"
            info "Seeded default niri.kdl configuration."
        elif grep -q '~/.config/agility-shell/start.sh' "$USER_CONFIG/config/niri.kdl"; then
            sed -i 's|spawn-at-startup "bash" "-c" "~/.config/agility-shell/start.sh"|spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service \|\| exec agility-shell"|g' "$USER_CONFIG/config/niri.kdl"
            info "Migrated startup command in existing niri.kdl while preserving all custom keybindings."
        fi
    fi
    success "User configuration initialized."
}

# -- Compositor Integration ---------------------------------------------------
inject_niri_include() {
    local startup_line='spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service || exec agility-shell"'
    local include_line='include "~/.config/agility-shell/config/niri.kdl"'

    local target_dirs=("$HOME/.config/niri")
    if [[ -d "$HOME/.config/Lniri" || -f "$HOME/.config/Lniri/config.kdl" ]]; then
        target_dirs+=("$HOME/.config/Lniri")
    fi

    for niri_config_dir in "${target_dirs[@]}"; do
        local niri_config="$niri_config_dir/config.kdl"
        mkdir -p "$niri_config_dir"

        if [[ ! -f "$niri_config" ]]; then
            info "Creating clean base Niri config in $niri_config..."
            cat << 'BASE_NIRI_EOF' > "$niri_config"
// Niri Base Configuration
prefer-no-csd

input {
    keyboard {
        numlock
    }
    touchpad {
        tap
        natural-scroll
    }
}

binds {
    Mod+T { spawn "alacritty"; }
    Mod+Q { close-window; }
    Mod+Shift+E { quit; }
}
BASE_NIRI_EOF
        fi

        # Remove old deprecated caffyne-shell includes if any
        sed -i '/caffyne-shell/d' "$niri_config" 2>/dev/null || true

        # Update startup line if old one exists
        if grep -qF '~/.config/agility-shell/start.sh' "$niri_config"; then
            info "Updating Niri startup command in $niri_config..."
            sed -i 's|spawn-at-startup "bash" "-c" "~/.config/agility-shell/start.sh"|spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service \|\| exec agility-shell"|g' "$niri_config"
        elif grep -qF 'command -v agility-shell' "$niri_config"; then
            info "Updating Niri startup command in $niri_config..."
            sed -i 's|spawn-at-startup "bash" "-c" "command -v agility-shell >/dev/null \&\& exec agility-shell \|\| exec ~/.config/agility-shell/start.sh"|spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service \|\| exec agility-shell"|g' "$niri_config"
        fi

        if ! grep -qF "$include_line" "$niri_config"; then
            info "Appending Agility Shell include to existing Niri config ($niri_config)..."
            echo "" >> "$niri_config"
            echo "$include_line" >> "$niri_config"
        fi
    done
    success "Niri config integrated safely."
}

setup_matugen() {
    info "Configuring Matugen templates..."
    local matugen_config_dir="$HOME/.config/matugen"
    local matugen_conf="$matugen_config_dir/config.toml"

    mkdir -p "$matugen_config_dir"
    [[ ! -f "$matugen_conf" ]] && touch "$matugen_conf"

    if ! grep -q "^\[config\]$" "$matugen_conf"; then
        printf "[config]\n" >> "$matugen_conf"
    fi

    if ! grep -q "\[templates.agility\]" "$matugen_conf"; then
        cat <<MATUGEN_EOF >> "$matugen_conf"

# Agility Shell Colors
[templates.agility]
input_path = '/usr/share/agility-shell/style/agility-shell-colors.css'
output_path = '~/.config/agility-shell/custom_style/colors.css'
MATUGEN_EOF
    fi
    success "Matugen configured."
}

setup_battery_limit_sudoers() {
    if [[ -d /sys/class/power_supply/BAT0 || -d /sys/class/power_supply/BAT1 || -d /sys/class/power_supply/BAT ]]; then
        info "Configuring passwordless sudo rule for battery charge limiter..."
        local sudoers_file="/etc/sudoers.d/agility-battery"
        echo "$USER ALL=(ALL) NOPASSWD: /usr/share/agility-shell/quickshell/agility/Scripts/system/toggle_battery_limit.sh, $HOME/.config/quickshell/Scripts/system/toggle_battery_limit.sh" | sudo tee "$sudoers_file" >/dev/null || true
        sudo chmod 0440 "$sudoers_file" 2>/dev/null || true
        success "Battery charge limit sudoers rule configured."
    fi
}

setup_systemd_service() {
    if command -v systemctl &>/dev/null; then
        info "Reloading systemd user daemon..."
        systemctl --user daemon-reload || true
        prompt_user "  Would you like to enable the Agility Shell systemd user service on login? [Y/n]: " enable_choice "y"
        case "$enable_choice" in
            [nN]|[nN][oO])
                info "Systemd service enable skipped. You can enable anytime via: systemctl --user enable agility-shell.service"
                ;;
            *)
                systemctl --user enable agility-shell.service || true
                success "Agility Shell systemd user service enabled."
                ;;
        esac
    fi
}

# -- Check if Agility Shell is already installed --------------------------------
is_agility_installed() {
    if [[ -f "/usr/bin/agl" || -f "/usr/bin/agilityd" || -f "/usr/bin/agility-shell" || -d "$SYSTEM_DATA" ]]; then
        return 0
    fi
    if [[ -d "$USER_CONFIG" && (-f "$USER_CONFIG/config/config.json" || -f "$USER_CONFIG/main.py" || -f "$USER_CONFIG/bar.py") ]]; then
        return 0
    fi
    if pacman -Qq agility-shell agility-shell-git &>/dev/null; then
        return 0
    fi
    return 1
}

# -- Update Shell and Cure Configurations --------------------------------------
do_update_and_cure() {
    local tag="${1:-}"
    info "Starting update and configuration cure for Agility Shell..."

    check_and_install_deps

    local work_dir=""
    local cleanup_work_dir=false
    local selected_tag="$tag"

    if [[ "$IS_LOCAL_REPO" == "true" ]]; then
        if [[ "$(realpath "$LOCAL_SRC_DIR" 2>/dev/null)" == "$(realpath "$USER_CONFIG" 2>/dev/null)"* ]]; then
            work_dir="$(mktemp -d)"
            cleanup_work_dir=true
            info "Staging installer sources from $LOCAL_SRC_DIR..."
            cp -r "$LOCAL_SRC_DIR"/* "$work_dir/"
        else
            work_dir="$LOCAL_SRC_DIR"
        fi
    else
        work_dir="$(mktemp -d)"
        cleanup_work_dir=true
        info "Cloning Agility Shell from $REPO_URL..."
        git clone "$REPO_URL" "$work_dir/repo"
        work_dir="$work_dir/repo"

        cd "$work_dir"
        git fetch --prune --tags origin
        git checkout -f main 2>/dev/null || git checkout -b main origin/main
        git reset --hard origin/main
        selected_tag="latest"
    fi

    # 1. Clean legacy shell files & backup user configs
    scan_and_remove_old_shell

    # 2. Update system files
    install_system_files "$work_dir" "make" false "$selected_tag"

    # 3. Cure configuration & setup hooks
    seed_user_configuration
    inject_niri_include
    setup_matugen
    setup_battery_limit_sudoers
    setup_systemd_service

    if [[ "$cleanup_work_dir" == "true" ]]; then
        rm -rf "$work_dir"
    fi

    echo
    success "Agility Shell successfully updated and configuration cured!"
    echo
    echo -e "  ${BOLD}Restart shell to apply changes:${RESET}"
    echo -e "    ${CYAN}agl restart${RESET}   (or systemctl --user restart agility-shell)"
    echo
}

# -- Install Shell (Fresh / Core) -----------------------------------------------
do_install() {
    local method="${1:-make}"
    local from_source="${2:-false}"
    local tag="${3:-}"
    info "Starting installation of Agility Shell (Prebuilt: $([[ "$from_source" == "true" ]] && echo "no (from source)" || echo "yes"))..."

    check_and_install_deps

    local work_dir=""
    local cleanup_work_dir=false
    local selected_tag="$tag"

    if [[ "$IS_LOCAL_REPO" == "true" ]]; then
        # If running from inside ~/.config/agility-shell, stage sources to tmp before deleting old shell
        if [[ "$(realpath "$LOCAL_SRC_DIR" 2>/dev/null)" == "$(realpath "$USER_CONFIG" 2>/dev/null)"* ]]; then
            work_dir="$(mktemp -d)"
            cleanup_work_dir=true
            info "Staging installer sources from $LOCAL_SRC_DIR..."
            cp -r "$LOCAL_SRC_DIR"/* "$work_dir/"
        else
            work_dir="$LOCAL_SRC_DIR"
        fi
    else
        work_dir="$(mktemp -d)"
        cleanup_work_dir=true
        info "Cloning Agility Shell from $REPO_URL..."
        git clone "$REPO_URL" "$work_dir/repo"
        work_dir="$work_dir/repo"

        cd "$work_dir"
        git fetch --prune --tags origin

        if [[ -n "$selected_tag" && "$selected_tag" != "latest" ]]; then
            info "Checking out requested tag: $selected_tag..."
            git checkout -f "$selected_tag" 2>/dev/null || git checkout -f "tags/$selected_tag" 2>/dev/null || true
        elif [[ "$from_source" == "false" ]]; then
            local latest_tag
            latest_tag=$(git tag -l --sort=-v:refname | grep -E '^[0-9]+(\.[0-9]+)+' | head -n 1 || true)
            if [[ -n "$latest_tag" ]]; then
                info "Using latest release tag v$latest_tag..."
                git checkout -f "$latest_tag" 2>/dev/null || git checkout -f "tags/$latest_tag" 2>/dev/null || true
                selected_tag="$latest_tag"
            else
                selected_tag="latest"
            fi
        else
            info "Using latest development source from main..."
            git checkout -f main 2>/dev/null || git checkout -b main origin/main
            git reset --hard origin/main
            selected_tag="latest"
        fi
    fi

    # Scan and delete old shell from ~/.config/agility-shell and system
    scan_and_remove_old_shell

    install_system_files "$work_dir" "$method" "$from_source" "$selected_tag"
    seed_user_configuration
    inject_niri_include
    setup_matugen
    setup_battery_limit_sudoers
    setup_systemd_service

    if [[ "$cleanup_work_dir" == "true" ]]; then
        rm -rf "$work_dir"
    fi

    echo
    success "Agility Shell installed successfully!"
    echo
    echo -e "  ${BOLD}Start shell:${RESET}"
    echo -e "    ${CYAN}agl start${RESET}       (or systemctl --user start agility-shell)"
    echo
    echo -e "  ${BOLD}CLI Commands:${RESET}"
    echo -e "    ${CYAN}agl restart${RESET}     - Restart running shell"
    echo -e "    ${CYAN}agl status${RESET}      - Inspect shell runtime status and logs"
    echo -e "    ${CYAN}agl update${RESET}      - Update shell in place"
    echo -e "    ${CYAN}agl uninstall${RESET}   - Cleanly remove"
    echo
    echo -e "  ${BOLD}User Configuration:${RESET}"
    echo -e "    ${CYAN}~/.config/agility-shell/config/config.json${RESET}"
    echo
}

show_help() {
    cat << EOF
Agility Shell Installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    --update, --cure            Update shell and cure existing configurations
    --fresh                     Open fresh installation menu
    --prebuilt                  Install prebuilt release binaries (Default)
    --from-source, --build, -b  Compile Rust workspace from source using cargo
    --pacman, -p                Install using native Arch pacman package (makepkg -si)
    --make, -m                  Install using Makefile directly (/usr/bin & /usr/share)
    --version, --tag <TAG>      Specify release tag to install (default: latest)
    --deps, --check-deps, -d    Test and install dependencies step-by-step
    --help, -h                  Show this help message

ONELINER:
    curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash

EOF
}

fresh_install_menu() {
    local tag="${1:-}"
    echo
    echo -e "  ${BOLD}Select installation method:${RESET}"
    echo -e "  ${BOLD}1)${RESET} ${CYAN}Latest Release${RESET} (Prebuilt binary) ${GREEN}(Recommended)${RESET}"
    echo -e "     ${DIM}Directly downloads and installs official release binaries.${RESET}"
    echo -e "  ${BOLD}2)${RESET} ${YELLOW}Compile by yourself${RESET} (Build from source)"
    echo -e "     ${DIM}Compiles the Rust workspace locally using cargo.${RESET}"
    echo -e "  ${BOLD}3)${RESET} Cancel"
    echo
    prompt_user "  Enter choice [1/2/3] (default: 1): " inst_choice "1"
    case "$inst_choice" in
        1|[bB][iI][nN]*|[pP][rR][eE]*)
            do_install "make" false "$tag"
            ;;
        2|[sS][oO][uU][rR][cC][eE]*|[bB][uU][iI][lL][dD]*)
            do_install "make" true "$tag"
            ;;
        3|[cC]|[qQ]|[eE][xX][iI][tT])
            info "Installation cancelled."
            exit 0
            ;;
        *)
            die "Invalid choice: '$inst_choice'"
            ;;
    esac
}

main_menu_choice() {
    if is_agility_installed; then
        echo -e "  ${BOLD}Existing Agility Shell installation detected.${RESET}"
        echo
        echo -e "  Please choose an option:"
        echo -e "  ${BOLD}1)${RESET} ${CYAN}Update Shell & Cure Configs${RESET} ${GREEN}(Recommended)${RESET}"
        echo -e "     ${DIM}Safely cures and migrates configs, cleans legacy files, and updates shell.${RESET}"
        echo -e "  ${BOLD}2)${RESET} ${GREEN}Fresh Install${RESET}"
        echo -e "     ${DIM}Perform a fresh install (latest release binary or compile by yourself).${RESET}"
        echo -e "  ${BOLD}3)${RESET} ${BLUE}Test & Install Dependencies Step-by-Step${RESET}"
        echo -e "  ${BOLD}4)${RESET} Cancel"
        echo
        prompt_user "  Enter choice [1/2/3/4] (default: 1): " choice "1"
        case "$choice" in
            1|[uU]|[uU][pP]*)
                do_update_and_cure ""
                ;;
            2|[fF]|[fF][rR]*)
                fresh_install_menu ""
                ;;
            3|[dD]*)
                test_and_install_deps_step_by_step true
                ;;
            4|[qQ]|[eE][xX][iI][tT])
                info "Installation cancelled."
                exit 0
                ;;
            *)
                die "Invalid choice: '$choice'"
                ;;
        esac
    else
        echo -e "  No previous Agility Shell installation found."
        fresh_install_menu ""
    fi
}

main() {
    check_arch
    check_not_root

    local method="make"
    local from_source=false
    local tag=""
    local check_deps_only=false
    local do_update=false
    local interactive=true

    while [[ $# -gt 0 ]]; do
        interactive=false
        case "$1" in
            --deps|--check-deps|-d|deps)
                check_deps_only=true
                shift
                ;;
            --update|--cure|update|cure)
                do_update=true
                shift
                ;;
            --fresh|fresh)
                interactive=true
                shift
                ;;
            --pacman|-p|pacman)
                method="pacman"
                shift
                ;;
            --make|-m|make)
                method="make"
                shift
                ;;
            --from-source|--source|--build|-b|build)
                from_source=true
                shift
                ;;
            --prebuilt)
                from_source=false
                shift
                ;;
            --version|--tag|-v)
                tag="${2:-}"
                shift 2 || shift
                ;;
            --help|-h|help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: '$1'"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ "$check_deps_only" == "true" ]]; then
        test_and_install_deps_step_by_step true
        exit 0
    fi

    if [[ "$do_update" == "true" ]]; then
        do_update_and_cure "$tag"
        exit 0
    fi

    if [[ "$interactive" == "true" ]]; then
        echo
        echo -e "${BOLD}${CYAN}+==================================+${RESET}"
        echo -e "${BOLD}${CYAN}|       Agility Shell Setup        |${RESET}"
        echo -e "${BOLD}${CYAN}+==================================+${RESET}"
        echo
        main_menu_choice
    else
        do_install "$method" "$from_source" "$tag"
    fi
}

main "$@"
