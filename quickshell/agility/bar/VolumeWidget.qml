import QtQuick
import ".."
import "../components"
import "../popouts" as Popouts

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowContent.implicitWidth + 18

    readonly property string volumeIcon: {
        if (BarDataService.volumeMuted || BarDataService.volume <= 0.01) return "volume-mute"
        if (BarDataService.volume < 0.4) return "volume-low"
        return "volume"
    }

    GlassPill {
        id: pill
        anchors.fill: parent
        interactive: false

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton) {
                    Popouts.PopoutService.toggle("audio_mixer")
                } else {
                    BarDataService.toggleVolumeMute()
                }
            }
        }

        Row {
            id: rowContent
            anchors.centerIn: parent
            spacing: 5

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: root.volumeIcon
                size: 15
                color: BarDataService.volumeMuted ? "#EF4444" : Theme.colAccent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: BarDataService.volumeMuted ? "Mute" : Math.round(BarDataService.volume * 100) + "%"
                color: BarDataService.volumeMuted ? "#EF4444" : Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 12
                font.weight: Font.Medium
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onWheel: function(wheel) {
                var delta = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                BarDataService.setVolume(BarDataService.volume + delta)
            }
        }
    }
}
