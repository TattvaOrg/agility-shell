#!/usr/bin/env python3
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
PRIMARY_PREFS = os.path.join(HOME, ".config/agility-shell/settings_prefs.json")
CACHE_PREFS = os.path.join(HOME, ".cache/quickshell/settings_prefs.json")
PREFS_PATH = PRIMARY_PREFS if os.path.isfile(PRIMARY_PREFS) else CACHE_PREFS
NIRI_CONFIG_PATH = os.path.join(HOME, ".config/agility-shell/config/niri.kdl")

DEFAULT_ACTION_SHORTCUTS = [
    {"id": "launcher", "title": "Open Launcher", "key": "Mod+Space", "cmd": ["agl", "toggle", "launcher"]},
    {"id": "settings", "title": "Open Settings", "key": "Mod+S", "cmd": ["agl", "toggle", "settings"]},
    {"id": "controlCenter", "title": "Control Center", "key": "Mod+C", "cmd": ["agl", "toggle", "cc"]},
    {"id": "dashboard", "title": "Open Dash", "key": "Mod+D", "cmd": ["agl", "toggle", "dash"]},
    {"id": "wallpaper", "title": "Wallpaper Gallery", "key": "Mod+Shift+W", "cmd": ["agl", "toggle", "WallpaperPicker"]},
    {"id": "clipboard", "title": "Clipboard History", "key": "Mod+V", "cmd": ["agl", "toggle", "clipboard"]},
    {"id": "screenshot", "title": "Screenshot Tool", "key": "Mod+Shift+S", "cmd": ["agl", "toggle", "screenshot"]},
    {"id": "powerMenu", "title": "Power Menu", "key": "Mod+Shift+E", "cmd": ["agl", "toggle", "power"]}
]

def format_spawn_args(parts):
    formatted = " ".join(f'"{p}"' for p in parts)
    return f"spawn {formatted};"

def sync_niri(action_shortcuts, custom_shortcuts):
    os.makedirs(os.path.dirname(NIRI_CONFIG_PATH), exist_ok=True)
    
    lines = [
        'spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service || exec agility-shell"',
        "",
        "layout {",
        '    background-color "transparent"',
        "}",
        "",
        "overview {",
        "    workspace-shadow {",
        "        off",
        "    }",
        "}",
        "",
        "layer-rule {",
        '    match namespace="^awww-daemon$"',
        "    place-within-backdrop true",
        "}",
        "",
        "binds {"
    ]

    # Action Shortcuts
    for sc in action_shortcuts:
        key = sc.get("key", "").strip()
        title = sc.get("title", "")
        cmd = sc.get("cmd", [])
        if key and cmd:
            spawn_str = format_spawn_args(cmd)
            lines.append(f'    {key:<13} hotkey-overlay-title="{title}" {{ {spawn_str} }}')

    # Custom Shortcuts
    if custom_shortcuts:
        lines.append("")
        lines.append("    // Custom user shortcuts")
        for sc in custom_shortcuts:
            key = sc.get("key", "").strip()
            name = sc.get("name", "Custom")
            command = sc.get("command", "").strip()
            if key and command:
                lines.append(f'    {key:<13} hotkey-overlay-title="{name}" {{ spawn "bash" "-c" "{command}"; }}')

    # Hardware keys
    lines.append("")
    lines.append('    XF86AudioRaiseVolume allow-when-locked=true { spawn "agl" "volume" "up"; }')
    lines.append('    XF86AudioLowerVolume allow-when-locked=true { spawn "agl" "volume" "down"; }')
    lines.append('    XF86AudioMute        allow-when-locked=true { spawn "agl" "volume" "mute"; }')
    lines.append('    XF86MonBrightnessUp   allow-when-locked=true { spawn "agl" "brightness" "up"; }')
    lines.append('    XF86MonBrightnessDown allow-when-locked=true { spawn "agl" "brightness" "down"; }')
    lines.append("}")
    lines.append("")

    content = "\n".join(lines)
    with open(NIRI_CONFIG_PATH, "w") as f:
        f.write(content)

    # Reload niri
    try:
        subprocess.run(["niri", "msg", "action", "load-config-file"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def main():
    action_shortcuts = DEFAULT_ACTION_SHORTCUTS
    custom_shortcuts = []

    # Check CLI arguments or preferences file
    if len(sys.argv) > 1 and sys.argv[1].strip():
        try:
            payload = json.loads(sys.argv[1])
            action_shortcuts = payload.get("actionShortcuts", DEFAULT_ACTION_SHORTCUTS)
            custom_shortcuts = payload.get("customShortcuts", [])
        except Exception as e:
            pass
    elif os.path.isfile(PREFS_PATH):
        try:
            with open(PREFS_PATH, "r") as f:
                prefs = json.load(f)
                action_shortcuts = prefs.get("actionShortcuts", DEFAULT_ACTION_SHORTCUTS)
                custom_shortcuts = prefs.get("customShortcuts", [])
        except Exception:
            pass

    sync_niri(action_shortcuts, custom_shortcuts)
    print("✓ Shortcuts synchronized successfully.")

if __name__ == "__main__":
    main()
