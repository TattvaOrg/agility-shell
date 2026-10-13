import QtQuick
import QtQuick.Layouts
import "../.."
import "../../components"
import "../../bar" as Bar

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mainCol.implicitHeight + 32

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ─── Header: Media Player Title & Close ───
        Row {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                SvgIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    icon: "music"
                    iconSize: 18
                    iconColor: Theme.colAccent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Music Player"
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }

            SvgIconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "x"
                iconSize: 14
                padding: 6
                onClicked: PopoutService.close()
            }
        }

        // ─── Album Art & Visualizer Hero Section ───
        GlassCard {
            width: parent.width
            height: 180
            radius: 16
            isTile: true

            Item {
                anchors.fill: parent
                anchors.margins: 12

                // Album Artwork Container
                Rectangle {
                    id: albumCover
                    width: 120
                    height: 120
                    radius: 12
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.isGlass ? "#33FFFFFF" : Theme.colPillBg
                    clip: true

                    Image {
                        id: coverImg
                        anchors.fill: parent
                        source: Bar.BarDataService.mediaArtUrl || ""
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready && source !== ""
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "music"
                        iconSize: 42
                        iconColor: Theme.colAccent
                        visible: !coverImg.visible
                    }
                }

                // Spectrum Visualizer Bars (16 Bars)
                Row {
                    id: spectrumRow
                    anchors.left: albumCover.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 80
                    spacing: 4

                    Repeater {
                        model: 16

                        Rectangle {
                            id: barRect
                            width: Math.max(3, (spectrumRow.width - 15 * 4) / 16)
                            radius: width / 2
                            anchors.bottom: parent.bottom
                            color: Theme.colAccent

                            readonly property real minH: 4
                            readonly property real maxH: 70
                            height: Bar.BarDataService.mediaPlaying ? Math.max(minH, (Math.sin((index + 1) * 0.8) * 0.5 + 0.5) * maxH) : minH

                            SequentialAnimation on height {
                                running: Bar.BarDataService.mediaPlaying
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: Math.max(8, ((index * 7) % 60) + 10)
                                    duration: 180 + (index * 40) % 220
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    to: Math.max(4, ((index * 3) % 25) + 4)
                                    duration: 180 + (index * 40) % 220
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }
                    }
                }
            }
        }

        // ─── Track Metadata Info ───
        Column {
            width: parent.width
            spacing: 4

            Text {
                text: Bar.BarDataService.mediaTitle || "No Active Playback"
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 15
                font.weight: Font.Bold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: Bar.BarDataService.mediaArtist || "Play music in Spotify, MPV, or browser"
                color: Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 12
                elide: Text.ElideRight
                width: parent.width
            }
        }

        // ─── Interactive Seek Slider ───
        Column {
            width: parent.width
            spacing: 6

            GlassSlider {
                width: parent.width
                height: 20
                value: Bar.BarDataService.mediaPositionRatio || 0.0
                onSliderMoved: function(newVal) {
                    Bar.BarDataService.seekMediaRatio(newVal)
                }
            }

            Row {
                width: parent.width

                Text {
                    anchors.left: parent.left
                    text: Bar.BarDataService.mediaPositionFormatted || "00:00"
                    color: Theme.colTextSec
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }

                Text {
                    anchors.right: parent.right
                    text: Bar.BarDataService.mediaLengthFormatted || "00:00"
                    color: Theme.colTextSec
                    font.family: Theme.fontMono
                    font.pixelSize: 10
                }
            }
        }

        // ─── Playback Control Buttons ───
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            // Shuffle
            SvgIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "player-shuffle"
                iconSize: 16
                iconColor: Theme.colTextSec
                onClicked: Bar.BarDataService.mediaToggleShuffle()
            }

            // Previous Track
            SvgIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "player-previous"
                iconSize: 20
                iconColor: Theme.colText
                onClicked: Bar.BarDataService.mediaPrevious()
            }

            // Play / Pause Prominent Button
            Rectangle {
                width: 48
                height: 48
                radius: 24
                color: Theme.colAccent
                anchors.verticalCenter: parent.verticalCenter

                scale: playHover.containsMouse ? 1.06 : 1.0
                Behavior on scale { NumberAnimation { duration: 120 } }

                SvgIcon {
                    anchors.centerIn: parent
                    icon: Bar.BarDataService.mediaPlaying ? "player-pause" : "player-play"
                    iconSize: 20
                    iconColor: "#000000"
                }

                MouseArea {
                    id: playHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Bar.BarDataService.toggleMediaPlayPause()
                }
            }

            // Next Track
            SvgIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "player-next"
                iconSize: 20
                iconColor: Theme.colText
                onClicked: Bar.BarDataService.mediaNext()
            }

            // Loop / Repeat
            SvgIconButton {
                anchors.verticalCenter: parent.verticalCenter
                icon: "player-loop"
                iconSize: 16
                iconColor: Theme.colTextSec
                onClicked: Bar.BarDataService.mediaCycleLoop()
            }
        }
    }
}
