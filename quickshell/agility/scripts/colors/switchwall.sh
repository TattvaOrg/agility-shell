#!/usr/bin/env bash

# Fast, robust, dependency-light wallpaper and color switch for Agility Shell Material Theme

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="$XDG_STATE_HOME/quickshell"
CONFIG_FILE="$XDG_CONFIG_HOME/agility-shell/config.json"
mkdir -p "$STATE_DIR/user/generated"

imgpath=""
mode_flag=""
type_flag=""
noswitch_flag=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            mode_flag="$2"
            shift 2
            ;;
        --type)
            type_flag="$2"
            shift 2
            ;;
        --image)
            imgpath="$2"
            shift 2
            ;;
        --noswitch)
            noswitch_flag="1"
            shift
            ;;
        -*)
            shift
            ;;
        *)
            if [[ -z "$imgpath" ]]; then
                imgpath="$1"
            fi
            shift
            ;;
    esac
done

# If no image path provided, get current from agl or fallback
if [[ -z "$imgpath" ]]; then
    if [[ -z "$noswitch_flag" ]]; then
        # If run interactively with no args, open wallpaper drawer or file chooser
        if command -v zenity &>/dev/null; then
            imgpath=$(zenity --file-selection --title="Choose Wallpaper" --file-filter="Images | *.jpg *.jpeg *.png *.webp *.bmp" 2>/dev/null)
        fi
    fi
fi

if [[ -z "$imgpath" ]]; then
    imgpath=$(agl wallpaper get 2>/dev/null)
fi

if [[ -z "$imgpath" || ! -f "$imgpath" ]]; then
    imgpath="$HOME/.local/share/agility-shell/wallpapers/18.jpg"
fi

# Determine dark/light mode
if [[ -z "$mode_flag" ]]; then
    mode_flag="dark"
fi

# Apply wallpaper with agl if not --noswitch
if [[ -z "$noswitch_flag" && -f "$imgpath" ]]; then
    agl wallpaper "$imgpath" 2>/dev/null || true
fi

# Generate Material 3 color palette with matugen
if command -v matugen &>/dev/null && [[ -f "$imgpath" ]]; then
    mat_type_arg=()
    if [[ -n "$type_flag" ]]; then
        mat_type_arg=(--type "$type_flag")
    fi
    matugen image "$imgpath" -m "$mode_flag" "${mat_type_arg[@]}" --source-color-index 0 --json hex 2>/dev/null | jq --arg m "$mode_flag" '
        .colors | to_entries | map({key: .key, value: (.value[$m].color // .value.default.color)}) | from_entries
    ' > "$STATE_DIR/user/generated/colors.json" 2>/dev/null || true
fi

# Update wallpaper path in Agility Shell config.json
if [[ -f "$CONFIG_FILE" && -n "$imgpath" ]]; then
    jq --arg p "$imgpath" '.background.wallpaperPath = $p' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
fi

exit 0
