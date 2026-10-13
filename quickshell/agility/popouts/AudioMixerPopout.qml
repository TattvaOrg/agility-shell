import QtQuick
import ".."
import "../components"
import "../bar" as Bar

Item {
    id: root

    implicitWidth: 380
    implicitHeight: Math.min(560, contentCol.implicitHeight + 32)

    Column {
        id: contentCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 14

        // ─── Header ───
        Row {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                GlassButton {
                    iconSource: "arrow-left"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.open("control_center")
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Audio Mixer"
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                GlassButton {
                    iconSource: "rotate"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.refreshAudioDevices()
                }

                GlassButton {
                    iconSource: "x"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.close()
                }
            }
        }

        // ─── Master Output Sink Section ───
        Text {
            text: "Output Sinks (Speakers / Headphones)"
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.SemiBold
        }

        GlassCard {
            width: parent.width
            implicitHeight: masterOutCol.implicitHeight + 20
            radius: 14

            Column {
                id: masterOutCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 10

                Row {
                    width: parent.width
                    height: 28
                    spacing: 8

                    MouseArea {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.toggleVolumeMute()

                        GlassIcon {
                            anchors.centerIn: parent
                            source: Bar.BarDataService.volumeMuted ? "volume-mute" : "volume"
                            size: 18
                            color: Bar.BarDataService.volumeMuted ? "#EF4444" : Theme.colAccent
                        }
                    }

                    GlassSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        minimumValue: 0.0
                        maximumValue: 1.0
                        stepSize: 0.02
                        value: Bar.BarDataService.volume
                        onValueChangedByUser: function(v) {
                            Bar.BarDataService.setVolume(v)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        text: Math.round(Bar.BarDataService.volume * 100) + "%"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Available sinks
                Repeater {
                    model: PopoutService.audioSinks

                    delegate: GlassPill {
                        width: masterOutCol.width
                        implicitHeight: 28
                        interactive: true
                        onClicked: PopoutService.setDefaultSink(modelData.name)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            GlassIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "speaker-hifi"
                                size: 14
                                color: Theme.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30
                                text: modelData.desc || modelData.name
                                color: Theme.colText
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ─── Master Input Source Section ───
        Text {
            text: "Input Sources (Microphones)"
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.SemiBold
        }

        GlassCard {
            width: parent.width
            implicitHeight: masterInCol.implicitHeight + 20
            radius: 14

            Column {
                id: masterInCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 10

                Row {
                    width: parent.width
                    height: 28
                    spacing: 8

                    MouseArea {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PopoutService.toggleMicMute()

                        GlassIcon {
                            anchors.centerIn: parent
                            source: "microphone"
                            size: 18
                            color: Bar.BarDataService.micMuted ? "#EF4444" : Theme.colAccent
                        }
                    }

                    GlassSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        minimumValue: 0.0
                        maximumValue: 1.0
                        stepSize: 0.02
                        value: Bar.BarDataService.micVolume
                        onValueChangedByUser: function(v) {
                            PopoutService.setMicVolume(v)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        text: Math.round(Bar.BarDataService.micVolume * 100) + "%"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // Available sources
                Repeater {
                    model: PopoutService.audioSources

                    delegate: GlassPill {
                        width: masterInCol.width
                        implicitHeight: 28
                        interactive: true
                        onClicked: PopoutService.setDefaultSource(modelData.name)

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            GlassIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "microphone"
                                size: 14
                                color: Theme.colAccent
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 30
                                text: modelData.desc || modelData.name
                                color: Theme.colText
                                font.family: Theme.fontMain
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }

        // ─── Application Streams Section ───
        Text {
            text: "Application Audio Streams (" + PopoutService.audioStreams.length + ")"
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.SemiBold
            visible: PopoutService.audioStreams.length > 0
        }

        Repeater {
            model: PopoutService.audioStreams

            delegate: GlassCard {
                width: contentCol.width
                height: 48
                radius: 12
                isTile: true

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "waveform"
                        size: 16
                        color: Theme.colAccent
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 90
                        text: modelData.name || "App"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        font.weight: Font.SemiBold
                        elide: Text.ElideRight
                    }

                    GlassSlider {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 170
                        minimumValue: 0.0
                        maximumValue: 1.0
                        stepSize: 0.05
                        value: modelData.volume || 1.0
                        onValueChangedByUser: function(v) {
                            PopoutService.setAppStreamVolume(modelData.id, v)
                        }
                    }

                    MouseArea {
                        width: 24
                        height: 24
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PopoutService.toggleAppStreamMute(modelData.id)

                        GlassIcon {
                            anchors.centerIn: parent
                            source: modelData.muted ? "volume-mute" : "volume"
                            size: 14
                            color: modelData.muted ? "#EF4444" : Theme.colTextSec
                        }
                    }
                }
            }
        }
    }
}
