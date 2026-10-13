#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Root Restart Wrapper (Forwarder)
#  Next-Gen Rust & Quickshell Architecture
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/restart.sh" ]]; then
    exec "$SCRIPT_DIR/scripts/restart.sh" "$@"
elif command -v agl >/dev/null 2>&1; then
    exec agl restart "$@"
elif [[ -f "$HOME/.config/agility-shell/scripts/restart.sh" ]]; then
    exec "$HOME/.config/agility-shell/scripts/restart.sh" "$@"
else
    echo "Restart script not found!" >&2
    exit 1
fi
