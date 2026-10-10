import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: Math.min(240, Math.max(120, contentRow.implicitWidth + 18))
    visible: BarDataService.mediaTitle !== ""

    GlassCard {
        anchors.fill: parent
        radius: 16
        isTile: true

        Row {
            id: contentRow
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            // Mini Play/Pause button
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                height: 22
                radius: 11
                color: Theme.colPillBg

                Text {
                    anchors.centerIn: parent
                    text: BarDataService.mediaPlaying ? "⏸" : "▶"
                    font.pixelSize: 10
                    color: Theme.colAccent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: BarDataService.toggleMediaPlayPause()
                }
            }

            GlassMarquee {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 34
                height: 18
                text: BarDataService.mediaArtist !== "" ? (BarDataService.mediaTitle + " • " + BarDataService.mediaArtist) : BarDataService.mediaTitle
                color: Theme.colText
                fontSize: 12
            }
        }
    }
}
