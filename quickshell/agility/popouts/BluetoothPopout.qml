import QtQuick
import ".."
import "../components"
import "../bar" as Bar

Item {
    id: root

    implicitWidth: 360
    implicitHeight: Math.min(500, contentCol.implicitHeight + 32)

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
                    text: "Bluetooth Manager"
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

                // Rescan button
                GlassButton {
                    iconSource: "rotate"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.scanBluetooth()
                }

                // Close button
                GlassButton {
                    iconSource: "x"
                    implicitWidth: 28
                    implicitHeight: 28
                    radius: 14
                    onClicked: PopoutService.close()
                }
            }
        }

        // ─── Bluetooth Power Status Card ───
        GlassCard {
            width: parent.width
            height: 48
            radius: 14
            isTile: true

            Row {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 10

                GlassIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "bluetooth"
                    size: 20
                    color: Bar.BarDataService.bluetoothConnected ? Theme.colAccent : Theme.colTextSec
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 120
                    spacing: 2

                    Text {
                        text: "Bluetooth Adapter"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                    }
                    Text {
                        text: Bar.BarDataService.bluetoothConnected ? (Bar.BarDataService.bluetoothDeviceCount + " Devices Connected") : "Disconnected"
                        color: Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }
                }

                GlassButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Bar.BarDataService.bluetoothConnected ? "Turn Off" : "Turn On"
                    implicitHeight: 28
                    radius: 8
                    onClicked: Bar.BarDataService.runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Connectivity org.agility.Daemon.Connectivity ToggleBluetooth 2>/dev/null || bluetoothctl power " + (Bar.BarDataService.bluetoothConnected ? "off" : "on") + " 2>/dev/null || true")
                }
            }
        }

        // ─── Devices Section ───
        Text {
            text: "Paired & Known Devices (" + PopoutService.bluetoothDevices.length + ")"
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.SemiBold
        }

        Item {
            width: parent.width
            height: Math.min(260, Math.max(80, devListView.contentHeight))
            clip: true

            ListView {
                id: devListView
                anchors.fill: parent
                spacing: 6
                model: PopoutService.bluetoothDevices

                delegate: GlassCard {
                    width: devListView.width
                    height: 48
                    radius: 12
                    isTile: true

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        GlassIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: "headphones"
                            size: 18
                            color: modelData.connected ? Theme.colAccent : Theme.colTextSec
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 130
                            spacing: 2

                            Text {
                                text: modelData.name || modelData.address
                                color: Theme.colText
                                font.family: Theme.fontMain
                                font.pixelSize: 12
                                font.weight: Font.SemiBold
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Text {
                                text: modelData.address
                                color: Theme.colTextSec
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }

                        GlassButton {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.connected ? "Disconnect" : "Connect"
                            primary: !modelData.connected
                            accentColor: modelData.connected ? "#EF4444" : Theme.colAccent
                            implicitHeight: 28
                            radius: 8
                            onClicked: {
                                if (modelData.connected) {
                                    PopoutService.disconnectBluetooth(modelData.address)
                                } else {
                                    PopoutService.connectBluetooth(modelData.address)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
