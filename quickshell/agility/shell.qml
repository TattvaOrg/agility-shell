//@ pragma ShellId agility-shell
//@ pragma AppId agility-shell
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Bar
import qs.Modules.Bar.Styles.Convex
import qs.Modules.Bar.Styles.Gaming
import qs.Modules.OSD
import qs.Modules.DesktopWidgets
import qs.Modules.Dock
import qs.Modules.DynamicIsland

ShellRoot {
    id: root

    readonly property bool isGaming: DisplayProfileService.gameModeActive
    readonly property bool isConvex: SettingsService.barStyle === "convex"

    IpcHandler {
        target: "osd"

        function volume(val: string) {
            OsdService.showVolume(val);
        }

        function brightness(val: string) {
            OsdService.showBrightness(val);
        }
    }

    IpcHandler {
        target: "wallpaper"

        function cycle(x: real, y: real) {
            WallpaperManager.cycleNextWallpaper(x, y, 1920, 1080);
        }
    }

    IpcHandler {
        target: "widgets"

        function toggle(widgetId: string): bool {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = !SettingsService.edgeLightingEnabled;
                return true;
            }
            if (widgetId === "desktopwidgets" || widgetId === "desktop-widgets" || widgetId === "widgets") {
                SettingsService.desktopWidgetsEnabled = !SettingsService.desktopWidgetsEnabled;
                return true;
            }
            if (widgetId === "dock") {
                SettingsService.dockEnabled = !SettingsService.dockEnabled;
                return true;
            }
            if (widgetId === "island" || widgetId === "dynamicisland" || widgetId === "dynamic-island") {
                SettingsService.dynamicIslandEnabled = !SettingsService.dynamicIslandEnabled;
                return true;
            }
            if (widgetId === "spotlight" || widgetId === "omni") {
                AppState.toggleWidget("spotlight");
                return true;
            }
            AppState.toggleWidget(widgetId);
            return true;
        }

        function open(widgetId: string): bool {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = true;
                return true;
            }
            if (widgetId === "desktopwidgets" || widgetId === "desktop-widgets" || widgetId === "widgets") {
                SettingsService.desktopWidgetsEnabled = true;
                return true;
            }
            if (widgetId === "dock") {
                SettingsService.dockEnabled = true;
                return true;
            }
            if (widgetId === "island" || widgetId === "dynamicisland" || widgetId === "dynamic-island") {
                SettingsService.dynamicIslandEnabled = true;
                return true;
            }
            if (widgetId === "spotlight" || widgetId === "omni") {
                AppState.openWidget("spotlight");
                return true;
            }
            AppState.openWidget(widgetId);
            return true;
        }

        function close(widgetId: string): bool {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = false;
                return true;
            }
            if (widgetId === "desktopwidgets" || widgetId === "desktop-widgets" || widgetId === "widgets") {
                SettingsService.desktopWidgetsEnabled = false;
                return true;
            }
            if (widgetId === "dock") {
                SettingsService.dockEnabled = false;
                return true;
            }
            if (widgetId === "island" || widgetId === "dynamicisland" || widgetId === "dynamic-island") {
                SettingsService.dynamicIslandEnabled = false;
                return true;
            }
            if (widgetId === "spotlight" || widgetId === "omni") {
                AppState.closeWidget("spotlight");
                return true;
            }
            AppState.closeWidget(widgetId);
            return true;
        }
    }

    SocketServer {
        id: edgelightServer
        path: "/tmp/quickshell_edgelight"
        active: true
        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        SettingsService.edgeLightingEnabled = !SettingsService.edgeLightingEnabled;
                        Qt.callLater(() => { connected = false; });
                    }
                }
            }
        }
    }

    SocketServer {
        id: dockSocketServer
        path: "/tmp/quickshell_dock"
        active: true
        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        SettingsService.dockEnabled = !SettingsService.dockEnabled;
                        Qt.callLater(() => { connected = false; });
                    }
                }
            }
        }
    }

    SocketServer {
        id: islandSocketServer
        path: "/tmp/quickshell_island"
        active: true
        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        SettingsService.dynamicIslandEnabled = !SettingsService.dynamicIslandEnabled;
                        Qt.callLater(() => { connected = false; });
                    }
                }
            }
        }
    }

    SocketServer {
        id: desktopWidgetsSocketServer
        path: "/tmp/quickshell_desktopwidgets"
        active: true
        handler: Component {
            Socket {
                onConnectedChanged: {
                    if (connected) {
                        SettingsService.desktopWidgetsEnabled = !SettingsService.desktopWidgetsEnabled;
                        Qt.callLater(() => { connected = false; });
                    }
                }
            }
        }
    }

    NotificationService {
        id: globalNotificationService
    }

    PanelWindow {
        id: barSurface

        readonly property int barHeight: BarStyleConfig.barHeight(SettingsService.barStyle)
        readonly property int barMarginTop: BarStyleConfig.barMarginTop(SettingsService.barStyle)
        readonly property int barMarginSide: BarStyleConfig.barMarginSide(SettingsService.barStyle)

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusionMode: (SettingsService.barAutoHide && (SettingsService.barIslandMode || SettingsService.barPillMode)) ? ExclusionMode.Ignore : ExclusionMode.Auto
        color: "transparent"
        focusable: false
        implicitHeight: !SettingsService.settingsLoaded ? 0 : (barMarginTop + barHeight)
        visible: SettingsService.settingsLoaded && !root.isGaming

        anchors {
            top: true
            left: true
            right: true
        }

        mask: Region {
        }

    }

    PanelWindow {
        id: gamingBarSurface

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.exclusiveZone: Constants.size3Xl + 2
        color: Theme.bg
        focusable: false
        implicitHeight: Constants.size3Xl + 2
        visible: SettingsService.settingsLoaded && root.isGaming

        anchors {
            top: true
            left: true
            right: true
        }

        GamingBar {
            anchors.fill: parent
            notificationService: globalNotificationService
        }

    }

    BarOverlayWindow {
        notificationService: globalNotificationService
        barSurface: barSurface
        visible: SettingsService.settingsLoaded && !root.isConvex && !root.isGaming
    }

    ConvexDesktop {
        id: convexDesktopSurface

        notificationService: globalNotificationService
        visible: SettingsService.settingsLoaded && root.isConvex && !root.isGaming
    }

    GamingOverlay {
        id: gamingOverlaySurface

        notificationService: globalNotificationService
    }

    ShellModules {
        id: shellModules
        notificationService: globalNotificationService
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            color: "transparent"
            focusable: false
            visible: SettingsService.settingsLoaded && HyprlandService.wpClicksEnabled

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            TapHandler {
                acceptedButtons: Qt.LeftButton
                gesturePolicy: TapHandler.WithinBounds
                onDoubleTapped: (eventPoint) => {
                    WallpaperManager.cycleNextWallpaper(eventPoint.position.x, eventPoint.position.y, parent.width, parent.height);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                propagateComposedEvents: true
                onDoubleClicked: (mouse) => {
                    WallpaperManager.cycleNextWallpaper(mouse.x, mouse.y, parent.width, parent.height);
                }
            }
        }
    }

    DesktopWidgetsLayer {
        id: desktopWidgetsLayer
        visible: SettingsService.settingsLoaded && SettingsService.desktopWidgetsEnabled && !root.isGaming
    }

    Dock {
        id: dockLayer
        visible: SettingsService.settingsLoaded && SettingsService.dockEnabled && !root.isGaming
    }

    DynamicIsland {
        id: dynamicIslandLayer
        visible: SettingsService.settingsLoaded && SettingsService.dynamicIslandEnabled && !root.isGaming
    }

    OsdPill {
        id: osdPillWindow
    }
    Timer {
        id: startupSoundTimer
        interval: 300
        running: SettingsService.settingsLoaded
        repeat: false
        onTriggered: {
            SoundService.play("session-start");
        }
    }

}
