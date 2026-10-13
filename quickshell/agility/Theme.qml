pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    visible: false

    // Active theme key
    property string currentTheme: "liquid_glass"

    // Widget visibility states (managed directly by Agility Shell)
    property bool isLoaded: false
    property var widgetVisibility: ({})

    // D-Bus Theme Tokens from org.agility.Daemon.Theme
    property var dbusTokens: ({
        "is_dark": true,
        "primary_color": "#2a98df",
        "secondary_color": "#8392a3",
        "surface_color": "#181c20",
        "background_color": "#0f1113",
        "accent_colors": ["#2a98df", "#50b2fc", "#94ccff", "#d2bfe7"],
        "active_wallpaper": "",
        "border_radius": 16,
        "font_family": "Inter",
        "font_mono": "JetBrains Mono",
        "active_preset": "liquid_glass"
    })

    function isWidgetVisible(key) {
        return root.isLoaded && (root.widgetVisibility[key] === true)
    }

    // Theme metadata list for UI pickers
    readonly property var themes: [
        { id: "liquid_glass",    name: "Liquid Glass", icon: "🫧", desc: "Translucent water droplet glass with curved meniscus sheen" },
        { id: "aurora_prism",    name: "Aurora Prism", icon: "💎", desc: "Crystal glass with iridescent aurora reflections" },
        { id: "evergreen_moss",  name: "Evergreen",    icon: "🌲", desc: "Translucent forest green with phosphor telemetry" },
        { id: "nordic",          name: "Nordic Frost", icon: "❄️", desc: "Arctic cold blue & snow storm palette" },
        { id: "tokyo_night",     name: "Tokyo Night",  icon: "🌸", desc: "Midnight indigo-violet with lavender & cyan" },
        { id: "oled",            name: "OLED Black",   icon: "🖤", desc: "100% pitch-black with crisp white typography" },
        { id: "material",        name: "Material 3",   icon: "🎨", desc: "Adaptive dynamic color scheme from wallpaper" },
        { id: "transparent",     name: "Transparent",  icon: "🪟", desc: "Minimal see-through floating aesthetic" },
        { id: "cyberpunk",       name: "Cyberpunk",    icon: "⚡", desc: "High-contrast neon glow on obsidian" },
        { id: "warm_latte",      name: "Warm Latte",   icon: "☕", desc: "Cozy espresso & caramel with warm amber" }
    ]

    // Convenience booleans
    readonly property bool isGlass: currentTheme === "liquid_glass" || currentTheme === "evergreen_moss" || currentTheme === "aurora_prism"
    readonly property bool isTransparent: currentTheme === "transparent"
    readonly property bool isMaterial: currentTheme === "material"
    readonly property bool isCyberpunk: currentTheme === "cyberpunk"
    readonly property bool isNordic: currentTheme === "nordic"
    readonly property bool isOled: currentTheme === "oled"
    readonly property bool isLatte: currentTheme === "warm_latte"
    readonly property bool isTokyo: currentTheme === "tokyo_night"
    readonly property bool isEvergreen: currentTheme === "evergreen_moss"
    readonly property bool isAurora: currentTheme === "aurora_prism"

    // Fonts
    readonly property string fontMain: (dbusTokens.font_family ? dbusTokens.font_family + ", " : "") + "Inter, sans-serif"
    readonly property string fontMono: (dbusTokens.font_mono ? dbusTokens.font_mono + ", " : "") + "JetBrains Mono, monospace"

    // ─── Dynamic Palette Properties ───
    // Primary Panel Background
    readonly property color colBg: {
        if (root.isMaterial && dbusTokens.background_color) return dbusTokens.background_color
        switch (currentTheme) {
            case "liquid_glass":   return "#550A1118"
            case "transparent":    return "#260B0E14"
            case "cyberpunk":      return "#0A0B10"
            case "nordic":         return "#2E3440"
            case "oled":           return "#000000"
            case "warm_latte":     return "#1E1A16"
            case "tokyo_night":    return "#1A1B26"
            case "evergreen_moss": return "#8A0C1A12"
            case "aurora_prism":   return "#78161826"
            case "material":
            default:               return "#232D33"
        }
    }

    // Inner Sub-Card / Tile Background
    readonly property color colBgTile: {
        if (root.isMaterial && dbusTokens.surface_color) return dbusTokens.surface_color
        switch (currentTheme) {
            case "liquid_glass":   return "#38141F2E"
            case "transparent":    return "#33141C26"
            case "cyberpunk":      return "#121420"
            case "nordic":         return "#3B4252"
            case "oled":           return "#0D0D0D"
            case "warm_latte":     return "#2D251E"
            case "tokyo_night":    return "#24283B"
            case "evergreen_moss": return "#99112419"
            case "aurora_prism":   return "#8C1E2033"
            case "material":
            default:               return "#3A454B"
        }
    }

    // Pill / Button / Badge Background
    readonly property color colPillBg: {
        if (root.isMaterial && dbusTokens.surface_container) return dbusTokens.surface_container
        switch (currentTheme) {
            case "liquid_glass":   return "#2D203045"
            case "transparent":    return "#4D212C3B"
            case "cyberpunk":      return "#1D2032"
            case "nordic":         return "#434C5E"
            case "oled":           return "#1A1A1A"
            case "warm_latte":     return "#3D3228"
            case "tokyo_night":    return "#2F354F"
            case "evergreen_moss": return "#A6183324"
            case "aurora_prism":   return "#992B2E48"
            case "material":
            default:               return "#303B42"
        }
    }

    // Main Accent Color
    readonly property color colAccent: {
        if (root.isMaterial && dbusTokens.primary_color) return dbusTokens.primary_color
        switch (currentTheme) {
            case "liquid_glass":   return "#7DD3FC"
            case "transparent":    return "#38BDF8"
            case "cyberpunk":      return "#00FFE0"
            case "nordic":         return "#88C0D0"
            case "oled":           return "#FFFFFF"
            case "warm_latte":     return "#F59E0B"
            case "tokyo_night":    return "#7AA2F7"
            case "evergreen_moss": return "#22C55E"
            case "aurora_prism":   return "#E879F9"
            case "material":
            default:               return "#C2E7FF"
        }
    }

    // Secondary / Positive Accent (Green)
    readonly property color colAccentGreen: {
        switch (currentTheme) {
            case "liquid_glass":   return "#34D399"
            case "transparent":    return "#4ADE80"
            case "cyberpunk":      return "#39FF14"
            case "nordic":         return "#A3BE8C"
            case "oled":           return "#4ADE80"
            case "warm_latte":     return "#84CC16"
            case "tokyo_night":    return "#73DACA"
            case "evergreen_moss": return "#86EFAC"
            case "aurora_prism":   return "#34D399"
            case "material":
            default:               return "#A2C9C2"
        }
    }

    // Warm / Alert Accent
    readonly property color colAccentWarm: {
        switch (currentTheme) {
            case "liquid_glass":   return "#FB7185"
            case "transparent":    return "#F43F5E"
            case "cyberpunk":      return "#FF007F"
            case "nordic":         return "#BF616A"
            case "oled":           return "#F87171"
            case "warm_latte":     return "#E07A5F"
            case "tokyo_night":    return "#F7768E"
            case "evergreen_moss": return "#FB923C"
            case "aurora_prism":   return "#FB7185"
            case "material":
            default:               return "#FFB4AB"
        }
    }

    // Warning / Yellow Accent
    readonly property color colAccentWarning: {
        switch (currentTheme) {
            case "liquid_glass":   return "#FCD34D"
            case "transparent":    return "#FBBF24"
            case "cyberpunk":      return "#FFE600"
            case "nordic":         return "#EBCB8B"
            case "oled":           return "#FBBF24"
            case "warm_latte":     return "#FBBF24"
            case "tokyo_night":    return "#E0AF68"
            case "evergreen_moss": return "#FACC15"
            case "aurora_prism":   return "#38BDF8"
            case "material":
            default:               return "#FFD54F"
        }
    }

    // Primary Text Color
    readonly property color colTextPrimary: {
        if (root.isMaterial && dbusTokens.on_surface) return dbusTokens.on_surface
        switch (currentTheme) {
            case "nordic":         return "#ECEFF4"
            case "warm_latte":     return "#FDF8F5"
            case "tokyo_night":    return "#C0CAF5"
            case "evergreen_moss": return "#ECFDF5"
            case "aurora_prism":   return "#F5F3FF"
            default:               return "#FFFFFF"
        }
    }

    // Secondary Text Color
    readonly property color colTextSecondary: {
        if (root.isMaterial && dbusTokens.secondary_color) return dbusTokens.secondary_color
        switch (currentTheme) {
            case "liquid_glass":   return "#B0C4D4"
            case "transparent":    return "#94A3B8"
            case "cyberpunk":      return "#8894B8"
            case "nordic":         return "#D8DEE9"
            case "oled":           return "#A3A3A3"
            case "warm_latte":     return "#C4B5A5"
            case "tokyo_night":    return "#7982A9"
            case "evergreen_moss": return "#86EFAC"
            case "aurora_prism":   return "#C4B5FD"
            case "material":
            default:               return "#9CA8AC"
        }
    }

    // Aliases for unified text references
    readonly property color colText: colTextPrimary
    readonly property color colTextSec: colTextSecondary

    // Border Color (Ultra-subtle, non-harsh)
    readonly property color borderColor: {
        if (root.isMaterial && dbusTokens.outline) return dbusTokens.outline
        switch (currentTheme) {
            case "liquid_glass":   return "#28FFFFFF"
            case "transparent":    return "#1AFFFFFF"
            case "cyberpunk":      return "#6600FFE0"
            case "nordic":         return "#26D8DEE9"
            case "oled":           return "#333333"
            case "warm_latte":     return "#33F59E0B"
            case "tokyo_night":    return "#38BB9AF7"
            case "evergreen_moss": return "#4D22C55E"
            case "aurora_prism":   return "#5CE879F9"
            case "material":
            default:               return "#24FFFFFF"
        }
    }

    // Border Width
    readonly property real borderWidth: {
        switch (currentTheme) {
            case "liquid_glass":   return 1.0
            case "cyberpunk":      return 1.5
            case "aurora_prism":   return 1.2
            case "evergreen_moss": return 1.2
            case "tokyo_night":    return 1.2
            case "transparent":    return 1.0
            default:               return 1.0
        }
    }

    // ─── Settings Persistence & Animations ───
    property var allSettings: ({})
    property int reloadVersion: 0
    property bool isSwitching: false
    signal settingsUpdated()

    Timer {
        id: switchAnimTimer
        interval: 650
        repeat: false
        onTriggered: {
            root.isSwitching = false
        }
    }

    function triggerPresetSwitch() {
        root.isSwitching = true
        switchAnimTimer.restart()
    }

    function reloadSettings() {
        root.triggerPresetSwitch()
        if (!loadSettingsProc.running) {
            loadSettingsProc.running = true
        }
        if (!loadTokensProc.running) {
            loadTokensProc.running = true
        }
    }

    function applyWidgetConfig(widget, key) {
        if (!widget || !key || !root.allSettings || !root.allSettings[key]) return
        var cfg = root.allSettings[key]
        if (cfg.scale !== undefined && widget.scaleFactor !== undefined) {
            widget.scaleFactor = Math.max(0.5, Math.min(2.5, cfg.scale))
        }
        var targetW = widget.width
        var targetH = widget.height
        if (cfg.x !== undefined) {
            var newX = Math.max(10, Math.min(widget.screenWidth - targetW - 10, cfg.x))
            widget.x = newX
            if (widget.posX !== undefined) widget.posX = newX
        }
        if (cfg.y !== undefined) {
            var newY = Math.max(10, Math.min(widget.screenHeight - targetH - 10, cfg.y))
            widget.y = newY
            if (widget.posY !== undefined) widget.posY = newY
        }
    }

    // ─── Fast D-Bus & Cache Loader ───
    Process {
        id: loadTokensProc
        command: ["sh", "-c", "cat ~/.cache/agility-shell/theme.json 2>/dev/null || busctl --user call org.agility.Daemon /org/agility/Daemon/Theme org.agility.Daemon.Theme GetTheme 2>/dev/null | sed 's/^[s ]*\"//;s/\"$//' || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text)
                    if (parsed && typeof parsed === "object") {
                        root.dbusTokens = parsed
                        if (parsed.active_preset && parsed.active_preset !== "") {
                            // Map daemon preset if custom was set
                            var pLower = parsed.active_preset.toLowerCase()
                            for (var i = 0; i < root.themes.length; i++) {
                                if (root.themes[i].id.toLowerCase() === pLower) {
                                    root.currentTheme = root.themes[i].id
                                    break
                                }
                            }
                        }
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/agility-shell/widget_settings.json 2>/dev/null || cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(text)
                    root.allSettings = data
                    if (data.manager) {
                        if (data.manager.theme) {
                            root.currentTheme = data.manager.theme
                        }
                        if (data.manager.visibility !== undefined && typeof data.manager.visibility === "object") {
                            root.widgetVisibility = Object.assign({}, data.manager.visibility)
                        }
                    }
                    root.isLoaded = true
                    root.reloadVersion += 1
                    root.settingsUpdated()
                } catch (e) {}
            }
        }
    }

    Process {
        id: saveSettingsProc
        running: false
    }

    function saveWidgetConfig(widgetName, configObj) {
        if (!widgetName || !configObj) return
        var cfgStr = JSON.stringify(configObj).replace(/'/g, "'\\''")
        var shCmd = "mkdir -p ~/.config/agility-shell && " +
            "jq '." + widgetName + " = " + JSON.stringify(configObj) + "' ~/.config/agility-shell/widget_settings.json > ~/.config/agility-shell/widget_settings.json.tmp 2>/dev/null && " +
            "mv ~/.config/agility-shell/widget_settings.json.tmp ~/.config/agility-shell/widget_settings.json"
        saveSettingsProc.command = ["sh", "-c", shCmd]
        saveSettingsProc.running = true
    }

    function setTheme(newTheme) {
        root.currentTheme = newTheme
        // Notify agilityd via D-Bus and persist in widget settings
        var notifyDbus = "busctl --user call org.agility.Daemon /org/agility/Daemon/Theme org.agility.Daemon.Theme SetPreset s \"" + newTheme + "\" 2>/dev/null || true; " +
            "mkdir -p ~/.config/agility-shell && " +
            "if [ -f ~/.config/agility-shell/widget_settings.json ]; then " +
            "  jq '.manager.theme = \"" + newTheme + "\"' ~/.config/agility-shell/widget_settings.json > ~/.config/agility-shell/widget_settings.json.tmp && " +
            "  mv ~/.config/agility-shell/widget_settings.json.tmp ~/.config/agility-shell/widget_settings.json; " +
            "fi"
        saveSettingsProc.command = ["sh", "-c", notifyDbus]
        saveSettingsProc.running = true
    }

    function setWidgetVisibility(widgetName, isVisible) {
        var vis = Object.assign({}, root.widgetVisibility)
        vis[widgetName] = isVisible
        root.widgetVisibility = vis

        var jsonStr = JSON.stringify(vis).replace(/'/g, "'\\''")
        var shCmd = "mkdir -p ~/.config/agility-shell && " +
            "if [ -f ~/.config/agility-shell/widget_settings.json ]; then " +
            "  jq '.manager.visibility = " + jsonStr + "' ~/.config/agility-shell/widget_settings.json > ~/.config/agility-shell/widget_settings.json.tmp && " +
            "  mv ~/.config/agility-shell/widget_settings.json.tmp ~/.config/agility-shell/widget_settings.json; " +
            "fi"
        saveSettingsProc.command = ["sh", "-c", shCmd]
        saveSettingsProc.running = true
    }

    // Watcher keeping theme & visibility synced with daemon
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            if (!loadSettingsProc.running && !saveSettingsProc.running && !root.isSwitching) {
                loadSettingsProc.running = true
                loadTokensProc.running = true
            }
        }
    }

    Component.onCompleted: {
        loadSettingsProc.running = true
        loadTokensProc.running = true
    }
}
