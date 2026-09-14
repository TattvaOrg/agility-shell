#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Start Script
# =============================================================================

set -euo pipefail

if command -v agility-shell >/dev/null 2>&1; then
    exec agility-shell "$@"
elif [[ -x "/usr/share/agility-shell/agility-shell" ]]; then
    exec /usr/share/agility-shell/agility-shell "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "")"
if [[ -f "$SCRIPT_DIR/main.py" ]]; then
    cd "$SCRIPT_DIR"
    source "$SCRIPT_DIR/venv/bin/activate" 2>/dev/null || true
    exec python3 main.py "$@"
fi

USER_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/agility-shell"
if [[ -f "$USER_CONFIG/main.py" ]]; then
    cd "$USER_CONFIG"
    source "$USER_CONFIG/venv/bin/activate" 2>/dev/null || true
    exec python3 main.py "$@"
fi

echo "Error: Agility Shell installation not found." >&2
exit 1
