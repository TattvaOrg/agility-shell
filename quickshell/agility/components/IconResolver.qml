pragma Singleton
import QtQuick

Item {
    id: root

    // Base directory for SVG assets inside quickshell bundle
    readonly property string svgsDir: Qt.resolvedUrl("../assets").toString()

    // Mapping from common app IDs & categories to Phosphor duotone SVGs
    readonly property var iconMap: ({
        // Browsers
        "firefox": "globe-duotone.svg",
        "org.mozilla.firefox": "globe-duotone.svg",
        "chromium": "globe-duotone.svg",
        "google-chrome": "globe-duotone.svg",
        "brave": "shield-check-duotone.svg",
        "browser": "globe-duotone.svg",

        // Terminals
        "terminal": "terminal-window-duotone.svg",
        "kitty": "terminal-window-duotone.svg",
        "alacritty": "terminal-window-duotone.svg",
        "foot": "terminal-window-duotone.svg",
        "wezterm": "terminal-window-duotone.svg",
        "ghostty": "terminal-window-duotone.svg",

        // Editors & Dev
        "code": "code-duotone.svg",
        "vscode": "code-duotone.svg",
        "nvim": "brackets-curly-duotone.svg",
        "neovim": "brackets-curly-duotone.svg",
        "vim": "brackets-curly-duotone.svg",
        "git": "git-branch-duotone.svg",

        // Communication
        "discord": "chat-circle-dots-duotone.svg",
        "com.discordapp.discord": "chat-circle-dots-duotone.svg",
        "telegram": "paper-plane-tilt-duotone.svg",
        "org.telegram.desktop": "paper-plane-tilt-duotone.svg",
        "slack": "slack-logo-duotone.svg",
        "mail": "envelope-simple-duotone.svg",

        // Media & Audio
        "spotify": "music-notes-duotone.svg",
        "com.spotify.client": "music-notes-duotone.svg",
        "mpv": "play-circle-duotone.svg",
        "vlc": "video-duotone.svg",
        "media": "music-notes-duotone.svg",
        "music": "headphones-duotone.svg",

        // File Managers
        "files": "folder-duotone.svg",
        "nautilus": "folder-duotone.svg",
        "org.gnome.nautilus": "folder-duotone.svg",
        "dolphin": "folder-duotone.svg",
        "org.kde.dolphin": "folder-duotone.svg",
        "thunar": "folder-duotone.svg",

        // System & Hardware Controls
        "settings": "gear-six-duotone.svg",
        "gnome-control-center": "gear-six-duotone.svg",
        "wifi": "wifi-high-duotone.svg",
        "network": "wifi-high-duotone.svg",
        "bluetooth": "bluetooth-duotone.svg",
        "volume": "speaker-high-duotone.svg",
        "volume-low": "speaker-low-duotone.svg",
        "volume-mute": "speaker-x-duotone.svg",
        "battery": "battery-charging-duotone.svg",
        "battery-low": "battery-warning-duotone.svg",
        "brightness": "sun-duotone.svg",
        "sun": "sun-duotone.svg",
        "moon": "moon-duotone.svg",
        "lock": "lock-key-duotone.svg",
        "power": "power-duotone.svg",
        "caffeine": "coffee-duotone.svg",
        "camera": "camera-duotone.svg",
        "record": "record-duotone.svg",
        "bell": "bell-duotone.svg",
        "bell-slash": "bell-slash-duotone.svg",
        "clock": "clock-duotone.svg",
        "calendar": "calendar-blank-duotone.svg",
        "weather": "cloud-sun-duotone.svg",
        "trash": "trash-duotone.svg",
        "search": "magnifying-glass-duotone.svg",
        "calculator": "calculator-duotone.svg",
        "clipboard": "clipboard-text-duotone.svg",

        // Minflair & Media Controls
        "player-play": "player-play.svg",
        "player-pause": "player-pause.svg",
        "player-previous": "player-previous.svg",
        "player-next": "player-next.svg",
        "player-shuffle": "player-shuffle.svg",
        "player-loop": "player-loop.svg",
        "player-loop-once": "player-loop-once.svg",
        "player-stop": "player-stop.svg",

        // Navigation & Status
        "chevron-right": "chevron-right.svg",
        "chevron-left": "chevron-left.svg",
        "chevron-up": "chevron-up.svg",
        "chevron-down": "chevron-down.svg",
        "check": "check.svg",
        "sparkles": "sparkles.svg",
        "sparkle": "sparkles.svg",
        "star": "star.svg",
        "gamepad": "gamepad.svg",
        "keybinds": "keybinds-icon.svg",
        "packages": "packagemanager-icon.svg",
        "refresh": "refresh.svg",
        "hourglass": "clock.svg",
        "arrow-right": "chevron-right.svg"
    })

    /// Resolves an app ID, icon name, or filename into a valid image URL.
    function resolveIcon(iconNameOrAppId) {
        if (!iconNameOrAppId || iconNameOrAppId === "") {
            return ""
        }

        var key = iconNameOrAppId.toString().trim()

        // If already a full URL or absolute path
        if (key.startsWith("file://") || key.startsWith("image://") || key.startsWith("qrc:/") || key.startsWith("/")) {
            return key
        }

        // If directly provided as a .svg filename
        if (key.endsWith(".svg")) {
            return root.svgsDir + "/" + key
        }

        // Normalize reverse-DNS appId (e.g. "org.mozilla.firefox" -> "firefox")
        var normalized = key.toLowerCase()
        if (root.iconMap[normalized]) {
            return root.svgsDir + "/" + root.iconMap[normalized]
        }

        // Try extracting suffix if reverse-DNS
        var parts = normalized.split(".")
        if (parts.length > 1) {
            var leaf = parts[parts.length - 1]
            if (root.iconMap[leaf]) {
                return root.svgsDir + "/" + root.iconMap[leaf]
            }
        }

        // If recognized flat icon from minflair SVG suite
        if (root.flatIcons[normalized]) {
            return root.svgsDir + "/" + normalized + ".svg"
        }

        // Default to phosphor duotone icon
        return root.svgsDir + "/" + normalized + "-duotone.svg"
    }

    readonly property var flatIcons: ({
        "3s": 1, "agility": 1, "apps-filled": 1, "apps": 1, "bar-filled": 1, "bar": 1,
        "bell-dot": 1, "bell-off": 1, "bell": 1, "bluetooth-off": 1, "bluetooth": 1,
        "box": 1, "calendar": 1, "capture-filled": 1, "capture": 1,
        "charger-filled": 1, "charger": 1, "check": 1, "chevron-down": 1,
        "chevron-left": 1, "chevron-right": 1, "chevron-up": 1, "circle-medium": 1,
        "clipboard": 1, "clock": 1, "code": 1, "coffee-filled": 1, "coffee": 1,
        "color-palette-filled": 1, "color-palette": 1, "commit": 1, "cpu": 1,
        "cursor-filled": 1, "cursor": 1, "download": 1, "eye-off": 1, "eye": 1,
        "font": 1, "fork": 1, "gamepad-filled": 1, "gamepad": 1, "ghost": 1,
        "github": 1, "hyprland": 1, "info-filled": 1, "info": 1, "keybinds-icon": 1,
        "keyboard-filled": 1, "keyboard": 1, "layout-filled": 1, "lock": 1,
        "logout": 1, "microphone-off": 1, "microphone": 1, "minus": 1,
        "monitor-filled": 1, "monitor": 1, "moon-filled": 1, "moon": 1,
        "music": 1, "neovim": 1, "ocr": 1, "packagemanager-icon": 1,
        "picture-spark": 1, "picture": 1, "player-loop-once": 1, "player-loop": 1,
        "player-next": 1, "player-pause": 1, "player-play": 1, "player-previous": 1,
        "player-shuffle": 1, "player-stop": 1, "plus": 1, "power": 1,
        "quote": 1, "record-area": 1, "record-icon": 1, "refresh": 1,
        "reload": 1, "rocket": 1, "screenshot-area": 1, "search": 1,
        "settings-icon": 1, "sparkles-filled": 1, "sparkles": 1,
        "square-rounded-check-filled": 1, "square-rounded-check": 1,
        "star-filled": 1, "star": 1, "sun": 1, "touchpad": 1, "trash": 1,
        "tune": 1, "update-filled": 1, "update": 1, "volume-off": 1,
        "volume": 1, "warning": 1, "widgets": 1, "wifi-0": 1, "wifi-1": 1,
        "wifi-2": 1, "wifi-off": 1, "wifi": 1, "window-filled": 1, "window": 1,
        "x": 1
    })
}
