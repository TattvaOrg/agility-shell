#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Root Start Wrapper (Forwarder)
#  Next-Gen Rust & Quickshell Architecture
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/start.sh" ]]; then
    exec "$SCRIPT_DIR/scripts/start.sh" "$@"
elif command -v agl >/dev/null 2>&1; then
    exec agl start "$@"
elif command -v agility-shell >/dev/null 2>&1; then
    exec agility-shell "$@"
elif [[ -f "$HOME/.config/agility-shell/scripts/start.sh" ]]; then
    exec "$HOME/.config/agility-shell/scripts/start.sh" "$@"
else
    echo "Error: Agility Shell launcher not found." >&2
    exit 1
fi
