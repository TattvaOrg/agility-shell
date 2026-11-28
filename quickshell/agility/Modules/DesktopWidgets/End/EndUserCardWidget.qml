/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/usercard/UserCardWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "userCard"
    displayName: "User Card"
    sizeModes: ["1x2", "1x1", "2x2", "2x3"]
    sizeMode: EndWidgetStore.getPref("userCard", "sizeMode", "1x2")

    baseWidth: sizeMode === "1x1" ? 128 : (sizeMode === "2x3" ? 420 : 276)
    baseHeight: (sizeMode === "1x1" || sizeMode === "1x2") ? 118 : 250

    property string username: (SystemInfoService.username && SystemInfoService.username !== "Loading...")
        ? SystemInfoService.username
        : (Quickshell.env("USER") || "User")
    property string hostname: (SystemInfoService.hostname && SystemInfoService.hostname !== "Loading...")
        ? SystemInfoService.hostname
        : "linux"
    property string avatarPath: ""
    property int uptimeSeconds: 0

    readonly property int uptimeDays: Math.floor(uptimeSeconds / 86400)
    readonly property int uptimeHours: Math.floor((uptimeSeconds % 86400) / 3600)
    readonly property int uptimeMinutes: Math.floor((uptimeSeconds % 3600) / 60)

    readonly property string greetingText: {
        let h = new Date().getHours();
        if (h < 12) return "Good Morning";
        if (h < 18) return "Good Afternoon";
        return "Good Evening";
    }
    readonly property string todayString: "Today • " + Qt.locale().toString(new Date(), "dddd d MMM")

    Process {
        id: avatarCheckProc
        command: ["sh", "-c", "for p in \"$HOME/.face\" \"$HOME/.face.icon\" \"$HOME/.config/agility-shell/avatar.png\"; do if [ -f \"$p\" ]; then echo \"$p\"; exit 0; fi; done"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                let p = text.trim();
                if (p !== "")
                    root.avatarPath = "file://" + p;
            }
        }
    }

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                let secs = parseFloat(text.trim().split(" ")[0]);
                if (!isNaN(secs))
                    root.uptimeSeconds = Math.floor(secs);
            }
        }
    }

    Process {
        id: lockProc
        command: ["agl", "lock"]
    }

    Timer {
        interval: 60000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProc.running = true
    }

    component AvatarView: Rectangle {
        property real avRadius: 20
        radius: avRadius
        color: Theme.bgAccent
        clip: true

        Image {
            id: avImg
            anchors.fill: parent
            source: root.avatarPath
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: root.avatarPath !== "" && status === Image.Ready
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: avImg.width
                    height: avImg.height
                    radius: avRadius
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.avatarPath === "" || avImg.status !== Image.Ready
            text: root.username.length > 0 ? root.username.charAt(0).toUpperCase() : "A"
            color: Theme.accent
            font.family: SettingsService.fontFamily
            font.pixelSize: Math.round(height * 0.42)
            font.weight: Font.Bold
        }
    }

    // 1x1: Avatar only
    AvatarView {
        anchors.fill: parent
        avRadius: 24
        visible: root.sizeMode === "1x1"
    }

    // 1x2: Compact greeting card (matches screenshot top-left)
    EndWidgetCard {
        anchors.fill: parent
        visible: root.sizeMode === "1x2"

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            AvatarView {
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                avRadius: 18
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 2

                Item { Layout.fillHeight: true }

                Text {
                    Layout.fillWidth: true
                    text: "Hi, " + root.username + "!"
                    color: EndTheme.onCard
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.greetingText
                    color: EndTheme.onCard
                    opacity: 0.85
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.todayString
                    color: EndTheme.onCardMuted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    // 2x2 and 2x3: Profile + Uptime + Quick actions
    EndWidgetCard {
        anchors.fill: parent
        visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                AvatarView {
                    Layout.preferredWidth: 64
                    Layout.preferredHeight: 64
                    avRadius: 32
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        Layout.fillWidth: true
                        text: root.username + "@" + root.hostname
                        color: Theme.fg
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Up • " + root.uptimeDays + "d " + root.uptimeHours + "h " + root.uptimeMinutes + "m"
                        color: Theme.muted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: WeatherService.conditionText + " • " + WeatherService.displayTemp
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 19
                    color: Theme.accent

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        SvgIcon {
                            icon: "lock"
                            iconSize: 14
                            iconColor: Theme.isDark ? "#000000" : "#ffffff"
                            flat: true
                        }
                        Text {
                            text: "Lock"
                            color: Theme.isDark ? "#000000" : "#ffffff"
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: lockProc.startDetached()
                    }
                }

                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: 19
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "settings-icon"
                        iconSize: 16
                        iconColor: Theme.fg
                        flat: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("minflair_settings")
                    }
                }

                Rectangle {
                    implicitWidth: 38
                    implicitHeight: 38
                    radius: 19
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "power"
                        iconSize: 16
                        iconColor: Theme.fg
                        flat: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.toggleWidget("powerMenu")
                    }
                }
            }
        }
    }
}
