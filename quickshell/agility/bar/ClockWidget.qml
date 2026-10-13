import QtQuick
import ".."
import "../components"

Item {
    id: root

    property string timeStr: "00:00"
    property string dateStr: "Mon, Jan 1"

    implicitHeight: 32
    implicitWidth: chipRow.implicitWidth + 20

    signal clicked()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var now = new Date()
            root.timeStr = Qt.formatDateTime(now, "hh:mm")
            root.dateStr = Qt.formatDateTime(now, "ddd, MMM d")
        }
    }

    GlassPill {
        anchors.fill: parent
        interactive: true
        onClicked: root.clicked()

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6

            GlassIcon {
                anchors.verticalCenter: parent.verticalCenter
                source: "clock"
                size: 15
                color: Theme.colAccent
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.timeStr
                color: Theme.colText
                font.family: Theme.fontMain
                font.pixelSize: 13
                font.bold: true
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 1
                height: 12
                color: "#30FFFFFF"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.dateStr
                color: Theme.colTextSec
                font.family: Theme.fontMain
                font.pixelSize: 12
            }
        }
    }
}
