import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../.."
import "../../../components"
import "../.." as Bar

Item {
    id: root

    property var screenModel: null
    property real barHeight: 40

    anchors.fill: parent

    readonly property real leftW: leftRow.implicitWidth + 36
    readonly property real rightW: rightRow.implicitWidth + 36
    readonly property real centerW: Math.max(180, centerRow.implicitWidth + 36)
    readonly property real centerX: Math.round((width - centerW) / 2)

    // Background organic curved bezel shape
    ConvexShape {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.barHeight + 6
        baseHeight: root.barHeight
        leftW: root.leftW
        centerX: root.centerX
        centerW: root.centerW
        rightW: root.rightW
        z: 0
    }

    // ─── Left Section ───
    Row {
        id: leftRow
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.top: parent.top
        height: root.barHeight
        spacing: 10
        z: 1

        SvgIconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "apps"
            iconSize: 16
            iconColor: hovered ? Theme.colAccent : Theme.colText
            onClicked: Quickshell.execDetached(["agl", "toggle", "launcher"])
        }

        // Workspaces
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Repeater {
                model: Bar.BarDataService.workspacesList

                Rectangle {
                    width: isActive ? 20 : (hasWindows ? 8 : 6)
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter

                    property bool isActive: modelData.idx === Bar.BarDataService.activeWorkspaceIdx
                    property bool hasWindows: (modelData.window_count || 0) > 0

                    color: isActive ? Theme.colAccent : (hasWindows ? Qt.lighter(Theme.colTextSec, 1.2) : Theme.colBorder)

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.switchToWorkspace(modelData.idx)
                    }
                }
            }
        }

        // Active window
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Bar.BarDataService.activeWindowTitle !== ""
            text: Bar.BarDataService.activeWindowTitle
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 1
            width: Math.min(180, implicitWidth)
        }
    }

    // ─── Center Section ───
    Row {
        id: centerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        height: root.barHeight
        spacing: 12
        z: 1

        // Clock
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: clockRow.implicitWidth
            height: clockRow.implicitHeight

            Row {
                id: clockRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "clock"
                    iconSize: 14
                    iconColor: Theme.colAccent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bar.BarDataService.clockFormatted
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["agl", "toggle", "calendar"])
            }
        }

        // Media ticker if playing
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            visible: Bar.BarDataService.mediaTitle !== ""

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 14
                color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
            }

            SvgIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: Bar.BarDataService.mediaPlaying ? "player-pause" : "player-play"
                iconSize: 11
                padding: 3
                iconColor: Theme.colAccent
                onClicked: Bar.BarDataService.toggleMediaPlayPause()
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Bar.BarDataService.mediaTitle
                color: Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 11
                elide: Text.ElideRight
                width: Math.min(140, implicitWidth)
            }
        }
    }

    // ─── Right Section ───
    Row {
        id: rightRow
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.top: parent.top
        height: root.barHeight
        spacing: 10
        z: 1

        // Volume
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: volRow.implicitWidth
            height: volRow.implicitHeight

            Row {
                id: volRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Bar.BarDataService.volumeMuted ? "volume-off" : "volume"
                    iconSize: 14
                    iconColor: Theme.colText
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(Bar.BarDataService.volumeLevel * 100) + "%"
                    color: Theme.colTextSec
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Bar.BarDataService.toggleVolumeMute()
            }
        }

        // Network
        SvgIcon {
            anchors.verticalCenter: parent.verticalCenter
            icon: Bar.BarDataService.wifiConnected ? "wifi" : "wifi-off"
            iconSize: 14
            iconColor: Theme.colText
        }

        // Battery
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            SvgIcon {
                anchors.verticalCenter: parent.verticalCenter
                icon: Bar.BarDataService.batteryCharging ? "charger" : "charger-filled"
                iconSize: 14
                iconColor: Theme.colText
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(Bar.BarDataService.batteryPercent) + "%"
                color: Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 11
            }
        }

        // Control Center
        SvgIconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: "tune"
            iconSize: 15
            iconColor: hovered ? Theme.colAccent : Theme.colText
            onClicked: Quickshell.execDetached(["agl", "toggle", "control-center"])
        }

        // Notifications
        SvgIconButton {
            anchors.verticalCenter: parent.verticalCenter
            icon: Bar.BarDataService.hasUnreadNotifications ? "bell-dot" : "bell"
            iconSize: 15
            iconColor: Bar.BarDataService.hasUnreadNotifications ? Theme.colAccent : (hovered ? Theme.colAccent : Theme.colText)
            onClicked: Quickshell.execDetached(["agl", "toggle", "notifications"])
        }
    }
}
