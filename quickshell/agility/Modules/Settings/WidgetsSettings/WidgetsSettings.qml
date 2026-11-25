import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Settings.Components
import qs.Modules.DesktopWidgets as DesktopWidgets

AppContainer {
    id: widgetsSettingsRoot

    // ─── Settings Store & Reactive State ───
    property var settingsData: ({})
    property var widgetVisibility: ({
        "clock": true,
        "poster": true,
        "calendar": true,
        "media": true,
        "sysinfo": true,
        "battery": true,
        "weather": true,
        "quickcontrols": true,
        "network": true,
        "notes": true,
        "todo": true,
        "timer": true,
        "thermal": true,
        "quote": true,
        "clipboard": true,
        "crypto": true,
        "worldclock": true,
        "git": true,
        "resourcewheel": true,
        "visualizer": true,
        "habits": true,
        "ping": true,
        "storagemap": true,
        "calc": true
    })
    property string currentTheme: "liquid_glass"
    property real globalScaleValue: 0.85
    property string pillPosition: "top_center"
    property string pillText: "Awe Widgets"
    property bool showPill: true
    property string searchQuery: ""
    property string selectedCategory: "All"

    readonly property var allCategories: ["All", "Core", "Media", "System", "Network", "Productivity"]

    readonly property var allWidgets: [
        { id: "clock",         name: "Clock",               icon: "clock",          cat: "Core",         desc: "Cookie, Nothing OS, Android stacked & digital clock styles" },
        { id: "poster",        name: "Poster / Photo",      icon: "image",          cat: "Media",        desc: "Organic photo frame (Arch, Scallop, Pebble) with GIF support" },
        { id: "calendar",      name: "Calendar",            icon: "calendar",       cat: "Core",         desc: "Interactive monthly calendar with day selector" },
        { id: "media",         name: "Media Player",        icon: "music",          cat: "Media",        desc: "MPRIS controller with fluid seekbar and soundwave bars" },
        { id: "sysinfo",       name: "System Info",         icon: "cpu",            cat: "System",       desc: "CPU load, RAM utilization and disk capacity overview" },
        { id: "battery",       name: "Battery Status",      icon: "battery",        cat: "System",       desc: "Battery percentage, AC adapter status, and power metrics" },
        { id: "weather",       name: "Live Weather",        icon: "cloud",          cat: "Network",      desc: "Current temperature, sky conditions and forecast" },
        { id: "quickcontrols", name: "Volume & Brightness", icon: "volume",         cat: "System",       desc: "PipeWire volume pill and display backlight sliders" },
        { id: "network",       name: "Network Telemetry",   icon: "wifi",           cat: "Network",      desc: "Wi-Fi SSID, bandwidth sparklines and IP privacy" },
        { id: "notes",         name: "Quick Notes",         icon: "edit",           cat: "Productivity", desc: "Material notepad with instant inline editing and debounced autosave" },
        { id: "todo",          name: "Tasks / Checklist",   icon: "check-square",   cat: "Productivity", desc: "Interactive task list with progress bar and completion tracker" },
        { id: "timer",         name: "Pomodoro Timer",      icon: "timer",          cat: "Productivity", desc: "Focus countdown, break intervals and stopwatch mode" },
        { id: "thermal",       name: "Hardware Thermals",   icon: "thermometer",    cat: "System",       desc: "CPU package & core temperatures via lm_sensors" },
        { id: "quote",         name: "Daily Inspiration",   icon: "quote",          cat: "Media",        desc: "Rotating motivational quotes with author tags and refresh shuffle" },
        { id: "clipboard",     name: "Clipboard History",   icon: "clipboard",      cat: "Productivity", desc: "Real-time clipboard monitor using wl-paste with one-click copy" },
        { id: "crypto",        name: "Crypto Ticker",       icon: "trending",       cat: "Network",      desc: "Live market rates for Bitcoin, Ethereum, Solana with trend pills" },
        { id: "worldclock",    name: "World Clock",         icon: "globe",          cat: "Core",         desc: "Multi-city timezone hub with solar day/night indicators" },
        { id: "git",           name: "Git Dashboard",       icon: "git",            cat: "Productivity", desc: "Repository monitor showing branch, uncommitted diffs and commit message" },
        { id: "resourcewheel", name: "Resource Wheel",      icon: "activity",       cat: "System",       desc: "4 concentric circular progress arcs for CPU, RAM, Disk, Thermals" },
        { id: "visualizer",    name: "Audio Visualizer",    icon: "waveform",       cat: "Media",        desc: "Desktop spectrum equalizer, fluid sine wave, and radial soundwave" },
        { id: "habits",        name: "Habit Tracker",       icon: "calendar-check", cat: "Productivity", desc: "7-day streak tracker with daily interactive check matrix" },
        { id: "ping",          name: "Network Ping",        icon: "activity",       cat: "Network",      desc: "Live latency monitor pinging Cloudflare, Google, GitHub" },
        { id: "storagemap",    name: "Storage Map",         icon: "disc",           cat: "System",       desc: "Segmented disk partition visualizer with Root capacity usage" },
        { id: "calc",          name: "Calculator",          icon: "calculator",     cat: "Core",         desc: "Floating calculator with live expression evaluation" }
    ]

    readonly property var allThemes: [
        { id: "system",         name: "System Dynamic", icon: "crosshair",  desc: "Material 3 palette extracted from wallpaper", bg: "#221A14", tile: "#261E18", acc: "#FFB77E" },
        { id: "liquid_glass",   name: "Liquid Glass",   icon: "droplet",    desc: "Translucent frosted glass with specular gloss", bg: "#141B24", tile: "#1B2430", acc: "#7DD3FC" },
        { id: "transparent",    name: "Transparent",    icon: "layout",     desc: "Minimal see-through floating aesthetic",        bg: "#0B0E14", tile: "#141C26", acc: "#38BDF8" },
        { id: "material",       name: "Material 3",     icon: "palette",    desc: "Original dark slate with Pixel cyan",          bg: "#232D33", tile: "#3A454B", acc: "#C2E7FF" },
        { id: "cyberpunk",      name: "Cyberpunk",      icon: "zap",        desc: "High-contrast neon glow on obsidian",          bg: "#0A0B10", tile: "#121420", acc: "#00FFE0" },
        { id: "nordic",         name: "Nordic Frost",   icon: "snowflake",  desc: "Arctic cold blue & snow storm palette",        bg: "#2E3440", tile: "#3B4252", acc: "#88C0D0" },
        { id: "oled",           name: "OLED Black",     icon: "moon",       desc: "100% pitch-black with crisp white typography",  bg: "#000000", tile: "#0D0D0D", acc: "#FFFFFF" },
        { id: "warm_latte",     name: "Warm Latte",     icon: "coffee",     desc: "Cozy espresso & caramel with warm amber",       bg: "#1E1A16", tile: "#2D251E", acc: "#F59E0B" },
        { id: "tokyo_night",    name: "Tokyo Night",    icon: "sparkles",   desc: "Midnight indigo-violet with lavender & cyan",   bg: "#1A1B26", tile: "#24283B", acc: "#7AA2F7" },
        { id: "evergreen_moss", name: "Evergreen",      icon: "feather",    desc: "Translucent forest green with phosphor telemetry", bg: "#0C1A12", tile: "#112419", acc: "#22C55E" },
        { id: "aurora_prism",   name: "Aurora Prism",   icon: "gem",        desc: "Crystal glass with iridescent aurora reflections", bg: "#161826", tile: "#1E2033", acc: "#E879F9" }
    ]

    // ─── Settings Persistence Process Handlers ───
    Process {
        id: loadSettingsProc
        command: ["sh", "-c", "cat ~/.config/quickshell/widget_settings.json 2>/dev/null || echo '{}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(text);
                    widgetsSettingsRoot.settingsData = data;
                    if (data.manager) {
                        if (data.manager.visibility !== undefined) {
                            let rawVis = data.manager.visibility;
                            if (rawVis.visibility !== undefined) rawVis = rawVis.visibility;
                            widgetsSettingsRoot.widgetVisibility = Object.assign({}, widgetsSettingsRoot.widgetVisibility, rawVis);
                        }
                        if (data.manager.position !== undefined) {
                            widgetsSettingsRoot.pillPosition = data.manager.position;
                        }
                        if (data.manager.pillText !== undefined && data.manager.pillText !== "") {
                            widgetsSettingsRoot.pillText = data.manager.pillText;
                        }
                        if (data.manager.showPill !== undefined) {
                            widgetsSettingsRoot.showPill = data.manager.showPill;
                        }
                        if (data.manager.theme !== undefined) {
                            widgetsSettingsRoot.currentTheme = data.manager.theme;
                        }
                    }
                    if (data.clock && data.clock.scale !== undefined) {
                        widgetsSettingsRoot.globalScaleValue = data.clock.scale;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: saveSettingsProc
        running: false
    }

    Timer {
        id: saveDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            let visJson = JSON.stringify(widgetsSettingsRoot.widgetVisibility);
            let posStr = JSON.stringify(widgetsSettingsRoot.pillPosition);
            let textStr = JSON.stringify(widgetsSettingsRoot.pillText);
            let themeStr = JSON.stringify(widgetsSettingsRoot.currentTheme);
            let showStr = widgetsSettingsRoot.showPill ? "True" : "False";
            let pyScript = "import json, os; p=os.path.expanduser('~/.config/quickshell/widget_settings.json'); os.makedirs(os.path.dirname(p), exist_ok=True); d=json.load(open(p)) if os.path.exists(p) else {}; m=d.setdefault('manager', {}); m['visibility']=json.loads(" + JSON.stringify(visJson) + "); m['position']=" + posStr + "; m['pillText']=" + textStr + "; m['theme']=" + themeStr + "; m['showPill']=" + showStr + "; open(p,'w').write(json.dumps(d,indent=2))";
            saveSettingsProc.command = ["python3", "-c", pyScript];
            saveSettingsProc.running = true;
        }
    }

    function toggleWidget(widgetId) {
        let vis = Object.assign({}, widgetsSettingsRoot.widgetVisibility);
        vis[widgetId] = (vis[widgetId] === false) ? true : false;
        widgetsSettingsRoot.widgetVisibility = vis;
        saveDebounceTimer.restart();
    }

    function setAllWidgets(enable) {
        let vis = {};
        for (let i = 0; i < allWidgets.length; i++) {
            vis[allWidgets[i].id] = enable;
        }
        widgetsSettingsRoot.widgetVisibility = vis;
        saveDebounceTimer.restart();
    }

    function setTheme(newTheme) {
        widgetsSettingsRoot.currentTheme = newTheme;
        DesktopWidgets.Theme.setTheme(newTheme);
        saveDebounceTimer.restart();
    }

    function setPillPosition(pos) {
        widgetsSettingsRoot.pillPosition = pos;
        saveDebounceTimer.restart();
    }

    function setPillVisibility(show) {
        widgetsSettingsRoot.showPill = show;
        saveDebounceTimer.restart();
    }

    function setPillText(textVal) {
        widgetsSettingsRoot.pillText = textVal;
        saveDebounceTimer.restart();
    }

    function applyGlobalScale(scaleVal) {
        widgetsSettingsRoot.globalScaleValue = scaleVal;
        let script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); os.makedirs(os.path.dirname(p), exist_ok=True); d=json.load(open(p)) if os.path.exists(p) else {}; widgets=[\"clock\",\"poster\",\"calendar\",\"media\",\"sysinfo\",\"battery\",\"weather\",\"quickcontrols\",\"network\",\"notes\",\"todo\",\"timer\",\"thermal\",\"quote\",\"clipboard\",\"crypto\",\"worldclock\",\"git\",\"resourcewheel\",\"visualizer\",\"habits\",\"ping\",\"storagemap\",\"calc\"]; [d.setdefault(w, {}).update({\"scale\": round(" + scaleVal + ", 2)}) for w in widgets]; open(p,\"w\").write(json.dumps(d,indent=2))'";
        saveSettingsProc.command = ["sh", "-c", script];
        saveSettingsProc.running = true;
    }

    function resetLayoutPositions() {
        let script = "python3 -c 'import json, os; p=os.path.expanduser(\"~/.config/quickshell/widget_settings.json\"); os.makedirs(os.path.dirname(p), exist_ok=True); d=json.load(open(p)) if os.path.exists(p) else {}; pos={\"poster\":(30,30),\"calendar\":(30,230),\"visualizer\":(30,460),\"media\":(30,620),\"clipboard\":(30,800),\"sysinfo\":(400,30),\"thermal\":(400,160),\"timer\":(640,160),\"quote\":(400,370),\"todo\":(400,520),\"notes\":(660,520),\"git\":(400,730),\"habits\":(660,730),\"resourcewheel\":(400,890),\"storagemap\":(660,890),\"clock\":(1120,40),\"battery\":(1120,300),\"weather\":(1120,430),\"network\":(1120,580),\"ping\":(1120,730),\"quickcontrols\":(1120,880),\"calc\":(1400,40),\"crypto\":(1400,330),\"worldclock\":(1400,500)}; [d.setdefault(k, {}).update({\"x\": v[0], \"y\": v[1]}) for k, v in pos.items()]; open(p,\"w\").write(json.dumps(d,indent=2))'";
        saveSettingsProc.command = ["sh", "-c", script];
        saveSettingsProc.running = true;
        loadSettingsProc.running = true;
    }

    function applyPresetLayout(presetName) {
        let script = "";
        if (presetName === "minimal") {
            let vis = {};
            for (let i = 0; i < allWidgets.length; i++) {
                vis[allWidgets[i].id] = (allWidgets[i].id === "clock" || allWidgets[i].id === "weather" || allWidgets[i].id === "media");
            }
            widgetsSettingsRoot.widgetVisibility = vis;
            saveDebounceTimer.restart();
        } else if (presetName === "productivity") {
            let vis = {};
            for (let i = 0; i < allWidgets.length; i++) {
                let id = allWidgets[i].id;
                vis[id] = (id === "clock" || id === "notes" || id === "todo" || id === "timer" || id === "habits" || id === "git" || id === "calc" || id === "clipboard");
            }
            widgetsSettingsRoot.widgetVisibility = vis;
            saveDebounceTimer.restart();
        } else if (presetName === "telemetry") {
            let vis = {};
            for (let i = 0; i < allWidgets.length; i++) {
                let id = allWidgets[i].id;
                vis[id] = (id === "resourcewheel" || id === "sysinfo" || id === "thermal" || id === "network" || id === "ping" || id === "storagemap" || id === "battery");
            }
            widgetsSettingsRoot.widgetVisibility = vis;
            saveDebounceTimer.restart();
        } else {
            resetLayoutPositions();
            setAllWidgets(true);
        }
    }

    Component.onCompleted: {
        loadSettingsProc.running = true;
    }

    // ─── Section 1: Master Controls & Desktop Integration ───
    AppGroup {
        title: "Desktop Widgets Master Configuration"
        icon: "widgets"
        badge: SettingsService.desktopWidgetsEnabled ? "Active" : "Disabled"

        SettingToggle {
            label: "Enable Desktop Widgets"
            description: "Render interactive floating widgets with draggable placement directly on the desktop"
            checked: SettingsService.desktopWidgetsEnabled
            onToggled: (val) => {
                SettingsService.desktopWidgetsEnabled = val;
                SettingsService.saveSettings();
            }
        }

        SettingToggle {
            label: "Floating Widget Manager Notch"
            description: "Display a floating desktop notch / pill to toggle widgets and access status on the fly"
            checked: widgetsSettingsRoot.showPill && SettingsService.widgetManagerNotchEnabled
            onToggled: (val) => {
                widgetsSettingsRoot.setPillVisibility(val);
                SettingsService.widgetManagerNotchEnabled = val;
                SettingsService.saveSettings();
            }
        }

        SettingSegmented {
            label: "Notch Screen Position"
            description: "Anchor position of the floating manager notch on your primary desktop"
            model: [
                { "text": "Top Center", "value": "top_center" },
                { "text": "Top Left", "value": "top_left" },
                { "text": "Top Right", "value": "top_right" },
                { "text": "Bottom Center", "value": "bottom_center" }
            ]
            currentValue: widgetsSettingsRoot.pillPosition
            onActivated: (val) => widgetsSettingsRoot.setPillPosition(val)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            RowLayout {
                Layout.fillWidth: true
                ThemedText {
                    text: "Master Widget Scaling"
                    customSize: Constants.sizeSm
                    font.weight: Font.Medium
                    color: Theme.fg
                    Layout.fillWidth: true
                }
                ThemedText {
                    text: Math.round(widgetsSettingsRoot.globalScaleValue * 100) + "%"
                    customSize: Constants.sizeSm
                    font.weight: Font.Bold
                    color: Theme.accent
                }
            }

            ThemedSlider {
                Layout.fillWidth: true
                from: 0.50
                to: 1.50
                stepSize: 0.05
                value: widgetsSettingsRoot.globalScaleValue
                onValueChanged: {
                    if (Math.abs(widgetsSettingsRoot.globalScaleValue - value) > 0.01) {
                        widgetsSettingsRoot.applyGlobalScale(value);
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                Repeater {
                    model: [
                        { "label": "Compact (75%)", "val": 0.75 },
                        { "label": "Standard (85%)", "val": 0.85 },
                        { "label": "Native (100%)", "val": 1.00 },
                        { "label": "Large (115%)", "val": 1.15 }
                    ]

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        radius: Constants.sizeXs
                        property bool isCurrent: Math.abs(widgetsSettingsRoot.globalScaleValue - modelData.val) < 0.04
                        color: isCurrent ? Theme.bgAccent : Theme.bgSecondary
                        border.width: 1
                        border.color: isCurrent ? Theme.accent : Theme.border

                        ThemedText {
                            anchors.centerIn: parent
                            text: modelData.label
                            customSize: 11
                            font.weight: parent.isCurrent ? Font.Bold : Font.Normal
                            color: parent.isCurrent ? Theme.accent : Theme.muted
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: widgetsSettingsRoot.applyGlobalScale(modelData.val)
                        }
                    }
                }
            }
        }
    }

    // ─── Section 2: Visual Themes Engine ───
    AppGroup {
        title: "Widget Visual Themes (11 Presets)"
        icon: "color-palette"
        badge: widgetsSettingsRoot.currentTheme.replace("_", " ").toUpperCase()

        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: widgetsSettingsRoot.allThemes

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: widgetsSettingsRoot.currentTheme === modelData.id

                    width: 125
                    height: 56
                    radius: Constants.sizeMd
                    color: modelData.bg
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Theme.accent : Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                font.pixelSize: 10
                                font.weight: Font.Bold
                                color: isSelected ? Theme.accent : (modelData.id === "oled" ? "#ffffff" : (modelData.acc || Theme.text))
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                visible: modelData.id === "system"
                                width: 28
                                height: 12
                                radius: 3
                                color: Theme.accent
                                Text {
                                    anchors.centerIn: parent
                                    text: "AUTO"
                                    font.pixelSize: 7
                                    font.weight: Font.Bold
                                    color: Theme.bg
                                }
                            }
                        }

                        RowLayout {
                            spacing: 3
                            Rectangle { width: 12; height: 12; radius: 6; color: modelData.bg; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2) }
                            Rectangle { width: 12; height: 12; radius: 6; color: modelData.tile; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.15) }
                            Rectangle { width: 12; height: 12; radius: 6; color: modelData.acc }
                            Rectangle { width: 12; height: 12; radius: 6; color: isSelected ? Theme.accent : Qt.rgba(1, 1, 1, 0.7) }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            widgetsSettingsRoot.setTheme(modelData.id);
                            SoundService.play("click");
                        }
                    }
                }
            }
        }
    }

    // ─── Section 3: Widget Suite Manager (All 24 Widgets) ───
    AppGroup {
        title: "Widget Suite Manager (" + widgetsSettingsRoot.allWidgets.length + " Widgets)"
        icon: "box"
        badge: "Interactive"

        // Search & Filter Toolbar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            RowLayout {
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                // Category Filter Pills
                RowLayout {
                    spacing: Constants.size2Xs

                    Repeater {
                        model: widgetsSettingsRoot.allCategories

                        Rectangle {
                            Layout.preferredHeight: 30
                            Layout.preferredWidth: catText.implicitWidth + 18
                            radius: Constants.sizeXs
                            property bool isCur: widgetsSettingsRoot.selectedCategory === modelData
                            color: isCur ? Theme.accent : Theme.bgSecondary
                            border.width: 1
                            border.color: isCur ? Theme.accent : Theme.border

                            ThemedText {
                                id: catText
                                anchors.centerIn: parent
                                text: modelData
                                customSize: 11
                                font.weight: parent.isCur ? Font.Bold : Font.Normal
                                color: parent.isCur ? Theme.bg : Theme.fg
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: widgetsSettingsRoot.selectedCategory = modelData
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                // Batch Actions
                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 84
                    radius: Constants.sizeXs
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        anchors.centerIn: parent
                        text: "Enable All"
                        customSize: 11
                        font.weight: Font.Medium
                        color: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widgetsSettingsRoot.setAllWidgets(true)
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 84
                    radius: Constants.sizeXs
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        anchors.centerIn: parent
                        text: "Disable All"
                        customSize: 11
                        font.weight: Font.Medium
                        color: Theme.muted
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widgetsSettingsRoot.setAllWidgets(false)
                    }
                }

                Rectangle {
                    Layout.preferredHeight: 30
                    Layout.preferredWidth: 104
                    radius: Constants.sizeXs
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        anchors.centerIn: parent
                        text: "Reset Positions"
                        customSize: 11
                        font.weight: Font.Medium
                        color: Theme.fg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widgetsSettingsRoot.resetLayoutPositions()
                    }
                }
            }

            // Search Bar Input
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 34
                radius: Constants.sizeXs
                color: Theme.bgSecondary
                border.width: 1
                border.color: searchInput.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Constants.sizeSm
                    anchors.rightMargin: Constants.sizeSm
                    spacing: Constants.sizeSm

                    DesktopWidgets.AweIcon {
                        name: "search"
                        size: 14
                        color: Theme.muted
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        color: Theme.fg
                        font.pixelSize: 12
                        clip: true
                        onTextChanged: widgetsSettingsRoot.searchQuery = text.toLowerCase().trim()

                        ThemedText {
                            visible: !searchInput.text
                            text: "Search widgets by name or description..."
                            customSize: 11
                            color: Theme.muted
                        }
                    }

                    ThemedText {
                        visible: searchInput.text !== ""
                        text: "Clear"
                        customSize: 10
                        color: Theme.muted
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = "";
                                widgetsSettingsRoot.searchQuery = "";
                            }
                        }
                    }
                }
            }
        }

        // 2-Column Responsive Grid of all 24 widgets
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Constants.sizeSm
            columnSpacing: Constants.sizeSm

            Repeater {
                model: {
                    return widgetsSettingsRoot.allWidgets.filter(function(w) {
                        let matchesCategory = (widgetsSettingsRoot.selectedCategory === "All" || w.cat === widgetsSettingsRoot.selectedCategory);
                        if (!matchesCategory) return false;
                        if (!widgetsSettingsRoot.searchQuery) return true;
                        let q = widgetsSettingsRoot.searchQuery;
                        return w.name.toLowerCase().indexOf(q) !== -1 ||
                               w.id.toLowerCase().indexOf(q) !== -1 ||
                               w.cat.toLowerCase().indexOf(q) !== -1 ||
                               w.desc.toLowerCase().indexOf(q) !== -1;
                    });
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    radius: Constants.sizeSm
                    property bool isWidgetEnabled: widgetsSettingsRoot.widgetVisibility[modelData.id] !== false
                    color: isWidgetEnabled ? Theme.bgSecondary : Theme.bgTertiary
                    border.width: 1
                    border.color: isWidgetEnabled ? Theme.border : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Constants.sizeSm
                        spacing: Constants.sizeSm

                        // Widget Icon
                        Rectangle {
                            width: 34
                            height: 34
                            radius: Constants.sizeXs
                            color: parent.parent.isWidgetEnabled ? Theme.bgAccent : Theme.bgSecondary
                            border.width: 1
                            border.color: parent.parent.isWidgetEnabled ? Theme.accent : Theme.border
                            Layout.alignment: Qt.AlignVCenter

                            DesktopWidgets.AweIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: 16
                                color: parent.parent.parent.isWidgetEnabled ? Theme.accent : Theme.muted
                            }
                        }

                        // Widget Details
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Layout.alignment: Qt.AlignVCenter

                            RowLayout {
                                spacing: Constants.sizeXs
                                ThemedText {
                                    text: modelData.name
                                    customSize: 12
                                    font.weight: Font.Bold
                                    color: parent.parent.parent.parent.isWidgetEnabled ? Theme.fg : Theme.muted
                                }

                                Rectangle {
                                    Layout.preferredHeight: 14
                                    Layout.preferredWidth: catLabel.implicitWidth + 8
                                    radius: 3
                                    color: Theme.bgTertiary
                                    border.width: 1
                                    border.color: Theme.border

                                    ThemedText {
                                        id: catLabel
                                        anchors.centerIn: parent
                                        text: modelData.cat
                                        customSize: 8
                                        font.weight: Font.Medium
                                        color: Theme.muted
                                    }
                                }
                            }

                            ThemedText {
                                text: modelData.desc
                                customSize: 10
                                color: Theme.muted
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        // Interactive Switch
                        Switch {
                            checked: parent.parent.isWidgetEnabled
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: Constants.size4Xl
                            implicitHeight: Constants.sizeXl + 2
                            onToggled: widgetsSettingsRoot.toggleWidget(modelData.id)

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            indicator: Rectangle {
                                implicitWidth: Constants.size4Xl
                                implicitHeight: Constants.sizeXl + 2
                                radius: height / 2
                                color: parent.checked ? Theme.accent : Theme.bgSecondary
                                border.width: 1
                                border.color: parent.checked ? Theme.accent : Theme.border

                                Rectangle {
                                    x: parent.parent.checked ? parent.width - width - 2 : 2
                                    y: 2
                                    width: parent.height - 4
                                    height: parent.height - 4
                                    radius: width / 2
                                    color: parent.parent.checked ? Theme.bg : Theme.muted

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: Constants.animFast
                                            easing.type: Easing.OutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ─── Section 4: Layout & Quick Setup Presets ───
    AppGroup {
        title: "Desktop Layout Presets"
        icon: "layout"

        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            Repeater {
                model: [
                    { "id": "all", "title": "Balanced Grid", "desc": "Clean 4-column layout with all 24 widgets arranged neatly" },
                    { "id": "minimal", "title": "Minimal Desk", "desc": "Clock, Weather & Media Player only for clean aesthetics" },
                    { "id": "productivity", "title": "Productivity Hub", "desc": "Notes, Todo, Habits, Pomodoro Timer, Git & Calc" },
                    { "id": "telemetry", "title": "Hardware Status", "desc": "Resource Wheel, Thermals, System Info & Network Ping" }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    radius: Constants.sizeSm
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Constants.sizeSm
                        spacing: 4

                        ThemedText {
                            text: modelData.title
                            customSize: 12
                            font.weight: Font.Bold
                            color: Theme.accent
                        }

                        ThemedText {
                            text: modelData.desc
                            customSize: 10
                            color: Theme.muted
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: widgetsSettingsRoot.applyPresetLayout(modelData.id)
                    }
                }
            }
        }
    }
}
