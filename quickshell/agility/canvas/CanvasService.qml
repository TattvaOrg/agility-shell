pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components" as Components

Item {
    id: root

    // ─── Edit Mode State ───
    property bool editModeActive: false
    property string selectedWidget: ""
    property int gridSize: 20
    property bool snapToGrid: true

    // Active widget placement metadata list
    property var widgetCatalog: [
        { "id": "clock", "name": "Clock & Time", "icon": "clock" },
        { "id": "sysinfo", "name": "System Info", "icon": "cpu" },
        { "id": "resourcewheel", "name": "Resource Gauges", "icon": "chart-pie-slice" },
        { "id": "calendar", "name": "Calendar", "icon": "calendar" },
        { "id": "weather", "name": "Weather", "icon": "cloud-sun" },
        { "id": "media", "name": "Media Player", "icon": "music-notes" },
        { "id": "visualizer", "name": "Audio Visualizer", "icon": "waveform" },
        { "id": "notes", "name": "Sticky Notes", "icon": "note-pencil" },
        { "id": "todo", "name": "Tasks & Todo", "icon": "check-square" },
        { "id": "habits", "name": "Habits Matrix", "icon": "grid-four" },
        { "id": "git", "name": "Git Dashboard", "icon": "git-branch" },
        { "id": "calc", "name": "Calculator", "icon": "calculator" },
        { "id": "timer", "name": "Timer & Stopwatch", "icon": "timer" },
        { "id": "thermal", "name": "Thermals", "icon": "thermometer" },
        { "id": "storagemap", "name": "Storage Map", "icon": "hard-drives" },
        { "id": "battery", "name": "Battery", "icon": "battery-charging" },
        { "id": "network", "name": "Network", "icon": "wifi-high" },
        { "id": "ping", "name": "Ping Latency", "icon": "pulse" },
        { "id": "crypto", "name": "Crypto Ticker", "icon": "currency-btc" },
        { "id": "worldclock", "name": "World Clocks", "icon": "globe" },
        { "id": "quote", "name": "Inspirational Quote", "icon": "chat-centered-text" },
        { "id": "poster", "name": "Poster Card", "icon": "image" },
        { "id": "clipboard", "name": "Clipboard History", "icon": "clipboard" },
        { "id": "quickcontrols", "name": "Quick Controls", "icon": "sliders" }
    ]

    function toggleEditMode() {
        root.editModeActive = !root.editModeActive
        if (!root.editModeActive) {
            root.selectedWidget = ""
        }
    }

    function enterEditMode() {
        root.editModeActive = true
    }

    function exitEditMode() {
        root.editModeActive = false
        root.selectedWidget = ""
    }

    function selectWidget(id) {
        root.selectedWidget = id
    }

    function snap(val) {
        if (!root.snapToGrid) return Math.round(val)
        return Math.round(val / root.gridSize) * root.gridSize
    }

    function savePlacement(widgetKey, posX, posY, scaleFactor) {
        if (!widgetKey) return

        var existing = (Theme.allSettings && Theme.allSettings[widgetKey]) ? Theme.allSettings[widgetKey] : {}
        var updated = Object.assign({}, existing, {
            "x": Math.round(posX),
            "y": Math.round(posY),
            "scale": (scaleFactor !== undefined) ? parseFloat(scaleFactor.toFixed(2)) : (existing.scale || 1.0)
        })

        Theme.saveWidgetConfig(widgetKey, updated)
        Components.SoundService.play("widget-placed")
    }

    function toggleWidgetVisibility(widgetKey) {
        if (!widgetKey) return
        var currentVis = Theme.isWidgetVisible(widgetKey)
        var newVis = !currentVis

        // Update Theme local map
        if (!Theme.widgetVisibility) Theme.widgetVisibility = {}
        Theme.widgetVisibility[widgetKey] = newVis
        Theme.settingsUpdated()

        if (newVis) {
            Components.SoundService.play("widget-placed")
        } else {
            Components.SoundService.play("widget-removed")
        }

        // Persist to widget_settings.json
        var shCmd = "mkdir -p ~/.config/agility-shell && " +
            "jq '.manager.visibility." + widgetKey + " = " + (newVis ? "true" : "false") + "' ~/.config/agility-shell/widget_settings.json > ~/.config/agility-shell/widget_settings.json.tmp 2>/dev/null && " +
            "mv ~/.config/agility-shell/widget_settings.json.tmp ~/.config/agility-shell/widget_settings.json 2>/dev/null || true"
        runCmd(shCmd)
    }

    function resetWidgetPosition(widgetKey, screenW, screenH) {
        var defaultX = Math.round((screenW - 300) / 2)
        var defaultY = Math.round((screenH - 200) / 2)
        savePlacement(widgetKey, defaultX, defaultY, 1.0)
        Theme.reloadSettings()
    }

    // ─── Process Runner ───
    Process {
        id: execProc
        running: false
    }

    function runCmd(cmd) {
        execProc.command = ["sh", "-c", cmd]
        execProc.running = true
    }
}
