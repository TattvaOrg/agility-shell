//@ pragma ShellId agility-shell
//@ pragma AppId agility-shell
//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Core
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Bar
import qs.Modules.Bar.Styles.Convex
import qs.Modules.Bar.Styles.Gaming
import qs.Modules.DesktopCanvas
import qs.Modules.OSD
import qs.modules.common
import qs.services
import qs.panelFamilies
import qs

ShellRoot {
    id: root

    readonly property bool isGaming: DisplayProfileService.gameModeActive
    readonly property bool isConvex: SettingsService.barStyle === "convex"

    // ─── Dots-Hyprland Material Theme Panel Families ───
    property var families: ["ii", "waffle"]

    function cyclePanelFamily() {
        const currentFamily = (SettingsService.desktopPreset === "bottom_waffle" || (Config.options && Config.options.panelFamily === "waffle")) ? "waffle" : "ii";
        const nextFamily = currentFamily === "ii" ? "waffle" : "ii";
        if (nextFamily === "waffle") {
            SettingsService.applyDesktopPreset("bottom_waffle");
        } else {
            SettingsService.applyDesktopPreset("full_canvas");
        }
        if (Config.options) Config.options.panelFamily = nextFamily;
    }

    component PanelFamilyLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: SettingsService.settingsLoaded && SettingsService.systemTheme === "material" && (
            identifier === "waffle" ? (SettingsService.desktopPreset === "bottom_waffle" || (Config.options && Config.options.panelFamily === "waffle"))
                                   : (SettingsService.desktopPreset !== "bottom_waffle" && (!Config.options || Config.options.panelFamily !== "waffle"))
        ) && extraCondition
    }

    IpcHandler {
        target: "osd"

        function volume(val: string) {
            if (SettingsService.systemTheme === "material") {
                GlobalStates.osdVolumeOpen = true;
            } else {
                OsdService.showVolume(val);
            }
        }

        function brightness(val: string) {
            if (SettingsService.systemTheme === "material") {
                GlobalStates.osdBrightnessOpen = true;
            } else {
                OsdService.showBrightness(val);
            }
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

        function toggle(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = !SettingsService.edgeLightingEnabled;
                return;
            }
            if (SettingsService.systemTheme === "material") {
                if (widgetId === "launcher") {
                    if (SettingsService.desktopPreset === "bottom_waffle") {
                        GlobalStates.searchOpen = !GlobalStates.searchOpen;
                    } else {
                        GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
                    }
                    return;
                }
                if (widgetId === "controlCenter" || widgetId === "notificationsCenter") {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                    return;
                }
                if (widgetId === "powerMenu") {
                    GlobalStates.sessionOpen = !GlobalStates.sessionOpen;
                    return;
                }
                if (widgetId === "wallpaper") {
                    GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen;
                    return;
                }
                if (widgetId === "cheatsheet" || widgetId === "minflair_keybinds") {
                    GlobalStates.overlayOpen = !GlobalStates.overlayOpen;
                    return;
                }
            }
            AppState.toggleWidget(widgetId);
        }

        function open(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = true;
                return;
            }
            if (SettingsService.systemTheme === "material") {
                if (widgetId === "launcher") {
                    if (SettingsService.desktopPreset === "bottom_waffle") {
                        GlobalStates.searchOpen = true;
                    } else {
                        GlobalStates.sidebarLeftOpen = true;
                    }
                    return;
                }
                if (widgetId === "controlCenter" || widgetId === "notificationsCenter") {
                    GlobalStates.sidebarRightOpen = true;
                    return;
                }
                if (widgetId === "powerMenu") {
                    GlobalStates.sessionOpen = true;
                    return;
                }
                if (widgetId === "wallpaper") {
                    GlobalStates.wallpaperSelectorOpen = true;
                    return;
                }
            }
            AppState.openWidget(widgetId);
        }

        function close(widgetId: string) {
            if (widgetId === "edgelight" || widgetId === "edgelighting") {
                SettingsService.edgeLightingEnabled = false;
                return;
            }
            if (SettingsService.systemTheme === "material") {
                if (widgetId === "launcher") {
                    GlobalStates.sidebarLeftOpen = false;
                    GlobalStates.searchOpen = false;
                    return;
                }
                if (widgetId === "controlCenter" || widgetId === "notificationsCenter") {
                    GlobalStates.sidebarRightOpen = false;
                    return;
                }
                if (widgetId === "powerMenu") {
                    GlobalStates.sessionOpen = false;
                    return;
                }
                if (widgetId === "wallpaper") {
                    GlobalStates.wallpaperSelectorOpen = false;
                    return;
                }
            }
            AppState.closeWidget(widgetId);
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
        visible: SettingsService.settingsLoaded && !root.isGaming && SettingsService.systemTheme !== "material"

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
        visible: SettingsService.settingsLoaded && !root.isConvex && !root.isGaming && SettingsService.systemTheme !== "material"
    }

    ConvexDesktop {
        id: convexDesktopSurface

        notificationService: globalNotificationService
        visible: SettingsService.settingsLoaded && root.isConvex && !root.isGaming && SettingsService.systemTheme !== "material"
    }

    // ─── Dots-Hyprland Material Theme Integration ───
    ReloadPopup {}

    PanelFamilyLoader {
        identifier: "ii"
        component: IllogicalImpulseFamily {}
    }

    PanelFamilyLoader {
        identifier: "waffle"
        component: WaffleFamily {}
    }

    IpcHandler {
        target: "panelFamily"

        function cycle() {
            root.cyclePanelFamily();
        }
    }

    GlobalShortcut {
        name: "panelFamilyCycle"
        description: "Cycles panel family"

        onPressed: root.cyclePanelFamily()
    }

    Variants {
        model: Quickshell.screens

        DesktopCanvas {
            required property var modelData
            screen: modelData
        }
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
            visible: SettingsService.settingsLoaded && HyprlandService.wpClicksEnabled && SettingsService.systemTheme !== "material"

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

    OsdPill {
        id: osdPillWindow
        visible: SettingsService.settingsLoaded && SettingsService.systemTheme !== "material"
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

    Component.onCompleted: {
        if (SettingsService.systemTheme === "material") {
            MaterialThemeLoader.reapplyTheme();
            Hyprsunset.load();
            FirstRunExperience.load();
            ConflictKiller.load();
            Cliphist.refresh();
            Wallpapers.load();
            Updates.load();
        }
    }

    Connections {
        target: SettingsService
        function onSystemThemeChanged() {
            if (SettingsService.systemTheme === "material") {
                MaterialThemeLoader.reapplyTheme();
                Hyprsunset.load();
                FirstRunExperience.load();
                ConflictKiller.load();
                Cliphist.refresh();
                Wallpapers.load();
                Updates.load();
            }
        }
    }
}
