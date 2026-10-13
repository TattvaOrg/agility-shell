import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../.."
import "../../../components"
import "../.." as Bar

Item {
    id: root

    property var screenModel: null
    property real barHeight: 38

    anchors.fill: parent

    // Container for the three floating island pills
    Item {
        id: islandContainer
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 6
        anchors.bottomMargin: 6

        // ══════════════════════════════════════════
        // 1. LEFT PILL: Launcher + Workspaces + App
        // ══════════════════════════════════════════
        Rectangle {
            id: leftPill
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: leftRow.implicitWidth + 18
            radius: height / 2

            color: Theme.isGlass ? "#40182430" : Theme.colCardBg
            border.color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
            border.width: 1

            scale: leftHover.containsMouse ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MouseArea {
                id: leftHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Row {
                id: leftRow
                anchors.centerIn: parent
                spacing: 8

                // App Launcher Trigger
                SvgIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "apps"
                    iconSize: 16
                    iconColor: hovered ? Theme.colAccent : Theme.colText
                    hoverBgColor: Theme.isGlass ? "#33FFFFFF" : Theme.colPillBg
                    onClicked: {
                        Quickshell.execDetached(["agl", "toggle", "launcher"])
                    }
                }

                // Divider line
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 16
                    color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
                }

                // Workspaces Dots / Indicator
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5

                    Repeater {
                        model: Bar.BarDataService.workspacesList

                        Rectangle {
                            id: wsDot
                            width: isActive ? 20 : (hasWindows ? 8 : 6)
                            height: 8
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isActive: modelData.idx === Bar.BarDataService.activeWorkspaceIdx
                            property bool hasWindows: (modelData.window_count || 0) > 0

                            color: isActive ? Theme.colAccent : (hasWindows ? Qt.lighter(Theme.colTextSec, 1.2) : Theme.colBorder)

                            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                            Behavior on color { ColorAnimation { duration: 150 } }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Bar.BarDataService.switchToWorkspace(modelData.idx)
                            }
                        }
                    }
                }

                // Active Window Title (if present)
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    visible: Bar.BarDataService.activeWindowTitle !== ""

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 1
                        height: 16
                        color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
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
            }
        }

        // ══════════════════════════════════════════
        // 2. CENTER PILL: Dynamic Morphing Island
        // ══════════════════════════════════════════
        Rectangle {
            id: centerPill
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            radius: height / 2

            // Dynamic Island width expansion based on active mode
            readonly property bool hasMedia: Bar.BarDataService.mediaTitle !== ""
            readonly property bool isPlaying: Bar.BarDataService.mediaPlaying

            width: {
                if (centerHover.containsMouse && hasMedia) return Math.min(320, mediaRow.implicitWidth + 24)
                if (hasMedia && isPlaying) return Math.min(280, mediaRow.implicitWidth + 24)
                return clockRow.implicitWidth + 24
            }

            color: Theme.isGlass ? "#48182430" : Theme.colCardBg
            border.color: Theme.isGlass ? (isPlaying ? Theme.colAccent : "#33FFFFFF") : (isPlaying ? Theme.colAccent : Theme.colBorder)
            border.width: isPlaying ? 1.5 : 1

            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
            Behavior on border.color { ColorAnimation { duration: 200 } }

            MouseArea {
                id: centerHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (centerPill.hasMedia) {
                        Quickshell.execDetached(["agl", "toggle", "media"])
                    } else {
                        Quickshell.execDetached(["agl", "toggle", "calendar"])
                    }
                }
            }

            // Normal Clock Island View
            Row {
                id: clockRow
                anchors.centerIn: parent
                spacing: 8
                visible: !centerPill.hasMedia || (!centerPill.isPlaying && !centerHover.containsMouse)
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

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

            // Morphing Music Island View
            Row {
                id: mediaRow
                anchors.centerIn: parent
                spacing: 8
                visible: centerPill.hasMedia && (centerPill.isPlaying || centerHover.containsMouse)
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Mini animated waveform bars
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: 4

                        Rectangle {
                            width: 2.5
                            height: centerPill.isPlaying ? Math.max(4, (index % 2 === 0 ? 12 : 8)) : 4
                            radius: 1.5
                            color: Theme.colAccent
                            anchors.verticalCenter: parent.verticalCenter

                            SequentialAnimation on height {
                                running: centerPill.isPlaying
                                loops: Animation.Infinite
                                NumberAnimation { to: 14; duration: 200 + index * 60; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: 4; duration: 200 + index * 60; easing.type: Easing.InOutQuad }
                            }
                        }
                    }
                }

                // Play / Pause mini button
                SvgIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Bar.BarDataService.mediaPlaying ? "player-pause" : "player-play"
                    iconSize: 12
                    padding: 4
                    iconColor: Theme.colAccent
                    onClicked: Bar.BarDataService.toggleMediaPlayPause()
                }

                // Marquee Track Info
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bar.BarDataService.mediaTitle + (Bar.BarDataService.mediaArtist !== "" ? (" • " + Bar.BarDataService.mediaArtist) : "")
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(160, implicitWidth)
                }

                // Next Track button
                SvgIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "player-next"
                    iconSize: 12
                    padding: 4
                    iconColor: Theme.colTextSec
                    hoverColor: Theme.colAccent
                    onClicked: Bar.BarDataService.mediaNext()
                }
            }
        }

        // ══════════════════════════════════════════
        // 3. RIGHT PILL: Status Controls & Control Center
        // ══════════════════════════════════════════
        Rectangle {
            id: rightPill
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: root.barHeight
            width: rightRow.implicitWidth + 16
            radius: height / 2

            color: Theme.isGlass ? "#40182430" : Theme.colCardBg
            border.color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
            border.width: 1

            scale: rightHover.containsMouse ? 1.02 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MouseArea {
                id: rightHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
            }

            Row {
                id: rightRow
                anchors.centerIn: parent
                spacing: 8

                // Volume Indicator
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
                            iconColor: Bar.BarDataService.volumeMuted ? Theme.colTextSec : Theme.colText
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Bar.BarDataService.volumeMuted ? "Mute" : (Math.round(Bar.BarDataService.volumeLevel * 100) + "%")
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.toggleVolumeMute()
                        onWheel: function(wheel) {
                            if (wheel.angleDelta.y > 0) Bar.BarDataService.volumeUp()
                            else Bar.BarDataService.volumeDown()
                        }
                    }
                }

                // Network Status
                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Bar.BarDataService.wifiConnected ? "wifi" : "wifi-off"
                    iconSize: 14
                    iconColor: Bar.BarDataService.wifiConnected ? Theme.colText : Theme.colTextSec
                }

                // Battery Status
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    SvgIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: Bar.BarDataService.batteryCharging ? "charger" : "charger-filled"
                        iconSize: 14
                        iconColor: Bar.BarDataService.batteryPercent <= 20 ? "#EF4444" : Theme.colText
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Math.round(Bar.BarDataService.batteryPercent) + "%"
                        color: Bar.BarDataService.batteryPercent <= 20 ? "#EF4444" : Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }

                // Divider
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 1
                    height: 16
                    color: Theme.isGlass ? "#33FFFFFF" : Theme.colBorder
                }

                // Control Center Trigger
                SvgIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "tune"
                    iconSize: 15
                    iconColor: hovered ? Theme.colAccent : Theme.colText
                    hoverBgColor: Theme.isGlass ? "#33FFFFFF" : Theme.colPillBg
                    onClicked: {
                        Quickshell.execDetached(["agl", "toggle", "control-center"])
                    }
                }

                // Notifications Bell Trigger
                SvgIconButton {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: Bar.BarDataService.hasUnreadNotifications ? "bell-dot" : "bell"
                    iconSize: 15
                    iconColor: Bar.BarDataService.hasUnreadNotifications ? Theme.colAccent : (hovered ? Theme.colAccent : Theme.colText)
                    hoverBgColor: Theme.isGlass ? "#33FFFFFF" : Theme.colPillBg
                    onClicked: {
                        Quickshell.execDetached(["agl", "toggle", "notifications"])
                    }
                }
            }
        }
    }
}
