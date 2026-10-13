import QtQuick
import ".."
import "../components"
import "../bar" as Bar

Item {
    id: root

    implicitWidth: 360
    implicitHeight: mainCol.implicitHeight + 32

    Column {
        id: mainCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        spacing: 16

        // ─── Header: User & Battery Status ───
        Row {
            width: parent.width
            height: 36

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.25)
                    border.color: Theme.colAccent
                    border.width: 1

                    GlassIcon {
                        anchors.centerIn: parent
                        source: "user"
                        size: 18
                        color: Theme.colAccent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: "Control Center"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    Text {
                        text: Bar.BarDataService.batteryPercent.toFixed(0) + "% Battery" + (Bar.BarDataService.batteryCharging ? " (Charging)" : "")
                        color: Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                    }
                }
            }

            // Power & Close actions
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                GlassButton {
                    iconSource: "power"
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    accentColor: "#EF4444"
                    onClicked: PopoutService.open("session")
                }

                GlassButton {
                    iconSource: "x"
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 16
                    onClicked: PopoutService.close()
                }
            }
        }

        // ─── Quick Toggle Tiles Grid (20.3) ───
        // 8 tiles: WiFi, Bluetooth, Caffeine, Night Light, Power Profile, Do Not Disturb, Screenshot, Screen Record
        Grid {
            id: tilesGrid
            width: parent.width
            columns: 2
            spacing: 10

            // 1. WiFi Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: Bar.BarDataService.wifiConnected ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Connectivity org.agility.Daemon.Connectivity ToggleWifi 2>/dev/null || nmcli radio wifi " + (Bar.BarDataService.wifiConnected ? "off" : "on") + " 2>/dev/null || true")
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: Bar.BarDataService.wifiConnected ? "wifi" : "wifi-high-duotone.svg"
                        size: 20
                        color: Bar.BarDataService.wifiConnected ? Theme.colAccent : Theme.colTextSec
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54
                        spacing: 2

                        Text {
                            text: "Wi-Fi"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: Bar.BarDataService.wifiConnected ? Bar.BarDataService.wifiSsid : "Off"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Chevron sub-menu button
                    MouseArea {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PopoutService.open("wifi")

                        GlassIcon {
                            anchors.centerIn: parent
                            source: "chevron-right"
                            size: 14
                            color: Theme.colTextSec
                        }
                    }
                }
            }

            // 2. Bluetooth Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: Bar.BarDataService.bluetoothConnected ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.runCmd("busctl --user call org.agility.Daemon /org/agility/Daemon/Connectivity org.agility.Daemon.Connectivity ToggleBluetooth 2>/dev/null || bluetoothctl power " + (Bar.BarDataService.bluetoothConnected ? "off" : "on") + " 2>/dev/null || true")
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "bluetooth"
                        size: 20
                        color: Bar.BarDataService.bluetoothConnected ? Theme.colAccent : Theme.colTextSec
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 54
                        spacing: 2

                        Text {
                            text: "Bluetooth"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                            elide: Text.ElideRight
                            width: parent.width
                        }
                        Text {
                            text: Bar.BarDataService.bluetoothConnected ? (Bar.BarDataService.bluetoothDeviceCount > 0 ? (Bar.BarDataService.bluetoothDeviceCount + " Devices") : "On") : "Off"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                            elide: Text.ElideRight
                            width: parent.width
                        }
                    }

                    // Chevron sub-menu button
                    MouseArea {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PopoutService.open("bluetooth")

                        GlassIcon {
                            anchors.centerIn: parent
                            source: "chevron-right"
                            size: 14
                            color: Theme.colTextSec
                        }
                    }
                }
            }

            // 3. Caffeine Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: Bar.BarDataService.caffeineActive ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.toggleCaffeine()
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "coffee"
                        size: 20
                        color: Bar.BarDataService.caffeineActive ? Theme.colAccent : Theme.colTextSec
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Caffeine"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: Bar.BarDataService.caffeineActive ? "Active" : "Inactive"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 4. Night Light Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: Bar.BarDataService.nightLightActive ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.toggleNightLight()
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "moon"
                        size: 20
                        color: Bar.BarDataService.nightLightActive ? "#FBBF24" : Theme.colTextSec
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Night Light"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: Bar.BarDataService.nightLightActive ? "Warm (4000K)" : "Off"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 5. Power Profile Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.cyclePowerProfile()
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "battery-charging"
                        size: 20
                        color: Bar.BarDataService.powerProfile === "performance" ? "#EF4444" : (Bar.BarDataService.powerProfile === "power-saver" ? "#10B981" : Theme.colAccent)
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Profile"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: Bar.BarDataService.powerProfile
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 6. Do Not Disturb (DND) Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: Bar.BarDataService.dndEnabled ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: Bar.BarDataService.toggleDnd()
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "bell"
                        size: 20
                        color: Bar.BarDataService.dndEnabled ? Theme.colAccent : Theme.colTextSec
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Do Not Disturb"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: Bar.BarDataService.dndEnabled ? "Silent" : "Normal"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 7. Screenshot Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true

                MouseArea {
                    anchors.fill: parent
                    onClicked: PopoutService.takeScreenshot("fullscreen")
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "camera"
                        size: 20
                        color: Theme.colAccent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Screenshot"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: "Full Screen"
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }

            // 8. Screen Record Tile
            GlassCard {
                width: (tilesGrid.width - 10) / 2
                height: 56
                radius: 14
                isTile: true
                color: PopoutService.isRecording ? Qt.rgba(0.94, 0.27, 0.27, 0.28) : (Theme.isGlass ? "#281D2938" : Theme.colPillBg)

                MouseArea {
                    anchors.fill: parent
                    onClicked: PopoutService.toggleScreenRecord()
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "video"
                        size: 20
                        color: PopoutService.isRecording ? "#EF4444" : Theme.colAccent
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Recording"
                            color: Theme.colText
                            font.family: Theme.fontMain
                            font.pixelSize: 12
                            font.weight: Font.SemiBold
                        }
                        Text {
                            text: PopoutService.isRecording ? "Recording..." : "Idle"
                            color: PopoutService.isRecording ? "#EF4444" : Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }

        // ─── Interactive Glass Sliders (20.2) ───
        // Volume, Microphone, Screen Brightness with real-time D-Bus sync
        GlassCard {
            width: parent.width
            implicitHeight: slidersCol.implicitHeight + 20
            radius: 16

            Column {
                id: slidersCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 12

                // 1. Output Volume Slider
                Row {
                    width: parent.width
                    height: 28
                    spacing: 10

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
                        id: volSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76
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
                        width: 32
                        text: Math.round(Bar.BarDataService.volume * 100) + "%"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // 2. Microphone Volume Slider
                Row {
                    width: parent.width
                    height: 28
                    spacing: 10

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
                        id: micSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76
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
                        width: 32
                        text: Math.round(Bar.BarDataService.micVolume * 100) + "%"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }

                // 3. Screen Brightness Slider
                Row {
                    width: parent.width
                    height: 28
                    spacing: 10

                    GlassIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        source: "sun"
                        size: 18
                        color: "#FBBF24"
                    }

                    GlassSlider {
                        id: brightSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 76
                        minimumValue: 0.05
                        maximumValue: 1.0
                        stepSize: 0.02
                        value: Bar.BarDataService.brightness
                        accentColor: "#FBBF24"
                        onValueChangedByUser: function(v) {
                            Bar.BarDataService.setBrightness(v)
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32
                        text: Math.round(Bar.BarDataService.brightness * 100) + "%"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // ─── Mini Media Player Card ───
        GlassCard {
            width: parent.width
            height: 64
            radius: 16
            visible: Bar.BarDataService.mediaTitle !== "" || Bar.BarDataService.mediaPlaybackStatus === "Playing"

            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 10

                Rectangle {
                    width: 44
                    height: 44
                    radius: 10
                    color: Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.2)
                    border.color: Theme.colAccent
                    border.width: 1

                    GlassIcon {
                        anchors.centerIn: parent
                        source: "music-notes"
                        size: 22
                        color: Theme.colAccent
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 170
                    spacing: 2

                    Text {
                        text: Bar.BarDataService.mediaTitle || "No Media"
                        color: Theme.colText
                        font.family: Theme.fontMain
                        font.pixelSize: 12
                        font.weight: Font.SemiBold
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    Text {
                        text: Bar.BarDataService.mediaArtist || "System Media"
                        color: Theme.colTextSec
                        font.family: Theme.fontMain
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        width: parent.width
                    }
                }

                // Media Playback Controls
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    MouseArea {
                        width: 28
                        height: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.mediaPrevious()

                        GlassIcon {
                            anchors.centerIn: parent
                            source: "skip-back"
                            size: 16
                            color: Theme.colTextSec
                        }
                    }

                    GlassButton {
                        implicitWidth: 32
                        implicitHeight: 32
                        radius: 16
                        primary: true
                        iconSource: Bar.BarDataService.mediaPlaying ? "pause" : "play"
                        onClicked: Bar.BarDataService.toggleMediaPlayPause()
                    }

                    MouseArea {
                        width: 28
                        height: 28
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Bar.BarDataService.mediaNext()

                        GlassIcon {
                            anchors.centerIn: parent
                            source: "skip-forward"
                            size: 16
                            color: Theme.colTextSec
                        }
                    }
                }
            }
        }
    }
}
