import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: dockSettingsRoot

    readonly property bool isDarkTheme: ColorUtils.isDark(Theme.bg)
    property bool showAppPicker: false
    property string appSearchQuery: ""

    readonly property var availableToPin: {
        let apps = Array.isArray(AppState.launcherApps) ? AppState.launcherApps : [];
        let q = appSearchQuery.trim().toLowerCase();
        let out = [];
        for (let i = 0; i < apps.length; i++) {
            let app = apps[i];
            if (!app || !app.name) continue;
            if (SettingsService.isAppPinned(app)) continue;
            if (q !== "" && !app.name.toLowerCase().includes(q) && !(app.exec || "").toLowerCase().includes(q)) continue;
            out.push(app);
            if (out.length >= 24) break;
        }
        return out;
    }

    function resolveIconSource(iconName) {
        if (!iconName) return "";
        let path = String(iconName);
        let home = Quickshell.env("HOME") || "";
        if (path.startsWith("$HOME")) {
            path = home + path.substring(5);
        } else if (path.startsWith("~")) {
            path = home + path.substring(1);
        }
        if (path.startsWith("/") || path.startsWith("file://")) {
            return path.startsWith("file://") ? path : ("file://" + path);
        }
        return Quickshell.iconPath(path, true);
    }

    Process {
        id: loadAppsProc
        command: ["agl", "get-apps"]
        stdout: StdioCollector {
            id: appsOutput
        }
        onExited: function(exitCode) {
            if (exitCode === 0 && appsOutput.text) {
                try {
                    let parsed = JSON.parse(appsOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        AppState.launcherApps = parsed;
                    }
                } catch (e) {
                }
            }
        }
    }

    Component.onCompleted: {
        if (!AppState.launcherApps || AppState.launcherApps.length === 0) {
            loadAppsProc.running = true;
        }
    }

    ColumnLayout {
        width: parent.width
        spacing: Constants.sizeLg

        // ─────────────────────────────────────────────
        // 1. FLOATING DOCK CONFIGURATION
        // ─────────────────────────────────────────────
        AppGroup {
            title: "FLOATING DOCK"
            icon: "dock"

            SettingToggle {
                label: "Enable Dynamic Dock"
                description: "Show a compact floating app dock with smooth magnification"
                Binding on checked { value: SettingsService.dockEnabled }
                onToggled: function(val) {
                    SettingsService.dockEnabled = val;
                    SoundService.play("click");
                }
            }

            SettingSegmented {
                label: "Dock Screen Edge Position"
                description: "Pin the dock along the bottom, top, left, or right display boundary"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                model: [
                    { "text": "Bottom", "value": "bottom" },
                    { "text": "Top", "value": "top" },
                    { "text": "Left", "value": "left" },
                    { "text": "Right", "value": "right" }
                ]
                currentValue: SettingsService.dockPosition
                onActivated: function(val) {
                    SettingsService.dockPosition = val;
                    SoundService.play("click");
                }
            }

            SettingToggle {
                label: "Show Launcher in Dock"
                description: "Display an Applications launcher shortcut on the leading dock edge"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                Binding on checked { value: SettingsService.dockShowLauncher }
                onToggled: function(val) {
                    SettingsService.dockShowLauncher = val;
                    SoundService.play("click");
                }
            }

            SettingToggle {
                label: "Show Trash in Dock"
                description: "Display a Trash bin shortcut on the trailing dock edge"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                Binding on checked { value: SettingsService.dockShowTrash }
                onToggled: function(val) {
                    SettingsService.dockShowTrash = val;
                    SoundService.play("click");
                }
            }

            SettingToggle {
                label: "Auto-Hide Dock"
                description: "Hide dock when idle and smoothly reveal when hovering screen edge"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                Binding on checked { value: SettingsService.dockAutoHide }
                onToggled: function(val) {
                    SettingsService.dockAutoHide = val;
                    SoundService.play("click");
                }
            }

            SettingToggle {
                label: "Dynamic Magnification Zoom"
                description: "Smoothly magnify hovered app icon and neighboring icons"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                Binding on checked { value: SettingsService.dockMagnification }
                onToggled: function(val) {
                    SettingsService.dockMagnification = val;
                    SoundService.play("click");
                }
            }

            SettingSpinBox {
                label: "Dock Icon Size"
                description: "Adjust dock icon size between 24px and 64px (or scroll on the dock)"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                from: 24
                to: 64
                stepSize: 2
                defaultValue: 38
                suffix: "px"
                value: SettingsService.dockIconSize
                onMoved: function(val) {
                    SettingsService.dockIconSize = Math.round(val);
                    SoundService.play("click");
                }
            }

            SettingSpinBox {
                label: "Dock Icon Spacing"
                description: "Adjust spacing between dock icons (2px to 20px)"
                enabled: SettingsService.dockEnabled
                opacity: SettingsService.dockEnabled ? 1.0 : 0.45
                from: 2
                to: 20
                stepSize: 2
                defaultValue: 6
                suffix: "px"
                value: SettingsService.dockItemSpacing
                onMoved: function(val) {
                    SettingsService.dockItemSpacing = Math.round(val);
                    SoundService.play("click");
                }
            }

            SettingRowTemplate {
                label: "Toggle Dock"
                description: "Quickly toggle the dock visibility now (Mod + Alt + D)"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: dockToggleBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: dockToggleHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        id: dockToggleBtnText
                        anchors.centerIn: parent
                        text: SettingsService.dockEnabled ? "Hide Dock" : "Show Dock"
                        customSize: Constants.sizeSm
                        font.weight: Font.DemiBold
                        color: dockToggleHover.containsMouse ? Theme.bg : Theme.fg
                    }

                    MouseArea {
                        id: dockToggleHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsService.dockEnabled = !SettingsService.dockEnabled;
                            SoundService.play("click");
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 2. PINNED DOCK APPLICATIONS
        // ─────────────────────────────────────────────
        AppGroup {
            title: "PINNED DOCK APPLICATIONS"
            icon: "star"

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ThemedText {
                        Layout.fillWidth: true
                        text: (SettingsService.dockPinnedApps && SettingsService.dockPinnedApps.length > 0)
                            ? "Pinned Apps (" + SettingsService.dockPinnedApps.length + ")"
                            : "No pinned applications. Pin apps below or right-click any app in Launcher or Dock."
                        customSize: Constants.sizeSm
                        color: Theme.muted
                        wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.preferredHeight: 28
                        Layout.preferredWidth: pinAddBtnLabel.implicitWidth + 20
                        radius: Constants.sizeMd
                        color: pinAddBtnHover.hovered ? Theme.accent : Theme.bgSecondary
                        border.width: 1
                        border.color: Theme.border

                        HoverHandler { id: pinAddBtnHover }

                        ThemedText {
                            id: pinAddBtnLabel
                            anchors.centerIn: parent
                            text: dockSettingsRoot.showAppPicker ? "Done" : "+ Pin App"
                            customSize: 11
                            font.weight: Font.DemiBold
                            color: pinAddBtnHover.hovered ? Theme.bg : Theme.fg
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                dockSettingsRoot.showAppPicker = !dockSettingsRoot.showAppPicker;
                                if (dockSettingsRoot.showAppPicker && (!AppState.launcherApps || AppState.launcherApps.length === 0)) {
                                    loadAppsProc.running = true;
                                }
                                SoundService.play("click");
                            }
                        }
                    }
                }

                // Inline App Picker for pinning directly from Dock Settings
                Rectangle {
                    visible: dockSettingsRoot.showAppPicker
                    Layout.fillWidth: true
                    Layout.preferredHeight: pickerCol.implicitHeight + 16
                    radius: Constants.sizeMd
                    color: Theme.bg
                    border.width: 1
                    border.color: Theme.border

                    ColumnLayout {
                        id: pickerCol
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        ThemedSearchBar {
                            id: pickerSearch
                            autoFocus: false
                            preferredHeight: 34
                            placeholderText: "Filter applications to pin..."
                            onSearchRequested: function(txt) {
                                dockSettingsRoot.appSearchQuery = txt;
                            }
                        }

                        ThemedText {
                            visible: dockSettingsRoot.availableToPin.length === 0
                            text: (AppState.launcherApps && AppState.launcherApps.length > 0)
                                ? "No matching unpinned applications"
                                : "Loading installed applications..."
                            customSize: 11
                            color: Theme.muted
                            Layout.leftMargin: 4
                        }

                        Flickable {
                            visible: dockSettingsRoot.availableToPin.length > 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(220, pickerListCol.implicitHeight)
                            contentWidth: width
                            contentHeight: pickerListCol.implicitHeight
                            clip: true
                            interactive: true

                            ColumnLayout {
                                id: pickerListCol
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: dockSettingsRoot.availableToPin

                                    Rectangle {
                                        id: pickRow
                                        required property var modelData
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 36
                                        radius: Constants.sizeSm
                                        color: pickRowHover.hovered ? Theme.bgSecondary : "transparent"

                                        HoverHandler { id: pickRowHover }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 10

                                            Image {
                                                id: pickImg
                                                width: 20
                                                height: 20
                                                sourceSize: Qt.size(40, 40)
                                                source: dockSettingsRoot.resolveIconSource(pickRow.modelData.icon)
                                                fillMode: Image.PreserveAspectFit
                                                visible: status === Image.Ready
                                            }

                                            SvgIcon {
                                                icon: "rocket"
                                                iconSize: 18
                                                flat: true
                                                visible: !pickImg.visible
                                            }

                                            ThemedText {
                                                Layout.fillWidth: true
                                                text: pickRow.modelData.name
                                                customSize: Constants.sizeSm
                                                font.weight: Font.Medium
                                                color: Theme.fg
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                Layout.preferredHeight: 24
                                                Layout.preferredWidth: 52
                                                radius: Constants.sizeSm
                                                color: doPinHover.hovered ? Theme.accent : Theme.bgSecondary
                                                border.width: 1
                                                border.color: doPinHover.hovered ? Theme.accent : Theme.border

                                                HoverHandler { id: doPinHover }

                                                ThemedText {
                                                    anchors.centerIn: parent
                                                    text: "Pin"
                                                    customSize: 11
                                                    font.weight: Font.DemiBold
                                                    color: doPinHover.hovered ? Theme.bg : Theme.fg
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        SettingsService.pinApp(pickRow.modelData);
                                                        SoundService.play("click");
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

                Repeater {
                    model: SettingsService.dockPinnedApps || []

                    Rectangle {
                        id: pinnedRow
                        required property var modelData
                        required property int index
                        readonly property int totalPinned: SettingsService.dockPinnedApps ? SettingsService.dockPinnedApps.length : 0

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        radius: Constants.sizeMd
                        color: Theme.bgSecondary
                        border.width: 1
                        border.color: Theme.border

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 10

                            Image {
                                id: pinnedAppImg
                                width: 24
                                height: 24
                                sourceSize: Qt.size(48, 48)
                                source: dockSettingsRoot.resolveIconSource(pinnedRow.modelData.icon)
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }

                            SvgIcon {
                                icon: "rocket"
                                iconSize: 20
                                flat: true
                                visible: !pinnedAppImg.visible
                            }

                            ThemedText {
                                Layout.fillWidth: true
                                text: pinnedRow.modelData.name || pinnedRow.modelData.id
                                customSize: Constants.sizeSm
                                font.weight: Font.DemiBold
                                color: Theme.fg
                                elide: Text.ElideRight
                            }

                            // Move Up / Left
                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: 26
                                radius: Constants.sizeSm
                                opacity: pinnedRow.index > 0 ? 1.0 : 0.35
                                color: upHover.hovered && pinnedRow.index > 0 ? Theme.bgAccent : Theme.bg
                                border.width: 1
                                border.color: Theme.border

                                HoverHandler { id: upHover }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: "chevron-up"
                                    iconSize: 13
                                    iconColor: Theme.fg
                                    flat: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: pinnedRow.index > 0
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        SettingsService.movePinnedApp(pinnedRow.index, pinnedRow.index - 1);
                                        SoundService.play("click");
                                    }
                                }
                            }

                            // Move Down / Right
                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: 26
                                radius: Constants.sizeSm
                                opacity: pinnedRow.index < (pinnedRow.totalPinned - 1) ? 1.0 : 0.35
                                color: downHover.hovered && pinnedRow.index < (pinnedRow.totalPinned - 1) ? Theme.bgAccent : Theme.bg
                                border.width: 1
                                border.color: Theme.border

                                HoverHandler { id: downHover }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: "chevron-down"
                                    iconSize: 13
                                    iconColor: Theme.fg
                                    flat: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: pinnedRow.index < (pinnedRow.totalPinned - 1)
                                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        SettingsService.movePinnedApp(pinnedRow.index, pinnedRow.index + 1);
                                        SoundService.play("click");
                                    }
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 26
                                Layout.preferredWidth: 64
                                radius: Constants.sizeSm
                                color: unpinHover.hovered ? Qt.rgba(1, 0.2, 0.2, 0.2) : Theme.bg
                                border.width: 1
                                border.color: unpinHover.hovered ? "#FF4B4B" : Theme.border

                                HoverHandler { id: unpinHover }

                                ThemedText {
                                    anchors.centerIn: parent
                                    text: "Unpin"
                                    customSize: 11
                                    font.weight: Font.Medium
                                    color: unpinHover.hovered ? "#FF4B4B" : Theme.muted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        SettingsService.unpinApp(pinnedRow.modelData);
                                        SoundService.play("click");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 3. SPOTLIGHT COMMAND BAR
        // ─────────────────────────────────────────────
        AppGroup {
            title: "SPOTLIGHT COMMAND BAR"
            icon: "spotlight"

            SettingToggle {
                label: "Enable Spotlight (Mod + K)"
                description: "Raycast/Spotlight unified command bar for math, apps, window switching, and web"
                Binding on checked { value: SettingsService.spotlightEnabled }
                onToggled: function(val) {
                    SettingsService.spotlightEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: spotlightInfoCol.implicitHeight + 24
                radius: Constants.sizeLg
                color: Qt.rgba(0.1, 0.1, 0.15, 0.4)
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: spotlightInfoCol
                    anchors.fill: parent
                    anchors.margins: Constants.sizeMd
                    spacing: 8

                    ThemedText {
                        text: "Spotlight Capabilities & Triggers:"
                        customSize: Constants.sizeSm
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    ThemedText {
                        Layout.fillWidth: true
                        text: "• Math & Calculator: Evaluates arithmetic (42*8, sqrt(144), 0xff in dec, 255 in hex) with one-click copy\n• Window Switcher: Instant filter over open windows (prefix 'w:') to focus windows across workspaces\n• Web Shortcuts: 'g:' Google, 'gh:' GitHub, 'yt:' YouTube, 'w:' Wikipedia, 'ddg:' DuckDuckGo\n• Quick Actions: Lock, Reboot, Shutdown, Sleep, Dark Mode toggle, DND toggle, Screenshot capture\n• Fuzzy App Search: Instantly launch any desktop application with fuzzy name matching"
                        customSize: Constants.sizeSm
                        color: Theme.muted
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                    }
                }
            }

            SettingRowTemplate {
                label: "Open Spotlight"
                description: "Trigger the Spotlight modal now to search apps, calculate math, or switch windows"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: spotBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: spotBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        id: spotBtnText
                        anchors.centerIn: parent
                        text: "Launch (Mod+K)"
                        customSize: Constants.sizeSm
                        font.weight: Font.DemiBold
                        color: spotBtnHover.containsMouse ? Theme.bg : Theme.fg
                    }

                    MouseArea {
                        id: spotBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("spotlight")
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 4. DYNAMIC ISLAND & LIVE ACTIVITIES HUB
        // ─────────────────────────────────────────────
        AppGroup {
            title: "DYNAMIC ISLAND & LIVE ACTIVITIES"
            icon: "sparkles"

            SettingToggle {
                label: "Enable Dynamic Island Capsule"
                description: "Expanding floating capsule at top center for live music, timer, and toasts"
                Binding on checked { value: SettingsService.dynamicIslandEnabled }
                onToggled: function(val) {
                    SettingsService.dynamicIslandEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: islandInfoCol.implicitHeight + 24
                radius: Constants.sizeLg
                color: Qt.rgba(0.1, 0.1, 0.15, 0.4)
                border.width: 1
                border.color: Theme.border

                ColumnLayout {
                    id: islandInfoCol
                    anchors.fill: parent
                    anchors.margins: Constants.sizeMd
                    spacing: 8

                    ThemedText {
                        text: "Included Live Activities:"
                        customSize: Constants.sizeSm
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    ThemedText {
                        Layout.fillWidth: true
                        text: "• Rotating vinyl & audio wave bars for active MPRIS music playback\n• Expandable mini-player on click with scrub bar and media controls\n• Live countdown timer and circular progress ring when Focus Timer is running\n• Animated toast capsule whenever text is copied to clipboard\n• Low battery (< 15%) flashing warning badge"
                        customSize: Constants.sizeSm
                        color: Theme.muted
                        lineHeight: 1.3
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 5. MISSION CONTROL / VISUAL WORKSPACE OVERVIEW
        // ─────────────────────────────────────────────
        AppGroup {
            title: "WINDOW SWITCHER & MISSION CONTROL"
            icon: "window"

            SettingToggle {
                label: "Enable Window Switcher (Mod + Tab)"
                description: "macOS-style compact window switcher with live thumbnails, workspace badges, and instant keyboard navigation"
                Binding on checked { value: SettingsService.missionControlEnabled }
                onToggled: function(val) {
                    SettingsService.missionControlEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingRowTemplate {
                label: "Open Window Switcher"
                description: "Trigger the macOS-style switcher now to cycle through open windows across all workspaces"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: mcBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: mcBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    ThemedText {
                        id: mcBtnText
                        anchors.centerIn: parent
                        text: "Launch Mission Control"
                        customSize: Constants.sizeSm
                        font.weight: Font.DemiBold
                        color: mcBtnHover.containsMouse ? Theme.bg : Theme.fg
                    }

                    MouseArea {
                        id: mcBtnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("missioncontrol")
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 6. DESKTOP THEMES & COLOR STYLE
        // ─────────────────────────────────────────────
        AppGroup {
            title: "DESKTOP THEMES & COLOR STYLE"
            icon: "color-palette"

            SettingToggle {
                label: "Dynamic Wallpaper Colors (Matugen)"
                description: "Automatically extract accent and palette colors from the active wallpaper"
                Binding on checked { value: Theme.generateFromWallpaper }
                onToggled: function(val) {
                    Theme.generateFromWallpaper = val;
                    if (val) {
                        if (WallpaperManager.currentWallpaperPath !== "")
                            Theme.generateTheme(WallpaperManager.currentWallpaperPath);
                    } else {
                        let t = Theme.themes[0];
                        let baseName = Theme.currentScheme.replace(" Light", "");
                        for (let i = 0; i < Theme.themes.length; i++) {
                            if (Theme.themes[i].name === baseName) {
                                t = Theme.themes[i];
                                break;
                            }
                        }
                        let scheme = dockSettingsRoot.isDarkTheme ? t.dark : t.light;
                        Theme.applyScheme(scheme);
                    }
                }
            }

            SettingToggle {
                label: "Dark Color Scheme"
                description: "Use dark palette variant for shell surfaces, dock, and widgets"
                Binding on checked { value: dockSettingsRoot.isDarkTheme }
                onToggled: function(val) {
                    if (Theme.generateFromWallpaper) {
                        Theme.applyWallpaperTheme(val);
                    } else {
                        let baseName = Theme.currentScheme.replace(" Light", "");
                        let t = Theme.themes[0];
                        for (let i = 0; i < Theme.themes.length; i++) {
                            if (Theme.themes[i].name === baseName) {
                                t = Theme.themes[i];
                                break;
                            }
                        }
                        let scheme = val ? t.dark : t.light;
                        Theme.applyScheme(scheme);
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: Theme.generateFromWallpaper ? 0.45 : 1.0
                enabled: !Theme.generateFromWallpaper

                ThemedText {
                    text: "Curated Shell Themes"
                    customSize: Constants.sizeSm
                    font.weight: Font.DemiBold
                    color: Theme.muted
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: Theme.themes

                        Rectangle {
                            id: themeCard
                            required property var modelData
                            required property int index
                            readonly property var activeSchemeData: dockSettingsRoot.isDarkTheme ? modelData.dark : modelData.light
                            readonly property bool isSelected: {
                                let cur = Theme.currentScheme.replace(" Light", "");
                                return cur === modelData.name || Theme.currentScheme === activeSchemeData.name;
                            }

                            width: 140
                            height: 64
                            radius: Constants.sizeMd
                            color: activeSchemeData.bg
                            border.width: isSelected ? 2 : 1
                            border.color: isSelected ? Theme.accent : Theme.border

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                RowLayout {
                                    Layout.fillWidth: true
                                    ThemedText {
                                        Layout.fillWidth: true
                                        text: themeCard.modelData.name
                                        customSize: 11
                                        font.weight: Font.Bold
                                        color: themeCard.activeSchemeData.fg
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: Theme.accent
                                        visible: themeCard.isSelected
                                    }
                                }

                                RowLayout {
                                    spacing: 4

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: themeCard.activeSchemeData.bg
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: themeCard.activeSchemeData.accent
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: themeCard.activeSchemeData.accentComplementary
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: themeCard.activeSchemeData.fg
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let s = dockSettingsRoot.isDarkTheme ? themeCard.modelData.dark : themeCard.modelData.light;
                                    Theme.applyScheme(s);
                                    SoundService.play("click");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
