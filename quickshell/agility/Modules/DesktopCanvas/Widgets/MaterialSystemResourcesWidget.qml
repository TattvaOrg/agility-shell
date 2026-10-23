import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Services
import qs.Core.Utils

Rectangle {
    id: root

    implicitWidth: 320
    implicitHeight: 200
    radius: MaterialTheme.cardRadius
    color: MaterialTheme.cardBackground
    border.width: 1
    border.color: MaterialTheme.cardBorder

    property int cpuPercent: 18
    property int memPercent: 42
    property string memUsageStr: "4.2 / 16 GB"
    property bool hovered: resMouseArea.containsMouse

    scale: hovered ? 1.02 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: MaterialTheme.animDurationFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: MaterialTheme.animDurationNormal
        }
    }

    MouseArea {
        id: resMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            AppState.toggleWidget("controlCenter");
        }
    }

    // High performance telemetry sampler
    Process {
        id: statsProc
        command: ["sh", "-c", "top -bn1 | grep 'Cpu(s)' | awk '{print int($2)}'; free -m | awk '/Mem:/ {printf(\"%d %d\\n\", $3, $2)}'"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                if (!data) return;
                let lines = data.trim().split("\n");
                if (lines.length >= 1) {
                    let cpuVal = parseInt(lines[0]);
                    if (!isNaN(cpuVal)) root.cpuPercent = Math.max(1, Math.min(100, cpuVal));
                }
                if (lines.length >= 2) {
                    let parts = lines[1].trim().split(/\s+/);
                    if (parts.length >= 2) {
                        let usedMb = parseInt(parts[0]);
                        let totalMb = parseInt(parts[1]);
                        if (!isNaN(usedMb) && !isNaN(totalMb) && totalMb > 0) {
                            root.memPercent = Math.round((usedMb / totalMb) * 100);
                            let usedGb = (usedMb / 1024).toFixed(1);
                            let totalGb = (totalMb / 1024).toFixed(0);
                            root.memUsageStr = usedGb + " / " + totalGb + " GB";
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 3000
        repeat: true
        running: true
        onTriggered: {
            if (!statsProc.running) statsProc.running = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: MaterialTheme.chipRadius
                color: MaterialTheme.m3primaryContainer

                Text {
                    anchors.centerIn: parent
                    text: "⚡"
                    font.pixelSize: 13
                }
            }

            Text {
                text: "System Monitor"
                font.family: SettingsService.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: MaterialTheme.m3onSurface
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 22
                implicitWidth: batBadgeText.implicitWidth + 16
                radius: 11
                color: SystemInfoService.batteryLevel <= 20 ? "#ffb4ab" : MaterialTheme.m3secondaryContainer

                Text {
                    id: batBadgeText
                    anchors.centerIn: parent
                    text: (SystemInfoService.hasBattery ? (SystemInfoService.batteryPercentage + (SystemInfoService.batteryStatus === "Charging" ? " ⚡" : "")) : "AC Power")
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: SystemInfoService.batteryLevel <= 20 ? "#690005" : MaterialTheme.m3onSecondaryContainer
                }
            }
        }

        // CPU Metric Bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "CPU"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: MaterialTheme.m3onSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.cpuPercent + "%"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: MaterialTheme.m3primary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: MaterialTheme.m3surfaceContainerHighest

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (root.cpuPercent / 100.0)
                    radius: 4
                    color: MaterialTheme.m3primary

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        // RAM Metric Bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Memory"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: MaterialTheme.m3onSurfaceVariant
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.memUsageStr + " (" + root.memPercent + "%)"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: MaterialTheme.m3secondary
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 8
                radius: 4
                color: MaterialTheme.m3surfaceContainerHighest

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width * (root.memPercent / 100.0)
                    radius: 4
                    color: MaterialTheme.m3secondary

                    Behavior on width {
                        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
