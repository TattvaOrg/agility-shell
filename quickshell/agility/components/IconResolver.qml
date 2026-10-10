pragma Singleton
import QtQuick

Item {
    id: root

    // Base directory for duotone SVG assets
    readonly property string svgsDir: Qt.resolvedUrl("../../../svgs")

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
        "clipboard": "clipboard-text-duotone.svg"
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

        // Try duotone suffix
        var duotoneFile = normalized + "-duotone.svg"
        return root.svgsDir + "/" + duotoneFile
    }
}
