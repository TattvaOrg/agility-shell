import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: appState

    property string activeWidget: ""
    property var activeWidgetsList: []
    readonly property bool isFocusWidgetOpen: isWidgetOpen("launcher") || isWidgetOpen("clipboard") || isWidgetOpen("wallpaper") || isWidgetOpen("powerMenu") || isWidgetOpen("screenshot")
    property int pendingSettingsTab: -1
    property var launcherApps: []
    property bool socketsCleaned: true
    property real islandWidth: 180
    property real islandHeight: Constants.size3Xl
    property alias barIslandWidth: appState.islandWidth
    property alias barIslandHeight: appState.islandHeight
    property bool isIslandOpen: false
    property bool isConvexOpen: false
    property real barConvexWidth: 220
    property real barConvexHeight: Constants.size4Xl
    property var activeTrayItem: null
    property bool hasActiveNotification: false
    property real activeNotificationWidth: 0
    property real activeNotificationHeight: 0
    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== undefined || Quickshell.env("XDG_CURRENT_DESKTOP") === "niri"
    property bool hasActiveWindow: false
    property string niriActiveTitle: ""
    property string niriActiveAppId: ""
    readonly property string activeWindowTitle: isNiri ? niriActiveTitle : (Hyprland.activeWindow ? (Hyprland.activeWindow.title || "") : "")
    readonly property string activeWindowClass: isNiri ? niriActiveAppId : (Hyprland.activeWindow ? (Hyprland.activeWindow.class || Hyprland.activeWindow.initialClass || "") : "")
    readonly property bool hasWindowOnScreen: isNiri ? hasActiveWindow : Boolean(Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.toplevelCount > 0)
    readonly property var focusWidgets: ["launcher", "clipboard", "wallpaper", "screenshot", "powerMenu"]
    readonly property var standaloneWindows: ["minflair_settings", "minflair_keybinds", "packagemanager"]

    signal toggleWidget(string widgetId)
    signal openWidget(string widgetId)

    function isBarWidget(id) {
        if (!id)
            return false;

        return id === "dashboard" || id === "controlCenter" || id === "notificationsCenter" || id === "music" || id === "clock" || id === "weather" || id.startsWith("systemTray_");
    }

    function isFocusWidget(id) {
        return focusWidgets.indexOf(id) !== -1;
    }

    function isBarOverlayWidget(id) {
        return isFocusWidget(id) || isBarWidget(id);
    }

    function isStandaloneWindow(id) {
        return standaloneWindows.indexOf(id) !== -1;
    }

    function isWidgetOpen(id) {
        if (!id || isStandaloneWindow(id))
            return false;

        if (activeWidget === id)
            return true;

        return activeWidgetsList.indexOf(id) !== -1;
    }

    function getSlot(widgetId, barStyle) {
        if (isFocusWidget(widgetId))
            return "focus";

        let s = barStyle || SettingsService.barStyle;
        if (s === "island")
            return "center";

        // convex
        if (widgetId === "dashboard")
            return "left";

        if (widgetId === "music")
            return "center";

        if (widgetId === "controlCenter" || widgetId === "notificationsCenter" || widgetId === "clock" || widgetId.startsWith("systemTray_"))
            return "right";

        return widgetId;
    }

    function closeWidget(widgetId) {
        if (!widgetId)
            return ;

        if (widgetId.startsWith("systemTray_") || activeWidget === widgetId)
            activeTrayItem = null;

        let idx = activeWidgetsList.indexOf(widgetId);
        if (idx !== -1) {
            let next = activeWidgetsList.slice();
            next.splice(idx, 1);
            activeWidgetsList = next;
        }
        if (activeWidget === widgetId)
            activeWidget = "";

    }

    function closeAllWidgets() {
        activeTrayItem = null;
        activeWidgetsList = [];
        activeWidget = "";
    }

    function openWidgetInternal(widgetId) {
        if (!widgetId || isStandaloneWindow(widgetId))
            return ;

        let slot = getSlot(widgetId);
        // Rule 1: Focus widgets close each other, but do NOT close bar widgets
        if (slot === "focus") {
            let next = [];
            for (let i = 0; i < activeWidgetsList.length; i++) {
                let item = activeWidgetsList[i];
                if (isFocusWidget(item))
                    continue;

                next.push(item);
            }
            next.push(widgetId);
            activeWidgetsList = next;
            activeWidget = widgetId;
            return ;
        }
        // Rule 2: Opening a bar widget closes widgets in the same slot, but keeps focus widgets open
        let next = [];
        for (let i = 0; i < activeWidgetsList.length; i++) {
            let item = activeWidgetsList[i];
            if (getSlot(item) === slot)
                continue;

            next.push(item);
        }
        if (next.indexOf(widgetId) === -1)
            next.push(widgetId);

        activeWidgetsList = next;
        activeWidget = widgetId;
    }

    function toggleWidgetInternal(widgetId) {
        if (!widgetId) {
            closeAllWidgets();
            return ;
        }
        if (isStandaloneWindow(widgetId))
            return ;

        if (isWidgetOpen(widgetId))
            closeWidget(widgetId);
        else
            openWidgetInternal(widgetId);
    }

    onActiveWidgetChanged: {
        if (activeWidget === "") {
            let next = [];
            for (let i = 0; i < activeWidgetsList.length; i++) {
                let item = activeWidgetsList[i];
                if (isFocusWidget(item))
                    next.push(item);

            }
            if (next.length !== activeWidgetsList.length)
                activeWidgetsList = next;

        } else {
            if (activeWidgetsList.indexOf(activeWidget) === -1)
                openWidgetInternal(activeWidget);

        }
    }
    onToggleWidget: (widgetId) => {
        toggleWidgetInternal(widgetId);
    }
    onOpenWidget: (widgetId) => {
        openWidgetInternal(widgetId);
    }

    // ─── Niri IPC Engine for Window Presence Tracking ───
    Process {
        id: niriQueryProc

        command: ["niri", "msg", "-j", "workspaces"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let list = JSON.parse(data.trim());
                    if (!Array.isArray(list))
                        return;

                    let hasWin = false;
                    for (let i = 0; i < list.length; i++) {
                        let ws = list[i];
                        if (ws.is_active || ws.is_focused) {
                            if (ws.active_window_id !== null && ws.active_window_id !== undefined)
                                hasWin = true;
                        }
                    }
                    appState.hasActiveWindow = hasWin;
                } catch (e) {
                }
            }
        }
    }

    Process {
        id: niriEventStreamProc

        command: ["niri", "msg", "event-stream"]

        stdout: SplitParser {
            onRead: (line) => {
                if (!line)
                    return;
                if (line.includes("Workspace") || line.includes("Window")) {
                    niriDebounceTimer.restart();
                }
            }
        }
    }

    Process {
        id: niriFocusedWindowProc

        command: ["niri", "msg", "-j", "focused-window"]

        stdout: SplitParser {
            onRead: (data) => {
                if (!data)
                    return;
                try {
                    let win = JSON.parse(data.trim());
                    if (win && win.id !== undefined) {
                        appState.niriActiveTitle = win.title || "";
                        appState.niriActiveAppId = win.app_id || "";
                    } else {
                        appState.niriActiveTitle = "";
                        appState.niriActiveAppId = "";
                    }
                } catch (e) {
                    appState.niriActiveTitle = "";
                    appState.niriActiveAppId = "";
                }
            }
        }
    }

    Timer {
        id: niriDebounceTimer

        interval: 50
        repeat: false
        onTriggered: {
            if (appState.isNiri) {
                if (!niriQueryProc.running)
                    niriQueryProc.running = true;
                if (!niriFocusedWindowProc.running)
                    niriFocusedWindowProc.running = true;
            }
        }
    }

    Timer {
        id: niriPollTimer

        interval: 2000
        repeat: true
        running: appState.isNiri
        triggeredOnStart: true
        onTriggered: {
            if (!niriQueryProc.running)
                niriQueryProc.running = true;
            if (!niriFocusedWindowProc.running)
                niriFocusedWindowProc.running = true;
        }
    }

    Component.onCompleted: {
        if (appState.isNiri) {
            niriQueryProc.running = true;
            niriFocusedWindowProc.running = true;
            niriEventStreamProc.running = true;
        }
    }
}
