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
    property alias initialFocusItem: filterField
    property var rawWindows: []
    property var workspaceList: []
    property int activeWorkspaceId: 1
    property string filterQuery: ""

    function refresh() {
        filterField.text = "";
        filterQuery = "";
        queryWindowsProc.running = true;
        if (AppState.isNiri) {
            queryWorkspacesProc.running = true;
        } else {
            if (Hyprland.focusedWorkspace)
                root.activeWorkspaceId = Hyprland.focusedWorkspace.id;
        }
        filterField.forceActiveFocus();
        Qt.callLater(function() {
            filterField.forceActiveFocus();
        });
    }

    function jumpToWorkspace(wsId) {
        if (wsId < 1 || wsId > 10)
            return;
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
        if (AppState.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(win.winId)]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "focuswindow", "address:" + win.address]);
        }
        closeMissionControl();
    }

    function closeWindow(win) {
        if (!win)
            return;
        if (AppState.isNiri) {
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(win.winId)]);
        } else {
            Quickshell.execDetached(["hyprctl", "dispatch", "closewindow", "address:" + win.address]);
        }
        refreshTimer.restart();
    }

    function closeMissionControl() {
        if (root.widget)
            root.widget.isOpen = false;
        else
            AppState.closeWidget("missioncontrol");
    }

    function rebuildWorkspaces() {
        let q = root.filterQuery.toLowerCase();
        let map = {};
        for (let i = 1; i <= 10; i++) {
            map[i] = [];
        }

        for (let i = 0; i < root.rawWindows.length; i++) {
            let w = root.rawWindows[i];
            let title = w.title || "";
            let wClass = w.class || w.app_id || "";
            let wsId = w.workspace ? (w.workspace.id || w.workspace) : (w.workspace_id || 1);
            if (typeof wsId !== "number")
                wsId = parseInt(wsId) || 1;

            if (q === "" || title.toLowerCase().includes(q) || wClass.toLowerCase().includes(q)) {
                if (!map[wsId])
                    map[wsId] = [];
                map[wsId].push({
                    title: title !== "" ? title : wClass,
                    wClass: wClass,
                    address: w.address || "",
                    winId: w.id !== undefined ? w.id : 0,
                    workspace: wsId
                });
            }
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
                        for (let i = 0; i < parsed.length; i++) {
                            let ws = parsed[i];
                            if (ws.is_active || ws.is_focused) {
                                root.activeWorkspaceId = ws.idx !== undefined ? ws.idx : (i + 1);
                                break;
                            }
                        }
                        root.rebuildWorkspaces();
                    }
                } catch (e) {
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Constants.sizeLg

        // ─────────────────────────────────────────────
        // 1. TOP HEADER BAR
        // ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeLg

            // Title & Icon
            RowLayout {
                spacing: Constants.sizeMd

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    radius: 18
                    color: Qt.rgba(0.4, 0.4, 1.0, 0.2)

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "window"
                        iconSize: 20
                        flat: true
                        iconColor: Theme.accent
                    }
                }

                ColumnLayout {
                    spacing: 0
                    Text {
                        text: "Mission Control"
                        font.pixelSize: Constants.fontSizeXl
                        font.weight: Font.Bold
                        color: Theme.text
                    }
                    Text {
                        text: root.rawWindows.length + " active windows across workspaces"
                        font.pixelSize: Constants.fontSizeSm
                        color: Theme.muted
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Search Filter Box
            Rectangle {
                Layout.preferredWidth: 340
                Layout.preferredHeight: 40
                radius: Constants.sizeLg
                color: Theme.bgSecondary
                border.width: filterField.activeFocus ? 2 : 1
                border.color: filterField.activeFocus ? Theme.accent : Theme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Constants.sizeMd
                    anchors.rightMargin: Constants.sizeMd
                    spacing: Constants.sizeSm

                    SvgIcon {
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 16
                        icon: "search"
                        iconSize: 16
                        flat: true
                        iconColor: filterField.activeFocus ? Theme.accent : Theme.muted
                    }

                    TextInput {
                        id: filterField
                        Layout.fillWidth: true
                        font.pixelSize: Constants.fontSizeMd
                        color: Theme.text
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {
                            anchors.fill: parent
                            text: "Filter open windows..."
                            color: Theme.muted
                            font: filterField.font
                            verticalAlignment: Text.AlignVCenter
                            visible: !filterField.text && !filterField.activeFocus
                        }

                        onTextChanged: {
                            root.filterQuery = filterField.text.trim();
                            root.rebuildWorkspaces();
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                root.closeMissionControl();
                                event.accepted = true;
                            } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && !filterField.text) {
                                let num = event.key - Qt.Key_0;
                                root.jumpToWorkspace(num);
                                event.accepted = true;
                            }
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                        radius: 10
                        color: clearHover.containsMouse ? Theme.surfaceHover : "transparent"
                        visible: filterField.text !== ""

                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            font.pixelSize: 11
                            color: Theme.muted
                        }

                        MouseArea {
                            id: clearHover
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: filterField.text = ""
                        }
                    }
                }
            }

            // Close button
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 18
                color: closeBtnMouse.containsMouse ? Theme.surfaceHover : Theme.bgSecondary
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: closeBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeMissionControl()
                }
            }
        }

        // ─────────────────────────────────────────────
        // 2. WORKSPACE TABS SELECTOR
        // ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            radius: Constants.sizeLg
            color: Theme.bgSecondary
            border.width: 1
            border.color: Theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                spacing: Constants.sizeSm

                Repeater {
                    model: 10

                    Rectangle {
                        required property int index
                        readonly property int wsNumber: index + 1
                        readonly property bool isCurrent: wsNumber === root.activeWorkspaceId
                        readonly property int winCount: {
                            for (let i = 0; i < root.workspaceList.length; i++) {
                                if (root.workspaceList[i].workspaceId === wsNumber)
                                    return root.workspaceList[i].windowCount;
                            }
                            return 0;
                        }

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: Constants.sizeMd
                        color: isCurrent ? Theme.accent : (wsTabMouse.containsMouse ? Theme.surfaceHover : "transparent")
                        border.width: isCurrent ? 0 : (winCount > 0 ? 1 : 0)
                        border.color: Theme.border

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: parent.parent.wsNumber.toString()
                                font.pixelSize: Constants.fontSizeMd
                                font.weight: parent.parent.isCurrent ? Font.Bold : Font.DemiBold
                                color: parent.parent.isCurrent ? Theme.bg : Theme.text
                            }

                            // Window count dot / badge
                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: parent.parent.isCurrent ? Theme.bg : Theme.accent
                                visible: parent.parent.winCount > 0
                            }
                        }

                        MouseArea {
                            id: wsTabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.jumpToWorkspace(parent.wsNumber)
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 3. MAIN WORKSPACE OVERVIEW GRID
        // ─────────────────────────────────────────────
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: wsCardsLayout.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: wsCardsLayout
                width: parent.width
                spacing: Constants.sizeLg

                Repeater {
                    model: root.workspaceList

                    Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: cardCol.implicitHeight + 28
                        radius: Constants.sizeXl
                        color: Theme.bgSecondary
                        border.width: modelData.isCurrent ? 2 : 1
                        border.color: modelData.isCurrent ? Theme.accent : Theme.border

                        ColumnLayout {
                            id: cardCol
                            anchors.fill: parent
                            anchors.margins: Constants.sizeLg
                            spacing: Constants.sizeMd

                            // Workspace Card Header
                            RowLayout {
                                Layout.fillWidth: true

                                RowLayout {
                                    spacing: Constants.sizeSm

                                    Rectangle {
                                        Layout.preferredHeight: 24
                                        Layout.preferredWidth: wsBadgeText.implicitWidth + 18
                                        radius: 12
                                        color: modelData.isCurrent ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)

                                        Text {
                                            id: wsBadgeText
                                            anchors.centerIn: parent
                                            text: "WORKSPACE " + modelData.workspaceId
                                            font.pixelSize: 11
                                            font.weight: Font.Bold
                                            color: modelData.isCurrent ? Theme.bg : Theme.text
                                        }
                                    }

                                    Text {
                                        text: modelData.windowCount + (modelData.windowCount === 1 ? " window" : " windows")
                                        font.pixelSize: Constants.fontSizeSm
                                        color: Theme.muted
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Switch to Workspace Button
                                Rectangle {
                                    Layout.preferredHeight: 26
                                    Layout.preferredWidth: switchText.implicitWidth + 20
                                    radius: 13
                                    color: switchHover.containsMouse ? Theme.surfaceHover : "transparent"
                                    border.width: 1
                                    border.color: Theme.border

                                    Text {
                                        id: switchText
                                        anchors.centerIn: parent
                                        text: modelData.isCurrent ? "Active Workspace" : "Switch Here →"
                                        font.pixelSize: 11
                                        font.weight: Font.DemiBold
                                        color: modelData.isCurrent ? Theme.accent : Theme.textSecondary
                                    }

                                    MouseArea {
                                        id: switchHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.jumpToWorkspace(modelData.workspaceId)
                                    }
                                }
                            }

                            // Empty Workspace Placeholder
                            Item {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 70
                                visible: modelData.windowCount === 0

                                Text {
                                    anchors.centerIn: parent
                                    text: "No open windows on this workspace"
                                    font.pixelSize: Constants.fontSizeMd
                                    color: Theme.muted
                                }
                            }

                            // Windows Grid Flow
                            Flow {
                                Layout.fillWidth: true
                                spacing: Constants.sizeMd
                                visible: modelData.windowCount > 0

                                Repeater {
                                    model: modelData.windows

                                    Rectangle {
                                        required property var modelData
                                        width: 260
                                        height: 90
                                        radius: Constants.sizeLg
                                        color: winHover.containsMouse ? Theme.surfaceHover : Qt.rgba(0, 0, 0, 0.25)
                                        border.width: winHover.containsMouse ? 1 : 0
                                        border.color: Theme.accent

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: Constants.sizeMd
                                            spacing: Constants.sizeMd

                                            // App Icon
                                            Item {
                                                Layout.preferredWidth: 42
                                                Layout.preferredHeight: 42

                                                Image {
                                                    id: winIcon
                                                    anchors.fill: parent
                                                    sourceSize: Qt.size(64, 64)
                                                    fillMode: Image.PreserveAspectFit
                                                    source: Quickshell.iconPath(modelData.wClass, true)
                                                    visible: status === Image.Ready
                                                }

                                                SvgIcon {
                                                    anchors.fill: parent
                                                    icon: "window"
                                                    iconSize: 28
                                                    flat: true
                                                    iconColor: Theme.accent
                                                    visible: !winIcon.visible
                                                }
                                            }

                                            // Title & Class
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 2

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.title
                                                    font.pixelSize: Constants.fontSizeMd
                                                    font.weight: Font.DemiBold
                                                    color: Theme.text
                                                    elide: Text.ElideRight
                                                }

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.wClass
                                                    font.pixelSize: Constants.fontSizeSm
                                                    color: Theme.muted
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            // Close window button
                                            Rectangle {
                                                Layout.preferredWidth: 22
                                                Layout.preferredHeight: 22
                                                radius: 11
                                                color: closeWinHover.containsMouse ? Qt.rgba(0.9, 0.2, 0.2, 0.3) : "transparent"
                                                visible: winHover.containsMouse

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    font.pixelSize: 11
                                                    color: closeWinHover.containsMouse ? "#ef4444" : Theme.muted
                                                }

                                                MouseArea {
                                                    id: closeWinHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    onClicked: root.closeWindow(modelData)
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: winHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.focusWindow(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─────────────────────────────────────────────
        // 4. BOTTOM KEYBOARD SHORTCUTS HINTS
        // ─────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: Constants.sizeMd
            color: Theme.bgSecondary

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Constants.sizeMd
                anchors.rightMargin: Constants.sizeMd
                spacing: Constants.sizeLg

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 24; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "1-9"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Jump Workspace"; font.pixelSize: 11; color: Theme.muted }
                }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 24; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Click"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Focus Window"; font.pixelSize: 11; color: Theme.muted }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 30; height: 18; radius: 4
                        color: Theme.surfaceHover
                        border.width: 1; border.color: Theme.border
                        Text { anchors.centerIn: parent; text: "Esc"; font.pixelSize: 10; color: Theme.textSecondary }
                    }
                    Text { text: "Exit"; font.pixelSize: 11; color: Theme.muted }
                }
            }
        }
    }
}
