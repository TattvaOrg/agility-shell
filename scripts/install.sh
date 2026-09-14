#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Installer
#  Arch Linux - Distributed System-Wide Installation
# =============================================================================

set -euo pipefail

REPO_URL="https://github.com/TattvaOrg/agility-shell.git"
SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_LIB="/usr/lib/agility-shell"
SYSTEM_VENV="$SYSTEM_LIB/venv"
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
if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/main.py" && -f "$REPO_ROOT/bar.py" && -d "$REPO_ROOT/bar_widgets" ]]; then
    IS_LOCAL_REPO=true
    LOCAL_SRC_DIR="$REPO_ROOT"
elif [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/main.py" && -f "$SCRIPT_DIR/bar.py" && -d "$SCRIPT_DIR/bar_widgets" ]]; then
    IS_LOCAL_REPO=true
    LOCAL_SRC_DIR="$SCRIPT_DIR"
fi

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

cat << "EOF"

                       m                
                     wq                 
                   qqX                  
                  dqd                   
                wwwp      1             
              .ppqm     Jr              
             <wqqp     pp               
            !dpqw    ~ww                
            pppd_   [pq;                
           CpqqL    pwU   `c            
          (pqqq    Qpp    ww!           
         YmqqqZ   ?qqw   |ppp           
        ]pqwww    qww    Zqqwml         
        qpqw:     d.      Owppq"        
       )pw       C          .mwL        
       wp                     wp[       
      _b                       qq,      
      m                          Z   
      
EOF

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

check_and_install_deps() {
    info "Checking system dependencies..."
    local missing_pacman=()
    local missing_aur=()

    for pkg in "${PACMAN_DEPS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing_pacman+=("$pkg")
        fi
    done

    for pkg in "${AUR_DEPS[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            missing_aur+=("$pkg")
        fi
    done

    local need_yay=false
    if [[ ${#missing_aur[@]} -gt 0 ]] && ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
        need_yay=true
    fi

    if [[ ${#missing_pacman[@]} -eq 0 && ${#missing_aur[@]} -eq 0 && "$need_yay" == "false" ]]; then
        success "All required dependencies are already installed."
        return 0
    fi

    echo
    warn "The following dependencies are missing and required:"
    if [[ ${#missing_pacman[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}Pacman packages:${RESET} ${CYAN}${missing_pacman[*]}${RESET}"
    fi
    if [[ ${#missing_aur[@]} -gt 0 ]]; then
        echo -e "  ${BOLD}AUR packages:${RESET}    ${CYAN}${missing_aur[*]}${RESET}"
    fi
    if [[ "$need_yay" == "true" ]]; then
        echo -e "  ${BOLD}AUR Helper:${RESET}      ${CYAN}yay (will be bootstrapped)${RESET}"
    fi
    echo

    prompt_user "  Would you like to install the missing dependencies now? [Y/n]: " dep_choice "y"
    case "$dep_choice" in
        [nN]|[nN][oO])
            warn "Dependency installation skipped by user."
            ;;
        *)
            if [[ ${#missing_pacman[@]} -gt 0 ]]; then
                info "Installing missing pacman packages..."
                sudo pacman -S --needed --noconfirm "${missing_pacman[@]}"
                success "Pacman dependencies installed."
            fi

            if [[ "$need_yay" == "true" ]]; then
                ensure_yay
            fi

            if [[ ${#missing_aur[@]} -gt 0 ]]; then
                local aur_helper="yay"
                if command -v paru &>/dev/null; then
                    aur_helper="paru"
                fi
                info "Installing missing AUR packages using $aur_helper..."
                "$aur_helper" -S --needed --noconfirm "${missing_aur[@]}"
                success "AUR dependencies installed."
            fi
            ;;
    esac
}

# -- Scan and Remove Old Shell from ~/.config -----------------------------------
scan_and_remove_old_shell() {
    local has_old_shell=false
    if [[ -f "$USER_CONFIG/main.py" || -f "$USER_CONFIG/bar.py" || -d "$USER_CONFIG/bar_widgets" || -d "$USER_CONFIG/venv" || -d "$USER_CONFIG/services" ]]; then
        has_old_shell=true
    fi

    if [[ "$has_old_shell" == "true" ]]; then
        echo
        info "Scanning ~/.config/agility-shell for old monolithic shell..."
        warn "Old shell detected in $USER_CONFIG!"
        info "Deleting old shell from ~/.config/agility-shell and transitioning to distributed system installation..."
        
        local timestamp
        timestamp="$(date +%Y%m%d_%H%M%S)"
        local backup_dir="$HOME/.config/agility-shell.backup-$timestamp"
        
        info "Creating safety backup of user configurations at $backup_dir..."
        cp -r "$USER_CONFIG" "$backup_dir"
        success "Backup created at $backup_dir"

        local tmp_data
        tmp_data="$(mktemp -d)"
        [[ -d "$USER_CONFIG/config" ]] && cp -r "$USER_CONFIG/config" "$tmp_data/"
        [[ -d "$USER_CONFIG/wallpapers" ]] && cp -r "$USER_CONFIG/wallpapers" "$tmp_data/"
        [[ -d "$USER_CONFIG/style" ]] && cp -r "$USER_CONFIG/style" "$tmp_data/"
        [[ -d "$USER_CONFIG/themes" ]] && cp -r "$USER_CONFIG/themes" "$tmp_data/"
        [[ -f "$USER_CONFIG/widget_settings.json" ]] && cp "$USER_CONFIG/widget_settings.json" "$tmp_data/"

        info "Deleting old shell Python source files, venv, and scripts from $USER_CONFIG..."
        rm -rf "$USER_CONFIG"
        mkdir -p "$USER_CONFIG"

        # Restore user custom data
        cp -r "$tmp_data"/* "$USER_CONFIG/" 2>/dev/null || true
        rm -rf "$tmp_data"
        success "Old shell deleted. ~/.config/agility-shell now cleanly holds user configurations only."
    fi
}


# -- Build and Install System Files --------------------------------------------
install_system_files() {
    local src_dir="$1"
    local method="${2:-make}"

    cd "$src_dir"

    if [[ "$method" == "pacman" ]]; then
        info "Building and installing native Arch pacman package (makepkg)..."
        makepkg -sif --noconfirm
        success "Pacman package installed successfully."
    else
        info "Building native snippets and installing via root Makefile..."
        make
        sudo make PREFIX="/usr" install
        sudo make PREFIX="/usr" install-venv
        success "System files and dedicated virtualenv installed to /usr/share and /usr/lib."
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

    # Seed baseline styles if not present
    for css in borders.css fonts.css colors.css; do
        if [[ ! -f "$USER_CONFIG/style/$css" && -f "$src_data/style/$css" ]]; then
            cp "$src_data/style/$css" "$USER_CONFIG/style/$css"
        fi
    done
    success "User configuration initialized."
}

# -- Compositor Integration ---------------------------------------------------
inject_niri_include() {
    local niri_config_dir="$HOME/.config/niri"
    local niri_config="$niri_config_dir/config.kdl"
    local startup_line='spawn-at-startup "bash" "-c" "command -v agility-shell >/dev/null && exec agility-shell || exec ~/.config/agility-shell/start.sh"'
    local include_line='include "~/.config/agility-shell/config/niri.kdl"'

    mkdir -p "$niri_config_dir"

    if [[ ! -f "$niri_config" ]]; then
        info "Creating clean base Niri config..."
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

    # Remove old includes if any
    sed -i '/caffyne-shell/d' "$niri_config" 2>/dev/null || true

    # Update startup line if old one exists
    if grep -qF '~/.config/agility-shell/start.sh' "$niri_config" && ! grep -qF 'command -v agility-shell' "$niri_config"; then
        info "Updating Niri startup command to use agility-shell system binary..."
        sed -i 's|spawn-at-startup "bash" "-c" "~/.config/agility-shell/start.sh"|spawn-at-startup "bash" "-c" "command -v agility-shell >/dev/null \&\& exec agility-shell \|\| exec ~/.config/agility-shell/start.sh"|g' "$niri_config"
    fi

    if ! grep -qF "$include_line" "$niri_config"; then
        info "Appending Agility Shell include to existing Niri config..."
        echo "" >> "$niri_config"
        echo "$include_line" >> "$niri_config"
    fi
    success "Niri config integrated."
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
output_path = '~/.config/agility-shell/style/colors.css'
MATUGEN_EOF
    fi
    success "Matugen configured."
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

do_install() {
    local method="${1:-make}"
    info "Starting installation of Agility Shell (Method: $method)..."

    check_and_install_deps

    local work_dir=""
    local cleanup_work_dir=false
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
    fi

    # Scan and delete old shell from ~/.config/agility-shell
    scan_and_remove_old_shell

    install_system_files "$work_dir" "$method"
    seed_user_configuration
    inject_niri_include
    setup_matugen
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
    echo -e "    ${CYAN}agl update${RESET}      - Rebuild and update in place"
    echo -e "    ${CYAN}agl uninstall${RESET}   - Cleanly remove"
    echo
    echo -e "  ${BOLD}User Configuration:${RESET}"
    echo -e "    ${CYAN}~/.config/agility-shell/config/config.json${RESET}"
    echo
}

main() {
    echo
    echo -e "${BOLD}${CYAN}+==================================+${RESET}"
    echo -e "${BOLD}${CYAN}|       Agility Shell Setup        |${RESET}"
    echo -e "${BOLD}${CYAN}+==================================+${RESET}"
    echo

    check_arch
    check_not_root

    echo -e "  Please choose an installation method:"
    echo -e "  ${BOLD}1)${RESET} ${CYAN}Native Arch Package (makepkg -si)${RESET}  (Recommended - tracked by pacman)"
    echo -e "  ${BOLD}2)${RESET} ${GREEN}Direct System Install (make install)${RESET} (Installed into /usr/share & /usr/lib)"
    echo -e "  ${BOLD}3)${RESET} Cancel"
    echo
    prompt_user "  Choice [1/2/3]: " choice "1"
    case "$choice" in
        1)
            do_install "pacman"
            ;;
        2)
            do_install "make"
            ;;
        3|[qQ]|[eE][xX][iI][tT])
            info "Installation cancelled."
            exit 0
            ;;
        *)
            die "Invalid choice: '$choice'"
            ;;
    esac
}

main "$@"
