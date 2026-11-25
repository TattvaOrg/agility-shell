import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Core.Services
pragma Singleton

Item {
    id: root

    readonly property bool isNiri: Boolean(Quickshell.env("NIRI_SOCKET")) || String(Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase() === "niri"

    property var runningApps: []
    property var runningAppMap: ({})
    property var rawWindows: []
    property int totalWindowCount: 0

    // Periodic fallback refresh timer (event-driven triggers handle immediate updates)
    Timer {
        id: refreshTimer
        interval: 1500
        running: true
        repeat: true
        onTriggered: {
            root.queryWindows();
        }
    }

    // Short delayed refresh after focus/close actions so compositor state has settled
    Timer {
        id: actionRefreshTimer
        interval: 120
        repeat: false
        onTriggered: {
            root.queryWindows();
        }
    }

    // Reactive triggers for Hyprland
    Connections {
        target: Hyprland
        enabled: !root.isNiri
        function onFocusedWorkspaceChanged() {
            root.queryWindows();
        }
        function onActiveToplevelChanged() {
            root.queryWindows();
        }
        function onRawEvent(event) {
            if (!event || !event.name) return;
            if (event.name === "openwindow" || event.name === "closewindow" || event.name === "movewindow" || event.name === "activewindow" || event.name === "windowtitle") {
                root.queryWindows();
            }
        }
    }

    // Reactive triggers for Niri via AppState's niri event-stream
    Connections {
        target: AppState
        enabled: root.isNiri
        function onNiriActiveTitleChanged() {
            root.queryWindows();
        }
        function onNiriActiveAppIdChanged() {
            root.queryWindows();
        }
        function onHasActiveWindowChanged() {
            root.queryWindows();
        }
    }

    // Ensure launcherApps is populated even if Launcher/Spotlight hasn't been opened yet
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
                        root.rebuildRunningApps();
                    }
                } catch (e) {
                }
            }
        }
    }

    // Windows Query Process
    Process {
        id: queryWindowsProc
        command: root.isNiri ? ["niri", "msg", "-j", "windows"] : ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: windowsOutput
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(windowsOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        root.rawWindows = parsed;
                        root.rebuildRunningApps();
                    }
                } catch (e) {
                }
            }
        }
    }

    function queryWindows() {
        if (!queryWindowsProc.running) {
            queryWindowsProc.running = true;
        }
    }

    function normalizeAppId(rawId) {
        if (!rawId) return "";
        let s = String(rawId).trim().toLowerCase();
        s = s.replace(/\.desktop$/, "");
        return s;
    }

    function execBinaryName(execStr) {
        if (!execStr) return "";
        let cleaned = String(execStr).replace(/%[a-zA-Z]/g, "").trim();
        let parts = cleaned.split(/\s+/);
        for (let i = 0; i < parts.length; i++) {
            let p = parts[i];
            if (!p || p === "env" || p.indexOf("=") !== -1) continue;
            let slash = p.lastIndexOf("/");
            return (slash !== -1 ? p.substring(slash + 1) : p).toLowerCase();
        }
        return "";
    }

    function lastSegment(idStr) {
        let s = normalizeAppId(idStr);
        let dot = s.lastIndexOf(".");
        return dot !== -1 ? s.substring(dot + 1) : s;
    }

    function findLauncherApp(appId) {
        if (!AppState.launcherApps || AppState.launcherApps.length === 0) return null;
        let norm = normalizeAppId(appId);
        if (!norm) return null;
        let normTail = lastSegment(norm);
        let hyphenHead = norm.split("-")[0];

        let partialMatch = null;
        for (let i = 0; i < AppState.launcherApps.length; i++) {
            let item = AppState.launcherApps[i];
            if (!item) continue;

            let itemId = normalizeAppId(item.id || item.desktopId || "");
            let itemName = normalizeAppId(item.name);
            let itemIcon = normalizeAppId(item.icon);
            let itemExecBin = execBinaryName(item.exec);
            let itemWmClass = normalizeAppId(item.startup_wm_class || "");

            // Exact high-confidence matches first
            if ((itemId && itemId === norm)
                || (itemWmClass && itemWmClass === norm)
                || (itemIcon && itemIcon === norm)
                || (itemExecBin && itemExecBin === norm)
                || (itemName && itemName === norm)) {
                return item;
            }

            // Tail segment or hyphen-prefix matches (e.g. "org.gnome.nautilus" <-> "nautilus", "brave-browser" <-> "brave")
            if (!partialMatch) {
                if (normTail.length >= 3 && ((itemExecBin && itemExecBin === normTail)
                    || (itemIcon && lastSegment(itemIcon) === normTail)
                    || (itemName && itemName === normTail))) {
                    partialMatch = item;
                } else if (hyphenHead.length >= 3 && ((itemExecBin && itemExecBin === hyphenHead)
                    || (itemName && itemName === hyphenHead)
                    || (itemIcon && itemIcon.startsWith(hyphenHead + "-")))) {
                    partialMatch = item;
                }
            }
        }
        return partialMatch;
    }

    function findRunningForPinned(pinnedApp) {
        if (!pinnedApp) return null;
        let candidates = [];
        if (pinnedApp.id) candidates.push(normalizeAppId(pinnedApp.id));
        if (pinnedApp.desktopId) candidates.push(normalizeAppId(pinnedApp.desktopId));
        if (pinnedApp.rawClass) candidates.push(normalizeAppId(pinnedApp.rawClass));
        if (pinnedApp.icon) {
            candidates.push(normalizeAppId(pinnedApp.icon));
            candidates.push(lastSegment(pinnedApp.icon));
        }
        if (pinnedApp.exec) {
            let bin = execBinaryName(pinnedApp.exec);
            if (bin) candidates.push(bin);
        }
        if (pinnedApp.name) candidates.push(normalizeAppId(pinnedApp.name));

        for (let i = 0; i < candidates.length; i++) {
            let key = candidates[i];
            if (key && root.runningAppMap[key]) {
                return root.runningAppMap[key];
            }
        }

        // Fallback scan over runningApps comparing tail/name/exec
        let list = root.runningApps || [];
        for (let j = 0; j < list.length; j++) {
            let r = list[j];
            if (!r) continue;
            let rKeys = [
                normalizeAppId(r.id),
                lastSegment(r.id),
                normalizeAppId(r.rawClass),
                normalizeAppId(r.name),
                execBinaryName(r.exec)
            ];
            for (let k = 0; k < candidates.length; k++) {
                if (candidates[k] && rKeys.indexOf(candidates[k]) !== -1) {
                    return r;
                }
            }
        }
        return null;
    }

    function rebuildRunningApps() {
        let appGroups = {};
        let order = [];
        let count = 0;

        for (let i = 0; i < root.rawWindows.length; i++) {
            let win = root.rawWindows[i];
            if (!win) continue;

            let title = String(win.title || "");
            let rawClass = root.isNiri ? (win.app_id || "") : (win.class || win.initialClass || "");
            if (rawClass === "" && title === "") continue;

            let lowerClass = String(rawClass).toLowerCase();
            if (lowerClass.includes("quickshell") || lowerClass.includes("agility-shell")) continue;

            let appId = normalizeAppId(rawClass);
            if (!appId) appId = normalizeAppId(title.split(" ")[0]);
            if (!appId) continue;

            count++;

            let hyprFocused = false;
            if (!root.isNiri) {
                if (win.focusHistoryID === 0) hyprFocused = true;
                else if (Hyprland.activeToplevel && win.address) {
                    let activeAddr = String(Hyprland.activeToplevel.address || "");
                    let winAddr = String(win.address);
                    hyprFocused = (activeAddr === winAddr) || (("0x" + activeAddr) === winAddr);
                }
            }

            let winObj = {
                "address": win.address || "",
                "winId": win.id !== undefined ? win.id : (win.address || ""),
                "title": title,
                "workspace": root.isNiri ? (win.workspace_id || 1) : (win.workspace ? win.workspace.id : 1),
                "isFocused": Boolean(win.focused || win.is_focused || hyprFocused)
            };

            if (!appGroups[appId]) {
                let match = root.findLauncherApp(appId);
                let displayName = match ? match.name : (rawClass.charAt(0).toUpperCase() + rawClass.slice(1));
                let iconName = match ? match.icon : rawClass;
                let execCmd = match ? match.exec : rawClass;
                let inTerminal = match ? Boolean(match.terminal) : false;

                appGroups[appId] = {
                    "id": appId,
                    "rawClass": rawClass,
                    "name": displayName,
                    "icon": iconName,
                    "exec": execCmd,
                    "terminal": inTerminal,
                    "windows": [winObj],
                    "windowCount": 1,
                    "isFocused": winObj.isFocused
                };
                order.push(appId);
            } else {
                appGroups[appId].windows.push(winObj);
                appGroups[appId].windowCount++;
                if (winObj.isFocused) {
                    appGroups[appId].isFocused = true;
                }
            }
        }

        let result = [];
        for (let j = 0; j < order.length; j++) {
            result.push(appGroups[order[j]]);
        }

        root.runningApps = result;
        root.runningAppMap = appGroups;
        root.totalWindowCount = count;
    }

    function focusWindow(win) {
        if (!win) return;
        if (root.isNiri) {
            if (win.winId !== undefined) {
                Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(win.winId)]);
            }
        } else {
            if (win.address) {
                Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + win.address]);
            }
        }
        actionRefreshTimer.restart();
    }

    function closeWindow(win) {
        if (!win) return;
        if (root.isNiri) {
            if (win.winId !== undefined) {
                Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.winId)]);
            }
        } else {
            if (win.address) {
                Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + win.address]);
            }
        }
        root.queryWindows();
        actionRefreshTimer.restart();
    }

    function focusApp(app) {
        if (!app) return;
        let wins = app.windows || [];
        if (wins.length === 0) {
            root.launchApp(app);
            return;
        }

        if (wins.length === 1) {
            root.focusWindow(wins[0]);
            return;
        }

        // Multiple windows: cycle to next window after currently focused one
        let focusedIdx = -1;
        for (let i = 0; i < wins.length; i++) {
            if (wins[i].isFocused) {
                focusedIdx = i;
                break;
            }
        }
        let nextIdx = (focusedIdx + 1) % wins.length;
        root.focusWindow(wins[nextIdx]);
    }

    function launchApp(app) {
        if (!app) return;
        let execCmd = app.exec || app.id;
        if (!execCmd) return;
        execCmd = String(execCmd).replace(/%[a-zA-Z]/g, "").trim();
        let command = ["agl", "launch-exec", execCmd];
        if (app.terminal) {
            command.push("--terminal");
        }
        Quickshell.execDetached(command);
        actionRefreshTimer.restart();
    }

    Component.onCompleted: {
        if (!AppState.launcherApps || AppState.launcherApps.length === 0) {
            loadAppsProc.running = true;
        }
        root.queryWindows();
    }
}
