/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/clock/),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "clock"
    displayName: "Clock"
    sizeModes: ["digital", "cookie", "daily", "stacked"]
    sizeMode: EndWidgetStore.getPref("clock", "style", "digital")

    baseWidth: sizeMode === "cookie" ? 220 : (sizeMode === "stacked" ? 200 : 280)
    baseHeight: sizeMode === "cookie" ? 220 : (sizeMode === "stacked" ? 210 : 112)

    property string hoursStr: "00"
    property string minutesStr: "00"
    property string dateStr: ""
    property real secondsSmooth: 0

    function updateClock() {
        let now = new Date();
        let h = now.getHours();
        let m = now.getMinutes();
        if (!SettingsService.clock24h)
            h = h % 12 || 12;
        hoursStr = h < 10 ? "0" + h : String(h);
        minutesStr = m < 10 ? "0" + m : String(m);
        dateStr = Qt.locale().toString(now, "dddd, MMM d");
        secondsSmooth = now.getSeconds() + now.getMilliseconds() / 1000.0;
    }

    Timer {
        interval: root.sizeMode === "cookie" ? 100 : 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateClock()
    }

    // Style 1: Expressive Digital (matches reference screenshot)
    Item {
        anchors.fill: parent
        visible: root.sizeMode === "digital"

        Row {
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.hoursStr
                color: EndTheme.primary
                font.family: SettingsService.fontFamily
                font.pixelSize: 88
                font.weight: Font.Black
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.45)
            }

            Text {
                text: ":"
                color: EndTheme.secondary
                font.family: SettingsService.fontFamily
                font.pixelSize: 84
                font.weight: Font.Black
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.45)
            }

            Text {
                text: root.minutesStr
                color: EndTheme.primary
                font.family: SettingsService.fontFamily
                font.pixelSize: 88
                font.weight: Font.Black
                style: Text.Raised
                styleColor: Qt.rgba(0, 0, 0, 0.45)
            }
        }
    }

    // Style 2: Material 3 Cookie Analog Clock
    Item {
        anchors.fill: parent
        visible: root.sizeMode === "cookie"

        MaterialShape {
            anchors.fill: parent
            shape: MaterialShape.Shape.Cookie9Sided
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.78)
            borderWidth: 0.012
            borderColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.45)
        }

        // Hour hand
        Item {
            anchors.centerIn: parent
            width: 12
            height: parent.height
            rotation: ((new Date().getHours() % 12) + new Date().getMinutes() / 60.0) * 30

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: -6
                width: 10
                height: 54
                radius: 5
                color: Theme.fg
            }
        }

        // Minute hand
        Item {
            anchors.centerIn: parent
            width: 8
            height: parent.height
            rotation: (new Date().getMinutes() + root.secondsSmooth / 60.0) * 6

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.verticalCenter
                anchors.bottomMargin: -4
                width: 7
                height: 76
                radius: 3.5
                color: Theme.accent
            }
        }

        // Orbiting second dot
        Item {
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            rotation: root.secondsSmooth * 6

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 22
                width: 10
                height: 10
                radius: 5
                color: Theme.accentComplementary
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 12
            height: 12
            radius: 6
            color: Theme.accent
        }
    }

    // Style 3: Daily Pill Badge Clock
    EndWidgetCard {
        anchors.fill: parent
        visible: root.sizeMode === "daily"

        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hoursStr + ":" + root.minutesStr
                color: Theme.fg
                font.family: SettingsService.fontFamily
                font.pixelSize: 48
                font.weight: Font.Bold
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: badgeTxt.implicitWidth + 20
                implicitHeight: 24
                radius: 12
                color: Theme.bgAccent

                Text {
                    id: badgeTxt
                    anchors.centerIn: parent
                    text: root.dateStr
                    color: Theme.accent
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
            }
        }
    }

    // Style 4: Stacked 2-Line Clock
    EndWidgetCard {
        anchors.fill: parent
        visible: root.sizeMode === "stacked"

        Column {
            anchors.centerIn: parent
            spacing: -14

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.hoursStr
                color: Theme.accent
                font.family: SettingsService.fontFamily
                font.pixelSize: 78
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.minutesStr
                color: Theme.fg
                font.family: SettingsService.fontFamily
                font.pixelSize: 78
                font.weight: Font.Black
            }
        }
    }
}
