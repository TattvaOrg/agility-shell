#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Restart Script
#  Gracefully stops running shell processes and relaunches Agility Shell.
# =============================================================================

set -euo pipefail

# -- Colors -------------------------------------------------------------------
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

# Parse arguments
FOREGROUND=false
PASS_ARGS=()
for arg in "$@"; do
    if [[ "$arg" == "--foreground" || "$arg" == "-f" ]]; then
        FOREGROUND=true
    else
        PASS_ARGS+=("$arg")
    fi
done

# Check if managed by systemd user service first
if [[ "$FOREGROUND" != true ]] && systemctl --user is-active --quiet agility-shell.service 2>/dev/null; then
    info "Agility Shell is running as a systemd user unit. Restarting via systemctl..."
    systemctl --user restart agility-shell.service
    success "Agility Shell systemd service restarted successfully."
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Agility Shell" "Agility Shell" "Shell restarted via systemd" 2>/dev/null || true
    fi
    exit 0
fi

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "")"
USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
SYSTEM_DATA="/usr/share/agility-shell"
SYSTEM_VENV="/usr/lib/agility-shell/venv"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
LOG_FILE="$LOG_DIR/shell.log"

mkdir -p "$LOG_DIR"

info "Restarting Agility Shell..."

# -- 1. Terminate existing shell processes safely -----------------------------
info "Stopping running Agility Shell & Quickshell instances..."

find_shell_pids() {
    local found_pids=()
    local raw_pids
    raw_pids=$(pgrep -x "agility-shell" 2>/dev/null || true)
    raw_pids+=" $(pgrep -f "python.*agility-shell/main\.py" 2>/dev/null || true)"
    raw_pids+=" $(pgrep -f "python.*[m]ain\.py" 2>/dev/null || true)"
    raw_pids+=" $(pgrep -f "[q]uickshell.*(agility|Awe)|[q]s.*(agility|Awe)" 2>/dev/null || true)"

    for pid in $raw_pids; do
        [[ -z "$pid" ]] && continue
        if [[ "$pid" -eq "$$" || "$pid" -eq "$PPID" ]]; then
            continue
        fi
        local cmdline
        cmdline=$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)
        if [[ "$cmdline" =~ restart\.sh|update\.sh|install\.sh|/bin/agl ]]; then
            continue
        fi
        found_pids+=("$pid")
    done
    echo "${found_pids[@]:-}"
}

ALL_PIDS=$(find_shell_pids)

if [[ -n "${ALL_PIDS// /}" ]]; then
    kill -15 $ALL_PIDS 2>/dev/null || true
    
    for i in {1..20}; do
        REMAINING=$(find_shell_pids)
        if [[ -z "${REMAINING// /}" ]]; then
            break
        fi
        sleep 0.1
    done

    REMAINING=$(find_shell_pids)
    if [[ -n "${REMAINING// /}" ]]; then
        warn "Force terminating lingering processes..."
        kill -9 $REMAINING 2>/dev/null || true
        sleep 0.2
    fi
fi

success "All previous shell processes stopped."
sleep 0.3

# -- 2. Determine launcher target ---------------------------------------------
TARGET_DIR=""
PYTHON_BIN="python3"

if [[ -n "$REPO_ROOT" && -f "$REPO_ROOT/main.py" && -f "$REPO_ROOT/bar.py" ]]; then
    # In-tree development checkout
    TARGET_DIR="$REPO_ROOT"
    if [[ -x "$REPO_ROOT/venv/bin/python3" ]]; then
        PYTHON_BIN="$REPO_ROOT/venv/bin/python3"
    elif [[ -x "$SYSTEM_VENV/bin/python3" ]]; then
        PYTHON_BIN="$SYSTEM_VENV/bin/python3"
    fi
elif [[ -d "$SYSTEM_DATA" && -f "$SYSTEM_DATA/main.py" ]]; then
    # System-wide installation
    TARGET_DIR="$SYSTEM_DATA"
    if [[ -x "$SYSTEM_VENV/bin/python3" ]]; then
        PYTHON_BIN="$SYSTEM_VENV/bin/python3"
    fi
elif [[ -d "$USER_CONFIG" && -f "$USER_CONFIG/main.py" ]]; then
    # Legacy user-config installation
    TARGET_DIR="$USER_CONFIG"
    if [[ -x "$USER_CONFIG/venv/bin/python3" ]]; then
        PYTHON_BIN="$USER_CONFIG/venv/bin/python3"
    fi
else
    error "Could not find Agility Shell main.py in $SYSTEM_DATA, $USER_CONFIG, or $REPO_ROOT"
    exit 1
fi

info "Launching updated shell from: $TARGET_DIR"
info "Using Python:                 $PYTHON_BIN"

# -- 3. Start Shell -----------------------------------------------------------
cd "$TARGET_DIR"

if [[ "$FOREGROUND" == true ]]; then
    info "Running in foreground mode..."
    exec "$PYTHON_BIN" main.py ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
else
    if command -v setsid >/dev/null 2>&1; then
        setsid "$PYTHON_BIN" main.py ${PASS_ARGS[@]+"${PASS_ARGS[@]}"} </dev/null >> "$LOG_FILE" 2>&1 &
    else
        nohup "$PYTHON_BIN" main.py ${PASS_ARGS[@]+"${PASS_ARGS[@]}"} </dev/null >> "$LOG_FILE" 2>&1 &
    fi
    DISOWN_PID=$!
    disown "$DISOWN_PID" 2>/dev/null || true
    
    sleep 1.0
    if kill -0 "$DISOWN_PID" 2>/dev/null; then
        success "Agility Shell started with PID $DISOWN_PID"
        info "Log output: $LOG_FILE"
        
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -a "Agility Shell" "Agility Shell" "Shell restarted successfully" 2>/dev/null || true
        fi
    else
        error "Failed to start Agility Shell! Check logs at $LOG_FILE"
        exit 1
    fi
fi
