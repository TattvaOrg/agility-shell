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
        function toggle(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = !SettingsService.edgeLightingEnabled;
                return;
            }
            AppState.toggleWidget(widgetId);
        }

        function open(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = true;
                return;
            }
            AppState.openWidget(widgetId);
        }

        function close(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = false;
                return;
            }
            AppState.closeWidget(widgetId);
        }

        target: "widgets"
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

            WlrLayershell.layer: WlrLayer.Background
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

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                onDoubleClicked: (mouse) => {
                    WallpaperManager.cycleNextWallpaper(mouse.x, mouse.y, parent.width, parent.height);
                }
            }
        }
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
