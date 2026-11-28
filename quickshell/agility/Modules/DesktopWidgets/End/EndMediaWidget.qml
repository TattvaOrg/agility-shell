/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/media/MediaWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Uses Agility Shell's MprisService. Combined under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "media"
    displayName: "Media Player"
    sizeModes: ["1x3", "1x1", "1x2", "2x2", "2x3"]
    sizeMode: EndWidgetStore.getPref("media", "sizeMode", "1x3")

    baseWidth: sizeMode === "1x1" ? 132 : ((sizeMode === "1x2" || sizeMode === "2x2") ? 276 : 420)
    baseHeight: (sizeMode === "2x2" || sizeMode === "2x3") ? 250 : 118

    readonly property var player: MprisService.activePlayer
    readonly property string trackTitle: player ? (player.trackTitle || "Unknown Track") : "Nothing Playing"
    readonly property string trackArtist: player ? (player.trackArtist || MprisService.activePlayerName || "Media") : "Start playback"
    readonly property string artUrl: player ? (player.trackArtUrl || "") : ""
    readonly property bool playing: MprisService.isPlaying

    function togglePlay() {
        if (!player)
            return;
        if (player.togglePlaying)
            player.togglePlaying();
        else if (player.canTogglePlaying)
            player.isPlaying = !player.isPlaying;
    }

    component ArtBox: Rectangle {
        property real boxRadius: 26
        property bool roundRight: true
        radius: boxRadius
        color: EndTheme.chipBg
        clip: true

        Image {
            id: artImg
            anchors.fill: parent
            source: root.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            visible: root.artUrl !== "" && status === Image.Ready
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: artImg.width
                    height: artImg.height
                    topLeftRadius: boxRadius
                    bottomLeftRadius: boxRadius
                    topRightRadius: roundRight ? boxRadius : 0
                    bottomRightRadius: roundRight ? boxRadius : 0
                }
            }
        }

        SvgIcon {
            anchors.centerIn: parent
            visible: root.artUrl === "" || artImg.status !== Image.Ready
            icon: "music"
            iconSize: 28
            iconColor: EndTheme.primary
            flat: true
        }
    }

    component PlayBtn: Item {
        width: 38
        height: 38
        MaterialShape {
            anchors.fill: parent
            shape: MaterialShape.Shape.Cookie12Sided
            color: EndTheme.primary
        }
        SvgIcon {
            anchors.centerIn: parent
            icon: root.playing ? "player-pause" : "player-play"
            iconSize: 16
            iconColor: EndTheme.onPrimary
            flat: true
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePlay()
        }
    }

    EndWidgetCard {
        anchors.fill: parent
        clip: true

        // 1x1
        Item {
            anchors.fill: parent
            visible: root.sizeMode === "1x1"

            ArtBox {
                anchors.fill: parent
                boxRadius: 24
            }

            Rectangle {
                anchors.fill: parent
                radius: 24
                gradient: Gradient {
                    GradientStop { position: 0.35; color: "transparent" }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.72) }
                }
            }

            RowLayout {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8
                spacing: 4

                Rectangle {
                    width: 26; height: 26; radius: 13; color: "transparent"
                    SvgIcon { anchors.centerIn: parent; icon: "player-previous"; iconSize: 12; iconColor: "#ffffff"; flat: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                }
                PlayBtn { width: 32; height: 32 }
                Rectangle {
                    width: 26; height: 26; radius: 13; color: "transparent"
                    SvgIcon { anchors.centerIn: parent; icon: "player-next"; iconSize: 12; iconColor: "#ffffff"; flat: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                }
            }
        }

        // 1x2 & 1x3 (matches reference screenshot bottom-right: flush left art + controls pill)
        RowLayout {
            anchors.fill: parent
            spacing: 0
            visible: root.sizeMode === "1x2" || root.sizeMode === "1x3"

            ArtBox {
                Layout.preferredWidth: 118
                Layout.fillHeight: true
                boxRadius: 26
                roundRight: false
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 16
                Layout.rightMargin: 14
                Layout.topMargin: 14
                Layout.bottomMargin: 12
                spacing: 4

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.trackTitle
                        color: EndTheme.onCard
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.trackArtist
                        color: EndTheme.onCardMuted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.alignment: Qt.AlignRight
                    implicitWidth: pillCtrlRow.implicitWidth + 10
                    implicitHeight: 44
                    radius: 22
                    color: EndTheme.chipBg
                    border.width: 1
                    border.color: EndTheme.chipBorder

                    RowLayout {
                        id: pillCtrlRow
                        anchors.centerIn: parent
                        spacing: 4

                        Rectangle {
                            width: 28; height: 28; radius: 14; color: "transparent"
                            SvgIcon { anchors.centerIn: parent; icon: "player-previous"; iconSize: 13; iconColor: EndTheme.onCard; flat: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                        }
                        PlayBtn {}
                        Rectangle {
                            width: 28; height: 28; radius: 14; color: "transparent"
                            SvgIcon { anchors.centerIn: parent; icon: "player-next"; iconSize: 13; iconColor: EndTheme.onCard; flat: true }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                        }
                    }
                }
            }
        }

        // 2x2 & 2x3
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"

            ArtBox {
                Layout.fillWidth: true
                Layout.fillHeight: true
                boxRadius: 16
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.trackTitle
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.trackArtist
                    color: Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Rectangle {
                    width: 32; height: 32; radius: 16; color: Theme.bgSecondary
                    SvgIcon { anchors.centerIn: parent; icon: "player-previous"; iconSize: 14; iconColor: Theme.fg; flat: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.previous() }
                }
                PlayBtn { width: 40; height: 40 }
                Rectangle {
                    width: 32; height: 32; radius: 16; color: Theme.bgSecondary
                    SvgIcon { anchors.centerIn: parent; icon: "player-next"; iconSize: 14; iconColor: Theme.fg; flat: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: if (root.player) root.player.next() }
                }
            }
        }
    }
}
