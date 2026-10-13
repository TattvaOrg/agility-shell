import QtQuick
import ".."
import "../components"
import "../bar" as Bar

Item {
    id: root

    implicitWidth: 360
    implicitHeight: Math.min(540, contentCol.implicitHeight + 32)

    property string selectedSsid: ""
    property bool isConnecting: false

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
                    text: "Wi-Fi Networks"
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
                    onClicked: PopoutService.scanWifi()
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

        // ─── Connected Network Card ───
        GlassCard {
            width: parent.width
            height: 52
            radius: 14
            visible: Bar.BarDataService.wifiConnected
            color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.22)

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                GlassIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    source: "wifi"
                    size: 20
                    color: Theme.colAccent
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 120
                    spacing: 2

                    Text {
                        text: Bar.BarDataService.wifiSsid
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    Text {
                        text: "Connected (" + Bar.BarDataService.wifiSignal + "% signal)"
                        color: Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 10
                    }
                }

                GlassButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Disconnect"
                    implicitHeight: 28
                    radius: 8
                    accentColor: "#EF4444"
                    onClicked: PopoutService.disconnectWifi(Bar.BarDataService.wifiSsid)
                }
            }
        }

        // ─── Inline Passphrase Dialog (when a protected SSID is clicked) ───
        GlassCard {
            id: passDialog
            width: parent.width
            implicitHeight: passCol.implicitHeight + 20
            radius: 14
            visible: root.selectedSsid !== ""

            Column {
                id: passCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Connect to \"" + root.selectedSsid + "\""
                    color: Theme.colText
                    font.family: Theme.fontMain
                    font.pixelSize: 12
                    font.weight: Font.SemiBold
                }

                // Password Input Field
                Rectangle {
                    width: parent.width
                    height: 32
                    radius: 8
                    color: Theme.isGlass ? "#3316222E" : Theme.colPillBg
                    border.color: pwInput.activeFocus ? Theme.colAccent : (Theme.isGlass ? "#22FFFFFF" : Theme.borderColor)
                    border.width: 1

                    TextInput {
                        id: pwInput
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        echoMode: TextInput.Password
                        clip: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: !pwInput.text && !pwInput.activeFocus
                            text: "Enter Wi-Fi Password..."
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                        }

                        onAccepted: {
                            root.isConnecting = true
                            PopoutService.connectWifi(root.selectedSsid, pwInput.text)
                            root.selectedSsid = ""
                            pwInput.text = ""
                        }
                    }
                }

                // Action buttons
                Row {
                    anchors.right: parent.right
                    spacing: 8

                    GlassButton {
                        text: "Cancel"
                        implicitHeight: 28
                        radius: 8
                        onClicked: {
                            root.selectedSsid = ""
                            pwInput.text = ""
                        }
                    }

                    GlassButton {
                        text: "Connect"
                        primary: true
                        implicitHeight: 28
                        radius: 8
                        onClicked: {
                            root.isConnecting = true
                            PopoutService.connectWifi(root.selectedSsid, pwInput.text)
                            root.selectedSsid = ""
                            pwInput.text = ""
                        }
                    }
                }
            }
        }

        // ─── Available Access Points List ───
        Text {
            text: "Available Networks (" + PopoutService.wifiNetworks.length + ")"
            color: Theme.colTextSec
            font.family: Theme.fontMain
            font.pixelSize: 11
            font.weight: Font.SemiBold
        }

        Item {
            width: parent.width
            height: Math.min(260, Math.max(80, netListView.contentHeight))
            clip: true

            ListView {
                id: netListView
                anchors.fill: parent
                spacing: 6
                model: PopoutService.wifiNetworks

                delegate: GlassCard {
                    width: netListView.width
                    height: 44
                    radius: 12
                    isTile: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.inUse) return
                            if (modelData.isSecure) {
                                root.selectedSsid = modelData.ssid
                            } else {
                                PopoutService.connectWifi(modelData.ssid, "")
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        GlassIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            source: modelData.signal > 60 ? "wifi" : (modelData.signal > 30 ? "wifi-medium-duotone.svg" : "wifi-low-duotone.svg")
                            size: 16
                            color: modelData.inUse ? Theme.colAccent : Theme.colText
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 80
                            text: modelData.ssid
                            color: modelData.inUse ? Theme.colAccent : Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: modelData.inUse ? Font.Bold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6

                            GlassIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                source: "lock"
                                size: 12
                                color: Theme.colTextSec
                                visible: modelData.isSecure
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.signal + "%"
                                color: Theme.colTextSec
                                font.family: Theme.fontMain
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }
}
