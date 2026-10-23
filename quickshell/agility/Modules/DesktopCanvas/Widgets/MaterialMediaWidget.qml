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

    property bool hovered: mediaMouseArea.containsMouse

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
        id: mediaMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Top info row
        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            // Album Art Thumbnail or Music Icon
            Rectangle {
                implicitWidth: 64
                implicitHeight: 64
                radius: MaterialTheme.buttonRadius
                color: MaterialTheme.m3primaryContainer
                clip: true

                Image {
                    anchors.fill: parent
                    source: (MprisService.activePlayer && MprisService.activePlayer.trackArtUrl) ? MprisService.activePlayer.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !parent.children[0].visible
                    text: "🎵"
                    font.pixelSize: 26
                }
            }

            // Track details
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (MprisService.activePlayer && MprisService.activePlayer.trackTitle) ? MprisService.activePlayer.trackTitle : "No Media Playing"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 14
                    font.bold: true
                    color: MaterialTheme.m3onSurface
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: (MprisService.activePlayer && MprisService.activePlayer.trackArtist) ? MprisService.activePlayer.trackArtist : (MprisService.activePlayerName !== "" ? MprisService.activePlayerName : "Agility Audio Engine")
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    color: MaterialTheme.m3onSurfaceVariant
                }

                // Small pill showing player source
                Rectangle {
                    implicitHeight: 18
                    implicitWidth: playerPillText.implicitWidth + 12
                    radius: 9
                    color: MaterialTheme.m3secondaryContainer

                    Text {
                        id: playerPillText
                        anchors.centerIn: parent
                        text: MprisService.activePlayerName !== "" ? MprisService.activePlayerName : "Ready"
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 9
                        font.bold: true
                        color: MaterialTheme.m3onSecondaryContainer
                    }
                }
            }
        }

        // Media Controls Row
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter

            Item { Layout.fillWidth: true }

            // Prev Button
            Rectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                color: prevMouse.containsMouse ? MaterialTheme.m3surfaceContainerHighest : MaterialTheme.m3surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "⏮"
                    font.pixelSize: 14
                    color: MaterialTheme.m3onSurface
                }

                MouseArea {
                    id: prevMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (MprisService.activePlayer && MprisService.activePlayer.canGoPrevious) {
                            MprisService.activePlayer.previous();
                        }
                    }
                }
            }

            // Play / Pause Button (Hero action pill)
            Rectangle {
                implicitWidth: 46
                implicitHeight: 46
                radius: 23
                color: playMouse.containsMouse ? MaterialTheme.m3primaryContainer : MaterialTheme.m3primary

                Text {
                    anchors.centerIn: parent
                    text: MprisService.isPlaying ? "⏸" : "▶"
                    font.pixelSize: 17
                    color: playMouse.containsMouse ? MaterialTheme.m3onPrimaryContainer : MaterialTheme.m3onPrimary
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (MprisService.activePlayer) {
                            MprisService.activePlayer.togglePlaying();
                        }
                    }
                }
            }

            // Next Button
            Rectangle {
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                color: nextMouse.containsMouse ? MaterialTheme.m3surfaceContainerHighest : MaterialTheme.m3surfaceContainerHigh

                Text {
                    anchors.centerIn: parent
                    text: "⏭"
                    font.pixelSize: 14
                    color: MaterialTheme.m3onSurface
                }

                MouseArea {
                    id: nextMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (MprisService.activePlayer && MprisService.activePlayer.canGoNext) {
                            MprisService.activePlayer.next();
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }
    }
}
