#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Root Uninstall Wrapper (Forwarder)
#  Guarantees 100% backward compatibility for direct execution & curl piping.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/uninstall.sh" ]]; then
    exec "$SCRIPT_DIR/scripts/uninstall.sh" "$@"
elif [[ -f "/usr/share/agility-shell/scripts/uninstall.sh" ]]; then
    exec "/usr/share/agility-shell/scripts/uninstall.sh" "$@"
elif [[ -f "$HOME/.config/agility-shell/scripts/uninstall.sh" ]]; then
    exec "$HOME/.config/agility-shell/scripts/uninstall.sh" "$@"
fi

# Fallback when running piped via curl/stdin:
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
REPO_DIR="$CACHE_DIR/repo"

if [[ -f "$REPO_DIR/scripts/uninstall.sh" ]]; then
    exec "$REPO_DIR/scripts/uninstall.sh" "$@"
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/scripts/uninstall.sh -o "$TMP_DIR/uninstall.sh"
chmod +x "$TMP_DIR/uninstall.sh"
bash "$TMP_DIR/uninstall.sh" "$@"
exit $?
