import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Settings.BarSettings
import qs.Modules.Settings.Components
import qs.Modules.Settings.EffectsSettings
import qs.Modules.Settings.InputAndClipboardSettings
import qs.Modules.Settings.IntegrationsSettings
import qs.Modules.Settings.MouseSettings
import qs.Modules.Settings.PersonalizationSettings
import qs.Modules.Settings.SystemInfo
import qs.Modules.Settings.WallpaperSettings
import qs.Modules.Settings.WindowSettings
import qs.Modules.Settings.WidgetsSettings

AppWindow {
    id: root

    property var pageComponents: [personalizationComp, barSettingsComp, effectsComp, windowComp, integrationsComp, mouseComp, inputAndClipboardComp, systemInfoComp, wallpaperComp, barAppletsComp, widgetsComp]
    property int activeTab: 0
    readonly property var navOrder: [0, 8, 1, 9, 10, 2, 3, 5, 6, 4, 7]
    readonly property var tabMetadata: ({
        "0": {
            "title": "Appearance",
            "subtitle": "Themes, dynamic colors, and system typography",
            "category": "DESKTOP"
        },
        "1": {
            "title": "Desktop Bar",
            "subtitle": "Configure widgets, layout, style, and bar visibility",
            "category": "DESKTOP"
        },
        "2": {
            "title": "Visual Effects",
            "subtitle": "Blur, opacity, window animations, and shadow effects",
            "category": "DESKTOP"
        },
        "3": {
            "title": "Windows & Display",
            "subtitle": "Window rules, borders, gaps, and monitor arrangements",
            "category": "DESKTOP"
        },
        "4": {
            "title": "Integrations & Apps",
            "subtitle": "Weather service, GitHub status, notifications, and launcher",
            "category": "MANAGEMENT"
        },
        "5": {
            "title": "Mouse & Touchpad",
            "subtitle": "Cursor speed, acceleration, scrolling, and touchpad gestures",
            "category": "INPUT & HARDWARE"
        },
        "6": {
            "title": "Keyboard & Clipboard",
            "subtitle": "Keyboard layouts, repeat delay, and clipboard history",
            "category": "INPUT & HARDWARE"
        },
        "7": {
            "title": "About System",
            "subtitle": "Hardware specifications, kernel, and software environment",
            "category": "ABOUT"
        },
        "8": {
            "title": "Wallpaper",
            "subtitle": "Screen crop preview, scaling modes, transitions, and shuffle",
            "category": "DESKTOP"
        },
        "9": {
            "title": "Bar Applets",
            "subtitle": "Active window, media visualizer, weather, battery, and status pills",
            "category": "DESKTOP"
        },
        "10": {
            "title": "Widgets",
            "subtitle": "Material 3 floating desktop widgets, themes, visibility, and layout",
            "category": "DESKTOP"
        }
    })
    readonly property var currentTabMeta: tabMetadata[activeTab] || tabMetadata[0]

    widgetId: "minflair_settings"
    windowTitle: "System Settings"
    contentPadding: 0
    property bool isDarkView: Theme.isDark
    backgroundColor: "transparent"

    Connections {
        target: Theme
        function onIsDarkChanged() {
            root.isDarkView = Theme.isDark;
        }
    }

    implicitWidth: {
        if (SettingsService.settingsWindowMode === "full")
            return Quickshell.screens[0] ? Quickshell.screens[0].width : 1920;
        if (SettingsService.settingsWindowMode === "boxed")
            return SettingsService.settingsBoxedWidth;
        return Quickshell.screens[0] ? Math.round(Quickshell.screens[0].width * 0.5) : 960;
    }
    implicitHeight: {
        if (SettingsService.settingsWindowMode === "full")
            return Quickshell.screens[0] ? Quickshell.screens[0].height : 1080;
        if (SettingsService.settingsWindowMode === "boxed")
            return SettingsService.settingsBoxedHeight;
        return Quickshell.screens[0] ? Math.round(Quickshell.screens[0].height * 0.85) : 720;
    }

    Process {
        id: niriWindowAdjustProc
        property string actionCmd: ""
        command: ["sh", "-c", actionCmd]
    }

    Timer {
        id: applyWindowPresentationTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!root.isOpen)
                return;

            if (SettingsService.settingsWindowMode === "boxed") {
                niriWindowAdjustProc.actionCmd = "niri msg action move-window-to-floating 2>/dev/null; niri msg action set-window-width " + SettingsService.settingsBoxedWidth + " 2>/dev/null; niri msg action set-window-height " + SettingsService.settingsBoxedHeight + " 2>/dev/null; niri msg action center-window 2>/dev/null; hyprctl dispatch setfloating active 2>/dev/null; hyprctl dispatch resizeactive exact " + SettingsService.settingsBoxedWidth + " " + SettingsService.settingsBoxedHeight + " 2>/dev/null; hyprctl dispatch centerwindow 2>/dev/null";
                niriWindowAdjustProc.running = false;
                niriWindowAdjustProc.running = true;
            } else if (SettingsService.settingsWindowMode === "full") {
                niriWindowAdjustProc.actionCmd = "niri msg action move-window-to-tiling 2>/dev/null; niri msg action set-column-width '100%' 2>/dev/null; niri msg action maximize-column 2>/dev/null";
                niriWindowAdjustProc.running = false;
                niriWindowAdjustProc.running = true;
            } else {
                niriWindowAdjustProc.actionCmd = "niri msg action move-window-to-tiling 2>/dev/null; niri msg action set-column-width '50%' 2>/dev/null";
                niriWindowAdjustProc.running = false;
                niriWindowAdjustProc.running = true;
            }
        }
    }

    Connections {
        target: SettingsService
        function onSettingsWindowModeChanged() {
            if (root.isOpen)
                applyWindowPresentationTimer.restart();

        }
        function onSettingsBoxedWidthChanged() {
            if (root.isOpen && SettingsService.settingsWindowMode === "boxed")
                applyWindowPresentationTimer.restart();

        }
        function onSettingsBoxedHeightChanged() {
            if (root.isOpen && SettingsService.settingsWindowMode === "boxed")
                applyWindowPresentationTimer.restart();

        }
    }

    onIsOpenChanged: {
        if (isOpen) {
            applyWindowPresentationTimer.restart();
            if (AppState.pendingSettingsTab !== -1) {
                activeTab = AppState.pendingSettingsTab;
                AppState.pendingSettingsTab = -1;
            } else {
                activeTab = 0;
            }
        }
    }

    Rectangle {
        id: windowCanvas
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: SettingsService.settingsBorderlessMode ? 14 : 12
        clip: true
        color: (!SettingsService.settingsCustomBackgroundEnabled)
            ? (root.isDarkView ? "#1E1E1E" : "#F5F5F7")
            : "#101216"
        border.width: SettingsService.settingsBorderlessMode ? 0 : 1
        border.color: root.isDarkView ? "#38383A" : "#D1D1D6"

        // Background Image Layer (Wallpaper or Custom Selected Image)
        Image {
            id: bgImage
            anchors.fill: parent
            visible: SettingsService.settingsCustomBackgroundEnabled && SettingsService.settingsCustomBackgroundBlur <= 0 && source !== ""
            fillMode: Image.PreserveAspectCrop
            source: {
                if (!SettingsService.settingsCustomBackgroundEnabled)
                    return "";
                if (SettingsService.settingsCustomBackgroundSource === "custom" && SettingsService.settingsCustomBackgroundImage !== "")
                    return "file://" + SettingsService.settingsCustomBackgroundImage;
                if (WallpaperManager.currentWallpaperPath !== "")
                    return "file://" + WallpaperManager.currentWallpaperPath;
                return "";
            }
            asynchronous: true
            cache: true
            smooth: true
        }

        // FastBlur for Frosted Glass Effect
        FastBlur {
            id: bgBlur
            anchors.fill: parent
            source: bgImage
            radius: SettingsService.settingsCustomBackgroundBlur
            visible: SettingsService.settingsCustomBackgroundEnabled && SettingsService.settingsCustomBackgroundBlur > 0 && bgImage.status === Image.Ready
            transparentBorder: false
            cached: true
        }

        // Frosted Tint Overlay (Dark/Light)
        Rectangle {
            id: dimOverlay
            anchors.fill: parent
            visible: SettingsService.settingsCustomBackgroundEnabled
            color: root.isDarkView
                ? Qt.rgba(12 / 255, 15 / 255, 20 / 255, SettingsService.settingsCustomBackgroundDim)
                : Qt.rgba(245 / 255, 245 / 255, 247 / 255, SettingsService.settingsCustomBackgroundDim)
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            SettingsSidebar {
                id: sidebar

                Layout.fillHeight: true
                activeTab: root.activeTab
                isDarkView: root.isDarkView
                onTabClicked: (id) => {
                    root.activeTab = id;
                }
                onCloseRequested: {
                    root.isOpen = false;
                }
            }

            Rectangle {
                id: contentContainer

                Layout.fillWidth: true
                Layout.fillHeight: true
                color: SettingsService.settingsCustomBackgroundEnabled
                    ? "transparent"
                    : (root.isDarkView ? "#1E1E1E" : "#F5F5F7")

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    AppHeader {
                        title: root.currentTabMeta.title
                        category: root.currentTabMeta.category
                        subtitle: root.currentTabMeta.subtitle
                        showDivider: true
                        canGoBack: root.activeTab === 9
                        backText: "Desktop Bar"
                        onBackClicked: {
                            root.activeTab = 1;
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        PageTransitionView {
                            anchors.fill: parent
                            activeIndex: root.activeTab
                            order: root.navOrder
                            onContentNeedsUpdate: (index) => {
                                pageLoader.sourceComponent = root.pageComponents[index];
                            }

                            Loader {
                                id: pageLoader

                                anchors.fill: parent
                                sourceComponent: personalizationComp
                            }
                        }
                    }
                }
            }

        }
    }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: root.isOpen && root.pageComponents && root.pageComponents.length > 1
        onActivated: {
            let currentIdx = root.navOrder.indexOf(root.activeTab);
            if (currentIdx === -1)
                currentIdx = 0;

            let nextIdx = (currentIdx + 1) % root.navOrder.length;
            root.activeTab = root.navOrder[nextIdx];
        }
    }

    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: root.isOpen && root.pageComponents && root.pageComponents.length > 1
        onActivated: {
            let currentIdx = root.navOrder.indexOf(root.activeTab);
            if (currentIdx === -1)
                currentIdx = 0;

            let prevIdx = (currentIdx - 1 + root.navOrder.length) % root.navOrder.length;
            root.activeTab = root.navOrder[prevIdx];
        }
    }

    Component {
        id: personalizationComp

        PersonalizationSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: barSettingsComp

        BarSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: effectsComp

        EffectsSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: windowComp

        WindowSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: integrationsComp

        IntegrationsSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: mouseComp

        MouseSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: inputAndClipboardComp

        InputAndClipboardSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: systemInfoComp

        SystemInfo {
            anchors.fill: parent
        }

    }

    Component {
        id: wallpaperComp

        WallpaperSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: barAppletsComp

        BarAppletsSettings {
            anchors.fill: parent
        }

    }

    Component {
        id: widgetsComp

        WidgetsSettings {
            anchors.fill: parent
        }

    }

}
