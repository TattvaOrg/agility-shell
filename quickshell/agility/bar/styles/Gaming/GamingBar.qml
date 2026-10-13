import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../.."
import "../../../components"
import "../.." as Bar

Rectangle {
    id: root

    property var screenModel: null
    property real barHeight: 32

    anchors.fill: parent
    color: "#0D1117"
    border.color: "#30363D"
    border.width: 1

    // ─── Left Section ───
    Row {
        id: leftSection
        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight
        spacing: 8

        // GAMING Badge
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            width: badgeContent.implicitWidth + 12
            color: Theme.colAccent
            radius: 2

            Row {
                id: badgeContent
                anchors.centerIn: parent
                spacing: 4

                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "gamepad-filled"
                    iconSize: 12
                    iconColor: "#000000"
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GAMING"
                    font.family: Theme.fontMono
                    font.bold: true
                    font.pixelSize: 10
                    color: "#000000"
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Theme.setBarStyle("island")
            }
        }

        // Compact Workspaces
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Repeater {
                model: Bar.BarDataService.workspacesList

                Rectangle {
                    width: 16
                    height: 16
                    radius: 2
                    color: isActive ? Theme.colAccent : (hasWindows ? "#21262D" : "transparent")
                    border.color: isActive ? Theme.colAccent : "#30363D"
                    border.width: 1

                    property bool isActive: modelData.idx === Bar.BarDataService.activeWorkspaceIdx
                    property bool hasWindows: (modelData.window_count || 0) > 0

                    Text {
                        anchors.centerIn: parent
                        text: (modelData.idx + 1).toString()
                        font.family: Theme.fontMono
                        font.pixelSize: 9
                        font.bold: true
                        color: isActive ? "#000000" : Theme.colTextSec
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.switchToWorkspace(modelData.idx)
                    }
                }
            }
        }
    }

    // ─── Center Section ───
    Row {
        id: centerSection
        anchors.centerIn: parent
        spacing: 6

        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: "clock"
            iconSize: 13
            iconColor: Theme.colAccent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Bar.BarDataService.clockFormatted
            font.family: Theme.fontMono
            font.pixelSize: 11
            font.bold: true
            color: "#FFFFFF"
        }
    }

    // ─── Right Section ───
    Row {
        id: rightSection
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: root.barHeight
        spacing: 8

        // CPU / RAM telemetry
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                text: "CPU " + Math.round(Bar.BarDataService.cpuUsage || 0) + "%"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.colTextSec
            }

            Text {
                text: "RAM " + Math.round(Bar.BarDataService.memUsage || 0) + "%"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.colTextSec
            }
        }

        // Volume
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "volume"
                iconSize: 13
                iconColor: Theme.colTextSec
            }

            Text {
                text: Math.round(Bar.BarDataService.volumeLevel * 100) + "%"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.colTextSec
            }
        }

        // Battery
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: "charger"
                iconSize: 13
                iconColor: Theme.colTextSec
            }

            Text {
                text: Math.round(Bar.BarDataService.batteryPercent) + "%"
                font.family: Theme.fontMono
                font.pixelSize: 10
                color: Theme.colTextSec
            }
        }

        // Power action
        SvgIconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "power"
            iconSize: 13
            padding: 3
            iconColor: "#EF4444"
            onClicked: Quickshell.execDetached(["agl", "toggle", "session"])
        }
    }
}
