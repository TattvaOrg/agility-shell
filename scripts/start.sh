#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Start Script
#  Next-Gen Rust (`agilityd`, `agl`) & Quickshell Architecture
# =============================================================================

set -euo pipefail

if command -v agl >/dev/null 2>&1; then
    exec agl start "$@"
elif command -v agility-shell >/dev/null 2>&1; then
    exec agility-shell "$@"
elif [[ -x "/usr/share/agility-shell/agility-shell" ]]; then
    exec /usr/share/agility-shell/agility-shell "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd || echo "")"
if [[ -x "$SCRIPT_DIR/agility-shell" ]]; then
    exec "$SCRIPT_DIR/agility-shell" "$@"
fi

echo "Error: Agility Shell installation not found." >&2
exit 1
