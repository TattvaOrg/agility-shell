#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Restart Script
#  Gracefully stops running Next-Gen shell processes and relaunches in < 15ms.
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

# If agl is available and not in foreground mode, delegate to agl restart
if [[ "$FOREGROUND" != true ]] && command -v agl >/dev/null 2>&1; then
    exec agl restart
fi

# Check if managed by systemd user service
if [[ "$FOREGROUND" != true ]] && (systemctl --user is-active --quiet agility-shell.service 2>/dev/null || systemctl --user is-enabled --quiet agility-shell.service 2>/dev/null); then
    info "Agility Shell is managed by a systemd user unit. Restarting via systemctl..."
    systemctl --user reset-failed agility-shell.service 2>/dev/null || true
    systemctl --user restart agility-shell.service
    success "Agility Shell systemd service restarted successfully."
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -a "Agility Shell" "Agility Shell" "Shell restarted via systemd" 2>/dev/null || true
    fi
    exit 0
fi

info "Gracefully restarting Agility Shell Next-Gen..."

# Terminate existing agility quickshell and agilityd instances safely
pkill -f "quickshell.*agility" 2>/dev/null || true
pkill -f "agility.*shell.qml" 2>/dev/null || true
killall -q -15 agilityd 2>/dev/null || true
sleep 0.015
pkill -9 -f "quickshell.*agility" 2>/dev/null || true
pkill -9 -f "agility.*shell.qml" 2>/dev/null || true
killall -q -9 agilityd 2>/dev/null || true

# Determine launcher or shell script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd || echo "")"

if command -v agility-shell >/dev/null 2>&1; then
    exec agility-shell ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
elif [[ -x "$REPO_ROOT/agility-shell" ]]; then
    exec "$REPO_ROOT/agility-shell" ${PASS_ARGS[@]+"${PASS_ARGS[@]}"}
else
    error "Could not find agility-shell executable to relaunch."
    exit 1
fi
