import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 32
    implicitWidth: rowLayout.implicitWidth + 18

    GlassPill {
        anchors.fill: parent
        interactive: false

        Row {
            id: rowLayout
            anchors.centerIn: parent
            spacing: 8

            // CPU Gauge
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "CPU"
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                    color: Theme.colTextSec
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Math.round(BarDataService.cpuUsage) + "%"
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    font.bold: true
                    color: BarDataService.cpuUsage > 80.0 ? "#EF4444" : Theme.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Rectangle {
                width: 1
                height: 12
                color: "#28FFFFFF"
                anchors.verticalCenter: parent.verticalCenter
            }

            // RAM Gauge
            Row {
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: "RAM"
                    font.family: Theme.fontMain
                    font.pixelSize: 10
                    color: Theme.colTextSec
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: Math.round(BarDataService.memoryUsage) + "%"
                    font.family: Theme.fontMain
                    font.pixelSize: 11
                    font.bold: true
                    color: BarDataService.memoryUsage > 85.0 ? "#EF4444" : Theme.colAccent
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
