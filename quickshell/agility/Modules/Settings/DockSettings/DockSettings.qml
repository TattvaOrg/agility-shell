import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Utils
import qs.Modules.Settings.Components

AppContainer {
    id: dockSettingsRoot

    readonly property bool isDarkTheme: ColorUtils.isDark(Theme.bg)

    ColumnLayout {
        width: parent.width
        spacing: Constants.sizeLg

        // ─────────────────────────────────────────────
        // 1. DESKTOP THEMES & COLOR STYLE
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "DESKTOP THEMES & COLOR STYLE"

            SettingToggle {
                labelText: "Dynamic Wallpaper Colors (Matugen)"
                descriptionText: "Automatically extract accent and palette colors from the active wallpaper"
                iconName: "sparkles"
                checked: Theme.generateFromWallpaper
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
                labelText: "Dark Color Scheme"
                descriptionText: "Use dark palette variant for shell surfaces, dock, and widgets"
                iconName: "moon"
                checked: dockSettingsRoot.isDarkTheme
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

            // Theme Cards Grid
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                opacity: Theme.generateFromWallpaper ? 0.45 : 1.0
                enabled: !Theme.generateFromWallpaper

                Text {
                    text: "Curated Shell Themes"
                    font.pixelSize: Constants.fontSizeSm
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 10

                    Repeater {
                        model: Theme.themes

                        Rectangle {
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
                                    Text {
                                        Layout.fillWidth: true
                                        text: parent.parent.parent.modelData.name
                                        font.pixelSize: 11
                                        font.weight: Font.Bold
                                        color: parent.parent.parent.activeSchemeData.fg
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: Theme.accent
                                        visible: parent.parent.parent.isSelected
                                    }
                                }

                                // Color Palette Swatches
                                RowLayout {
                                    spacing: 4

                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: parent.parent.parent.activeSchemeData.bg
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.2)
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: parent.parent.parent.activeSchemeData.accent
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: parent.parent.parent.activeSchemeData.accentComplementary
                                    }
                                    Rectangle {
                                        width: 14; height: 14; radius: 7
                                        color: parent.parent.parent.activeSchemeData.fg
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    let s = dockSettingsRoot.isDarkTheme ? parent.modelData.dark : parent.modelData.light;
                                    Theme.applyScheme(s);
                                    SoundService.play("click");
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 2. FLOATING DOCK CONFIGURATION
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "FLOATING DOCK"

            SettingToggle {
                labelText: "Enable Dynamic Dock"
                descriptionText: "Show a floating macOS / iPadOS-style app dock with smooth magnification"
                iconName: "apps"
                checked: SettingsService.dockEnabled
                onToggled: function(val) {
                    SettingsService.dockEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingSegmented {
                labelText: "Dock Screen Edge Position"
                descriptionText: "Pin the dock along the bottom, left, or right display boundary"
                iconName: "layout"
                options: ["Bottom", "Left", "Right"]
                currentIndex: {
                    if (SettingsService.dockPosition === "left") return 1;
                    if (SettingsService.dockPosition === "right") return 2;
                    return 0;
                }
                onIndexSelected: function(idx) {
                    let pos = "bottom";
                    if (idx === 1) pos = "left";
                    if (idx === 2) pos = "right";
                    SettingsService.dockPosition = pos;
                    SettingsService.saveSettings();
                }
            }

            SettingToggle {
                labelText: "Auto-Hide Dock"
                descriptionText: "Hide dock when idle and smoothly reveal when hovering screen edge"
                iconName: "eye"
                checked: SettingsService.dockAutoHide
                onToggled: function(val) {
                    SettingsService.dockAutoHide = val;
                    SettingsService.saveSettings();
                }
            }

            SettingToggle {
                labelText: "Dynamic Magnification Zoom"
                descriptionText: "Magnify hovered app icon and neighboring icons using parabolic physics"
                iconName: "sparkles"
                checked: SettingsService.dockMagnification
                onToggled: function(val) {
                    SettingsService.dockMagnification = val;
                    SettingsService.saveSettings();
                }
            }

            SettingSegmented {
                labelText: "Base Icon Size"
                descriptionText: "Standard size for application icons resting in the dock"
                iconName: "settings"
                options: ["36px", "44px", "48px", "56px"]
                currentIndex: {
                    if (SettingsService.dockIconSize === 36) return 0;
                    if (SettingsService.dockIconSize === 44) return 1;
                    if (SettingsService.dockIconSize === 56) return 3;
                    return 2; // 48px
                }
                onIndexSelected: function(idx) {
                    let sizes = [36, 44, 48, 56];
                    SettingsService.dockIconSize = sizes[idx];
                    SettingsService.saveSettings();
                }
            }

            SettingRowTemplate {
                labelText: "Toggle Dock"
                descriptionText: "Quickly toggle the dock visibility now"
                iconName: "layout"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: dockToggleBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: dockToggleHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: dockToggleBtnText
                        anchors.centerIn: parent
                        text: SettingsService.dockEnabled ? "Hide Dock" : "Show Dock"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.DemiBold
                        color: dockToggleHover.containsMouse ? Theme.bg : Theme.text
                    }

                    MouseArea {
                        id: dockToggleHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            SettingsService.dockEnabled = !SettingsService.dockEnabled;
                            SettingsService.saveSettings();
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 3. SPOTLIGHT COMMAND BAR
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "SPOTLIGHT COMMAND BAR"

            SettingToggle {
                labelText: "Enable Spotlight (Mod + K)"
                descriptionText: "Raycast/Spotlight unified command bar for math, apps, window switching, and web"
                iconName: "search"
                checked: SettingsService.spotlightEnabled
                onToggled: function(val) {
                    SettingsService.spotlightEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            // Overview Info Card
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

                    Text {
                        text: "Spotlight Capabilities & Triggers:"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    Text {
                        text: "• Math & Calculator: Evaluates arithmetic (42*8, sqrt(144), 0xff in dec, 255 in hex) with one-click copy\n• Window Switcher: Instant filter over open windows (prefix 'w:') to focus windows across workspaces\n• Web Shortcuts: 'g:' Google, 'gh:' GitHub, 'yt:' YouTube, 'w:' Wikipedia, 'ddg:' DuckDuckGo\n• Quick Actions: Lock, Reboot, Shutdown, Sleep, Dark Mode toggle, DND toggle, Screenshot capture\n• Fuzzy App Search: Instantly launch any desktop application with fuzzy name matching"
                        font.pixelSize: Constants.fontSizeSm
                        color: Theme.textSecondary
                        lineHeight: 1.3
                    }
                }
            }

            SettingRowTemplate {
                labelText: "Open Spotlight"
                descriptionText: "Trigger the Spotlight modal now to search apps, calculate math, or switch windows"
                iconName: "command"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: spotBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: spotBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: spotBtnText
                        anchors.centerIn: parent
                        text: "Launch (Mod+K)"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.DemiBold
                        color: spotBtnHover.containsMouse ? Theme.bg : Theme.text
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
        SettingGroup {
            title: "DYNAMIC ISLAND & LIVE ACTIVITIES"

            SettingToggle {
                labelText: "Enable Dynamic Island Capsule"
                descriptionText: "Expanding floating capsule at top center for live music, timer, and toasts"
                iconName: "music"
                checked: SettingsService.dynamicIslandEnabled
                onToggled: function(val) {
                    SettingsService.dynamicIslandEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            // Overview Info Card
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

                    Text {
                        text: "Included Live Activities:"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    Text {
                        text: "• Rotating vinyl & audio wave bars for active MPRIS music playback\n• Expandable mini-player on click with scrub bar and media controls\n• Live countdown timer and circular progress ring when Focus Timer is running\n• Animated toast capsule whenever text is copied to clipboard\n• Low battery (< 15%) flashing warning badge"
                        font.pixelSize: Constants.fontSizeSm
                        color: Theme.textSecondary
                        lineHeight: 1.3
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 5. MISSION CONTROL / VISUAL WORKSPACE OVERVIEW
        // ─────────────────────────────────────────────
        SettingGroup {
            title: "MISSION CONTROL & WORKSPACE OVERVIEW"

            SettingToggle {
                labelText: "Enable Mission Control (Mod + Tab)"
                descriptionText: "Fullscreen visual overview of all workspaces and open windows"
                iconName: "window"
                checked: SettingsService.missionControlEnabled
                onToggled: function(val) {
                    SettingsService.missionControlEnabled = val;
                    SettingsService.saveSettings();
                }
            }

            SettingRowTemplate {
                labelText: "Open Mission Control"
                descriptionText: "View all occupied workspaces, filter windows, and switch between them"
                iconName: "layout"

                Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: mcBtnText.implicitWidth + 24
                    radius: Constants.sizeMd
                    color: mcBtnHover.containsMouse ? Theme.accent : Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    Text {
                        id: mcBtnText
                        anchors.centerIn: parent
                        text: "Launch (Mod+Tab)"
                        font.pixelSize: Constants.fontSizeSm
                        font.weight: Font.DemiBold
                        color: mcBtnHover.containsMouse ? Theme.bg : Theme.text
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
    }
}
