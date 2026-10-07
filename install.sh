#!/usr/bin/env bash
# =============================================================================
#  Agility Shell -- Root Install Wrapper (Forwarder)
#  Guarantees 100% backward compatibility for curl piping and direct execution.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/scripts/install.sh" ]]; then
    exec "$SCRIPT_DIR/scripts/install.sh" "$@"
fi

# Fallback when running piped via curl/stdin without an in-tree git clone:
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/agility-shell"
REPO_DIR="$CACHE_DIR/repo"
REPO_URL="https://github.com/TattvaOrg/agility-shell.git"

if [[ -d "$REPO_DIR/.git" ]]; then
    echo "[agility] Reusing repository cache at $REPO_DIR..."
    cd "$REPO_DIR"
    git remote set-url origin "$REPO_URL" 2>/dev/null || true
    git fetch --prune --tags origin
else
    echo "[agility] Initializing repository cache at $REPO_DIR..."
    mkdir -p "$CACHE_DIR"
    git clone "$REPO_URL" "$REPO_DIR"
fi

exec "$REPO_DIR/scripts/install.sh" "$@"
