import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Services
import qs.Core.Utils

Rectangle {
    id: root

    implicitWidth: 320
    implicitHeight: 180
    radius: MaterialTheme.cardRadius
    color: MaterialTheme.cardBackground
    border.width: 1
    border.color: MaterialTheme.cardBorder

    // Interactive hover elevation
    property bool hovered: clockMouseArea.containsMouse

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
        id: clockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            AppState.toggleWidget("dashboard");
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 8

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
                    text: "🕒"
                    font.pixelSize: 13
                }
            }

            Text {
                text: {
                    let d = SystemInfoService.currentTime;
                    let hrs = d.getHours();
                    if (hrs < 12) return "Good morning";
                    if (hrs < 18) return "Good afternoon";
                    return "Good evening";
                }
                font.family: SettingsService.fontFamily
                font.pixelSize: 13
                font.bold: true
                color: MaterialTheme.m3onSurfaceVariant
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 22
                implicitWidth: dateBadgeText.implicitWidth + 16
                radius: 11
                color: MaterialTheme.m3secondaryContainer

                Text {
                    id: dateBadgeText
                    anchors.centerIn: parent
                    text: Qt.formatDate(SystemInfoService.currentTime, "ddd")
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: MaterialTheme.m3onSecondaryContainer
                }
            }
        }

        // Clock Display
        Text {
            Layout.fillWidth: true
            text: Qt.formatTime(SystemInfoService.currentTime, SettingsService.clock24h ? "HH:mm" : "hh:mm ap")
            font.family: SettingsService.fontFamily
            font.pixelSize: 46
            font.bold: true
            color: MaterialTheme.m3primary
        }

        // Full Date Display
        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(SystemInfoService.currentTime, "dddd, MMMM d, yyyy")
            font.family: SettingsService.fontFamily
            font.pixelSize: 13
            color: MaterialTheme.m3onSurface
            opacity: 0.85
        }
    }
}
