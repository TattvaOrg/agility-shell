import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var widget: null
    property alias initialFocusItem: keyHandler
    property var rawWindows: []
    property var flatWindows: []
    property var workspaceList: []
    property var niriWorkspaceIdToIdx: ({})
    property int activeWorkspaceId: 1
    property string filterQuery: ""
    property int selectedIndex: 0

    function refresh() {
        if (AppState.isNiri) {
            closeMissionControl();
            Quickshell.execDetached(["niri", "msg", "action", "toggle-overview"]);
            return;
        }
        filterQuery = "";
        queryWindowsProc.running = true;
        if (AppState.isNiri) {
            queryWorkspacesProc.running = true;
        } else {
            if (Hyprland.focusedWorkspace)
                root.activeWorkspaceId = Hyprland.focusedWorkspace.id;
        }
        keyHandler.forceActiveFocus();
        Qt.callLater(function() {
            keyHandler.forceActiveFocus();
        });
    }

    function jumpToWorkspace(wsId) {
        if (wsId < 1 || wsId > 10)
            return;
        SoundService.play("click");
        if (AppState.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(wsId)]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(wsId)]);
        }
        closeMissionControl();
    }

    function focusWindow(win) {
        if (!win)
            return;
        SoundService.play("click");
        if (AppState.isNiri) {
            if (win.workspace) {
                Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(win.workspace)]);
            }
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(win.winId)]);
        } else {
            if (win.workspace) {
                Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(win.workspace)]);
            }
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + win.address]);
        }
        closeMissionControl();
    }

    function closeWindow(win) {
        if (!win)
            return;
        SoundService.play("click");
        if (AppState.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.winId)]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + win.address]);
        }
        refreshTimer.restart();
    }

    function closeMissionControl() {
        if (root.widget && typeof root.widget.close === "function")
            root.widget.close();
        else
            AppState.closeWidget("missioncontrol");
    }

    function formatAppName(wClass, title) {
        if (!wClass || wClass === "") {
            if (title && title !== "") {
                let p = title.split(" — ")[0].split(" - ")[0].trim();
                if (p.length > 0) return p;
            }
            return "Application";
        }
        let clean = wClass;
        if (clean.includes(".")) {
            let parts = clean.split(".");
            clean = parts[parts.length - 1];
        }
        let lower = clean.toLowerCase();
        if (lower === "google-chrome") return "Google Chrome";
        if (lower === "chromium") return "Chromium";
        if (lower === "code" || lower === "codium") return "VS Code";
        if (lower === "firefox") return "Firefox";
        if (lower === "nautilus" || lower === "org.gnome.nautilus") return "Files";
        if (lower === "thunar") return "Thunar Files";
        if (lower === "alacritty") return "Alacritty";
        if (lower === "kitty") return "Kitty";
        if (lower === "foot") return "Foot Terminal";
        if (lower === "wezterm" || lower === "org.wezfurlong.wezterm") return "WezTerm";
        if (lower === "discord") return "Discord";
        if (lower === "spotify") return "Spotify";
        if (lower === "slack") return "Slack";
        if (lower === "steam") return "Steam";
        if (lower === "mpv") return "MPV Player";
        return clean.charAt(0).toUpperCase() + clean.slice(1);
    }

    function isTerminalApp(wClass) {
        if (!wClass) return false;
        let lower = wClass.toLowerCase();
        return lower.includes("alacritty") || lower.includes("kitty") || lower.includes("foot") ||
               lower.includes("wezterm") || lower.includes("terminal") || lower.includes("konsole");
    }

    function isBrowserApp(wClass) {
        if (!wClass) return false;
        let lower = wClass.toLowerCase();
        return lower.includes("brave") || lower.includes("firefox") || lower.includes("chrome") ||
               lower.includes("chromium") || lower.includes("zen") || lower.includes("vivaldi");
    }

    function isCodeApp(wClass) {
        if (!wClass) return false;
        let lower = wClass.toLowerCase();
        return lower.includes("code") || lower.includes("codium") || lower.includes("zed") ||
               lower.includes("cursor") || lower.includes("neovim") || lower.includes("sublime");
    }

    function getWorkspaceColor(wsId) {
        let colors = [
            "#3b82f6", "#10b981", "#f59e0b", "#ec4899", "#8b5cf6",
            "#06b6d4", "#f97316", "#6366f1", "#14b8a6", "#e11d48"
        ];
        let idx = ((wsId || 1) - 1) % colors.length;
        if (idx < 0) idx = 0;
        return colors[idx];
    }

    function rebuildWorkspaces() {
        let q = root.filterQuery.toLowerCase();
        let flat = [];
        let map = {};
        for (let i = 1; i <= 10; i++) {
            map[i] = [];
        }

        for (let i = 0; i < root.rawWindows.length; i++) {
            let w = root.rawWindows[i];
            let title = w.title || "";
            let wClass = w.class || w.app_id || "";
            let rawWsId = w.workspace ? (w.workspace.id || w.workspace) : (w.workspace_id || 1);
            let wsId = rawWsId;
            if (AppState.isNiri && root.niriWorkspaceIdToIdx[rawWsId] !== undefined) {
                wsId = root.niriWorkspaceIdToIdx[rawWsId];
            }
            if (typeof wsId !== "number")
                wsId = parseInt(wsId) || 1;

            if (q === "" || title.toLowerCase().includes(q) || wClass.toLowerCase().includes(q)) {
                let winObj = {
                    title: title !== "" ? title : wClass,
                    wClass: wClass,
                    address: w.address || "",
                    winId: w.id !== undefined ? w.id : 0,
                    workspace: wsId,
                    isCurrentWs: wsId === root.activeWorkspaceId,
                    isFocused: w.focused || w.is_focused || false
                };
                flat.push(winObj);

                if (!map[wsId])
                    map[wsId] = [];
                map[wsId].push(winObj);
            }
        }

        root.flatWindows = flat;

        if (flat.length > 1) {
            root.selectedIndex = 1;
        } else {
            root.selectedIndex = 0;
        }

        let list = [];
        for (let i = 1; i <= 10; i++) {
            let wins = map[i] || [];
            if (wins.length > 0 || i === root.activeWorkspaceId || i <= 4) {
                list.push({
                    workspaceId: i,
                    windows: wins,
                    isCurrent: i === root.activeWorkspaceId,
                    windowCount: wins.length
                });
            }
        }
        root.workspaceList = list;
    }

    Timer {
        id: refreshTimer
        interval: 150
        repeat: false
        onTriggered: {
            queryWindowsProc.running = true;
        }
    }

    // Windows query process
    Process {
        id: queryWindowsProc
        command: AppState.isNiri ? ["niri", "msg", "-j", "windows"] : ["hyprctl", "clients", "-j"]

        stdout: StdioCollector {
            id: windowsOutput
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(windowsOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        root.rawWindows = parsed;
                        root.rebuildWorkspaces();
                    }
                } catch (e) {
                }
            }
        }
    }

    // Niri workspaces query process
    Process {
        id: queryWorkspacesProc
        command: ["niri", "msg", "-j", "workspaces"]

        stdout: StdioCollector {
            id: workspacesOutput
        }

        onExited: function(exitCode) {
            if (exitCode === 0) {
                try {
                    let parsed = JSON.parse(workspacesOutput.text.trim());
                    if (Array.isArray(parsed)) {
                        let idToIdx = {};
                        for (let i = 0; i < parsed.length; i++) {
                            let ws = parsed[i];
                            let idx = ws.idx !== undefined ? ws.idx : (i + 1);
                            if (ws.id !== undefined) {
                                idToIdx[ws.id] = idx;
                            }
                            if (ws.is_active || ws.is_focused) {
                                root.activeWorkspaceId = idx;
                            }
                        }
                        root.niriWorkspaceIdToIdx = idToIdx;
                        root.rebuildWorkspaces();
                    }
                } catch (e) {
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // GLOBAL KEYBOARD NAVIGATION HANDLER
    // ─────────────────────────────────────────────
    Item {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            let n = root.flatWindows.length;
            if (n === 0) {
                if (event.key === Qt.Key_Escape) {
                    root.closeMissionControl();
                    event.accepted = true;
                }
                return;
            }

            let cols = Math.max(1, exposGrid.columns);

            if (event.key === Qt.Key_Tab) {
                if (event.modifiers & Qt.ShiftModifier) {
                    root.selectedIndex = (root.selectedIndex - 1 + n) % n;
                } else {
                    root.selectedIndex = (root.selectedIndex + 1) % n;
                }
                SoundService.play("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                root.selectedIndex = (root.selectedIndex - 1 + n) % n;
                SoundService.play("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                root.selectedIndex = (root.selectedIndex + 1) % n;
                SoundService.play("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                root.selectedIndex = (root.selectedIndex - 1 + n) % n;
                SoundService.play("click");
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (n > cols) {
                    root.selectedIndex = Math.min(n - 1, root.selectedIndex + cols);
                    SoundService.play("click");
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (n > cols) {
                    root.selectedIndex = Math.max(0, root.selectedIndex - cols);
                    SoundService.play("click");
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                if (root.flatWindows[root.selectedIndex]) {
                    root.focusWindow(root.flatWindows[root.selectedIndex]);
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                root.closeMissionControl();
                event.accepted = true;
            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                let idx = event.key - Qt.Key_1;
                if (idx < n) {
                    root.selectedIndex = idx;
                    root.focusWindow(root.flatWindows[idx]);
                    event.accepted = true;
                }
            }
        }
    }

    // ─────────────────────────────────────────────
    // FULLSCREEN CLEAN WINDOW OVERVIEW (NO TOP BAR)
    // ─────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: 40

        // Empty state placeholder
        Item {
            anchors.centerIn: parent
            visible: root.flatWindows.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12

                SvgIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: "window"
                    iconSize: 56
                    flat: true
                    iconColor: Theme.muted
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Active Windows"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: Theme.fg
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Press Esc to return"
                    font.pixelSize: 12
                    color: Theme.muted
                }
            }
        }

        // Exposé Window Spread Area
        Flickable {
            anchors.fill: parent
            clip: true
            visible: root.flatWindows.length > 0
            contentWidth: width
            contentHeight: Math.max(height, exposGrid.height + 60)
            boundsBehavior: Flickable.StopAtBounds

            Item {
                anchors.centerIn: parent
                width: exposGrid.width
                height: exposGrid.height

                Grid {
                    id: exposGrid
                    anchors.centerIn: parent
                    rowSpacing: 28
                    columnSpacing: 28

                    // Clean columns calculation:
                    // 1 window -> 1 col; 2 windows -> 2 cols; 3 windows -> 3 cols; 4 windows -> 2 cols (2x2); etc.
                    columns: {
                        let n = root.flatWindows.length;
                        if (n <= 1) return 1;
                        if (n === 2) return 2;
                        if (n === 3) return 3;
                        if (n === 4) return 2;
                        if (n <= 6) return 3;
                        if (n <= 8) return 4;
                        return Math.min(5, Math.ceil(Math.sqrt(n * 1.4)));
                    }

                    // Responsive card dimensions to give windows realistic desktop proportions
                    readonly property real targetCardWidth: {
                        let cols = columns;
                        let maxW = parent.parent.width - 64;
                        let computed = (maxW - (cols - 1) * columnSpacing) / cols;
                        let n = root.flatWindows.length;
                        if (n === 1) return 560;
                        if (n === 2) return 460;
                        if (n === 3) return Math.round(Math.min(420, Math.max(300, computed)));
                        return Math.round(Math.min(380, Math.max(260, computed)));
                    }

                    readonly property real targetCardHeight: Math.round(targetCardWidth * 0.62)

                    Repeater {
                        model: root.flatWindows

                        Item {
                            id: cardWrapper
                            required property var modelData
                            required property int index
                            readonly property bool isSelected: root.selectedIndex === index
                            readonly property bool isTerminal: root.isTerminalApp(modelData.wClass)
                            readonly property bool isBrowser: root.isBrowserApp(modelData.wClass)
                            readonly property bool isCode: root.isCodeApp(modelData.wClass)

                            width: exposGrid.targetCardWidth
                            height: exposGrid.targetCardHeight

                            // ── SCALED MINIATURE WINDOW ──
                            Rectangle {
                                id: windowFrame
                                anchors.fill: parent
                                radius: 10
                                scale: cardWrapper.isSelected ? 1.04 : (cardMouse.containsMouse ? 1.02 : 1.0)
                                color: cardWrapper.isSelected
                                    ? Qt.rgba(0.09, 0.11, 0.17, 0.98)
                                    : (cardMouse.containsMouse ? Qt.rgba(0.08, 0.10, 0.15, 0.95) : Qt.rgba(0.06, 0.07, 0.11, 0.92))
                                border.width: 1
                                border.color: cardWrapper.isSelected ? Qt.rgba(1, 1, 1, 0.25) : (cardMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.2) : Qt.rgba(1, 1, 1, 0.10))

                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    // ── REALISTIC SUBTLE WINDOW TITLEBAR (Clean, No fake traffic lights) ──
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 26
                                        color: Qt.rgba(0, 0, 0, 0.35)
                                        radius: 10

                                        // Square off bottom corners so only top is rounded
                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            height: 6
                                            color: parent.color
                                        }

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 8
                                            anchors.rightMargin: 8
                                            spacing: 6

                                            Image {
                                                width: 14
                                                height: 14
                                                sourceSize: Qt.size(28, 28)
                                                fillMode: Image.PreserveAspectFit
                                                source: Quickshell.iconPath(cardWrapper.modelData.wClass, true)
                                                visible: status === Image.Ready
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: cardWrapper.modelData.title || cardWrapper.modelData.wClass
                                                font.pixelSize: 10
                                                font.weight: Font.DemiBold
                                                color: cardWrapper.isSelected ? Theme.accent : Theme.fg
                                                elide: Text.ElideRight
                                            }

                                            // Minimal Workspace Indicator
                                            Rectangle {
                                                Layout.preferredHeight: 14
                                                Layout.preferredWidth: wsNumTxt.implicitWidth + 8
                                                radius: 4
                                                color: Qt.rgba(1, 1, 1, 0.08)

                                                Text {
                                                    id: wsNumTxt
                                                    anchors.centerIn: parent
                                                    text: "WS " + cardWrapper.modelData.workspace
                                                    font.pixelSize: 8
                                                    color: Theme.muted
                                                }
                                            }
                                        }
                                    }

                                    // ── AUTHENTIC MINIATURE WINDOW CANVAS ──
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: cardWrapper.isTerminal ? "#0b0d13" : Qt.rgba(0, 0, 0, 0.20)
                                        radius: 8

                                        // 1. TERMINAL CONTENT (Real terminal look with prompt lines)
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 5
                                            visible: cardWrapper.isTerminal

                                            RowLayout {
                                                spacing: 4
                                                Text {
                                                    text: "cachy@arch:"
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                    font.weight: Font.Bold
                                                    color: "#22c55e"
                                                }
                                                Text {
                                                    text: "~"
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                    color: "#38bdf8"
                                                }
                                                Text {
                                                    text: "$"
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                    color: "#94a3b8"
                                                }
                                                Text {
                                                    text: {
                                                        let t = cardWrapper.modelData.title;
                                                        if (t && t.includes(":")) {
                                                            let parts = t.split(":");
                                                            return parts[parts.length - 1].trim();
                                                        }
                                                        return "exec " + cardWrapper.modelData.wClass.toLowerCase();
                                                    }
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                    color: "#e2e8f0"
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                            }

                                            // Monospace terminal text lines
                                            Rectangle {
                                                Layout.preferredWidth: parent.width * 0.75
                                                Layout.preferredHeight: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.15)
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: parent.width * 0.55
                                                Layout.preferredHeight: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.10)
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: parent.width * 0.85
                                                Layout.preferredHeight: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.12)
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: parent.width * 0.40
                                                Layout.preferredHeight: 3
                                                radius: 1.5
                                                color: Qt.rgba(1, 1, 1, 0.08)
                                            }

                                            Item { Layout.fillHeight: true }

                                            // Bottom terminal prompt with blinking cursor
                                            RowLayout {
                                                spacing: 4
                                                Text {
                                                    text: "cachy@arch:~$ "
                                                    font.pixelSize: 9
                                                    font.family: "monospace"
                                                    color: "#22c55e"
                                                }
                                                Rectangle {
                                                    width: 6
                                                    height: 10
                                                    color: "#38bdf8"
                                                }
                                            }
                                        }

                                        // 2. CODE EDITOR CONTENT (VS Code / Zed mockup)
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 10
                                            spacing: 6
                                            visible: cardWrapper.isCode

                                            Repeater {
                                                model: 5
                                                RowLayout {
                                                    spacing: 8
                                                    Text {
                                                        text: String(index + 1)
                                                        font.pixelSize: 8
                                                        font.family: "monospace"
                                                        color: Qt.rgba(1, 1, 1, 0.25)
                                                    }
                                                    Rectangle {
                                                        Layout.preferredWidth: (index % 2 === 0 ? 140 : 90) + (index * 15)
                                                        Layout.preferredHeight: 4
                                                        radius: 2
                                                        color: index === 0 ? "#60a5fa" : (index === 2 ? "#f472b6" : Qt.rgba(1, 1, 1, 0.2))
                                                    }
                                                }
                                            }
                                            Item { Layout.fillHeight: true }
                                        }

                                        // 3. BROWSER CONTENT (URL bar & page)
                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 8
                                            visible: cardWrapper.isBrowser

                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 18
                                                radius: 4
                                                color: Qt.rgba(1, 1, 1, 0.08)

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6
                                                    anchors.rightMargin: 6
                                                    spacing: 4

                                                    Text {
                                                        text: "🔒"
                                                        font.pixelSize: 8
                                                    }
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: cardWrapper.modelData.title
                                                        font.pixelSize: 8
                                                        color: Theme.muted
                                                        elide: Text.ElideRight
                                                    }
                                                }
                                            }

                                            Item { Layout.fillHeight: true }

                                            Image {
                                                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                                width: 38
                                                height: 38
                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectFit
                                                source: Quickshell.iconPath(cardWrapper.modelData.wClass, true)
                                                opacity: 0.35
                                            }

                                            Item { Layout.fillHeight: true }
                                        }

                                        // 4. GENERIC APP CONTENT (Centered App Icon)
                                        Item {
                                            anchors.fill: parent
                                            visible: !cardWrapper.isTerminal && !cardWrapper.isBrowser && !cardWrapper.isCode

                                            Image {
                                                anchors.centerIn: parent
                                                width: 48
                                                height: 48
                                                sourceSize: Qt.size(96, 96)
                                                fillMode: Image.PreserveAspectFit
                                                source: Quickshell.iconPath(cardWrapper.modelData.wClass, true)
                                                visible: status === Image.Ready
                                                opacity: 0.8
                                            }

                                            SvgIcon {
                                                anchors.centerIn: parent
                                                icon: "window"
                                                iconSize: 42
                                                flat: true
                                                iconColor: Theme.accent
                                                visible: status !== Image.Ready
                                                opacity: 0.6
                                            }
                                        }
                                    }
                                }
                            }

                            // Click & Hover Interaction
                            MouseArea {
                                id: cardMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPositionChanged: {
                                    root.selectedIndex = cardWrapper.index;
                                }
                                onClicked: {
                                    root.focusWindow(cardWrapper.modelData);
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // MINIMAL BOTTOM SHORTCUT HINT (Clean & Unobtrusive)
        // ─────────────────────────────────────────────
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            height: 26
            width: hintRow.implicitWidth + 24
            radius: 13
            color: Qt.rgba(0.06, 0.08, 0.12, 0.65)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.08)

            RowLayout {
                id: hintRow
                anchors.centerIn: parent
                spacing: 12

                Text {
                    text: root.flatWindows.length + (root.flatWindows.length === 1 ? " window" : " windows")
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    color: Theme.accent
                }

                Rectangle { width: 1; height: 10; color: Qt.rgba(1, 1, 1, 0.15) }

                Text {
                    text: "↵ Focus   ⇥ Cycle   Esc Close"
                    font.pixelSize: 9
                    color: Theme.muted
                }
            }
        }
    }
}
