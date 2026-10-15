import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property real prevRxBytes: 0
    property real prevTxBytes: 0
    property real prevTimestamp: 0
    property string downSpeedText: "0K"
    property string upSpeedText: "0K"
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed
    readonly property bool isVisible: SettingsService.appletNetwork

    function formatSpeed(bytesPerSec) {
        if (bytesPerSec < 1024)
            return Math.round(bytesPerSec) + "B";
        if (bytesPerSec < 1024 * 1024)
            return Math.round(bytesPerSec / 1024) + "K";
        return (bytesPerSec / (1024 * 1024)).toFixed(1) + "M";
    }

    implicitHeight: SettingsService.barWidgetHeight
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    implicitWidth: isVisible ? (contentRow.implicitWidth + Constants.sizeSm * 2) : 0
    width: implicitWidth
    opacity: isVisible ? 1 : 0
    visible: isVisible || opacity > 0.001
    clip: true

    radius: height / 2
    color: isHovered ? Theme.bgSecondary : "transparent"
    border.color: isHovered ? Theme.borderSecondary : "transparent"
    border.width: 1
    scale: isPressed ? 0.96 : (isHovered ? 1.02 : 1)

    Behavior on width {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Process {
        id: netProc
        command: ["sh", "-c", "awk 'NR>2 {rx+=$2; tx+=$10} END {print rx, tx}' /proc/net/dev"]

        stdout: SplitParser {
            onRead: (line) => {
                if (!line) return;
                let parts = line.trim().split(/\s+/);
                if (parts.length >= 2) {
                    let rx = parseFloat(parts[0]) || 0;
                    let tx = parseFloat(parts[1]) || 0;
                    let now = Date.now();

                    if (root.prevTimestamp > 0 && now > root.prevTimestamp) {
                        let dt = (now - root.prevTimestamp) / 1000;
                        let rxRate = Math.max(0, (rx - root.prevRxBytes) / dt);
                        let txRate = Math.max(0, (tx - root.prevTxBytes) / dt);
                        root.downSpeedText = root.formatSpeed(rxRate);
                        root.upSpeedText = root.formatSpeed(txRate);
                    }

                    root.prevRxBytes = rx;
                    root.prevTxBytes = tx;
                    root.prevTimestamp = now;
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.isVisible
        triggeredOnStart: true
        onTriggered: {
            if (!netProc.running)
                netProc.running = true;
        }
    }

    Timer {
        id: hoverTimer

        interval: 160
        repeat: false
        onTriggered: {
            if (SettingsService.barOpenOnHover && root.isHovered && !AppState.isWidgetOpen("controlCenter")) {
                AppState.openWidget("controlCenter");
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (SettingsService.barOpenOnHover)
                hoverTimer.restart();
        }
        onExited: {
            hoverTimer.stop();
        }
        onClicked: {
            hoverTimer.stop();
            AppState.toggleWidget("controlCenter");
        }
    }

    RowLayout {
        id: contentRow
        anchors.centerIn: parent
        spacing: Constants.size3Xs

        SvgIcon {
            icon: "download"
            iconSize: 12
            flat: true
            iconColor: Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }

        ThemedText {
            text: root.downSpeedText
            customSize: 10
            font.weight: Font.Medium
            color: root.isHovered ? Theme.fg : Theme.muted
            Layout.alignment: Qt.AlignVCenter
        }

        SvgIcon {
            icon: "arrow-up-duotone"
            iconSize: 11
            flat: true
            iconColor: Theme.muted
            Layout.alignment: Qt.AlignVCenter
        }

        ThemedText {
            text: root.upSpeedText
            customSize: 10
            font.weight: Font.Medium
            color: root.isHovered ? Theme.fg : Theme.muted
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
