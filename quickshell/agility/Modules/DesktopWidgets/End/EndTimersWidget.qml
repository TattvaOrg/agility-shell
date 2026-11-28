/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/timers/TimerWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Connects Focus Pomodoro to Agility Shell's FocusTimerService.
 * Combined under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "timers"
    displayName: "Timers"
    supportsFlip: true
    isVertical: EndWidgetStore.getPref("timers", "vertical", false)

    baseWidth: isVertical ? 132 : 420
    baseHeight: isVertical ? 384 : 118

    // Local Stopwatch & Countdown state
    property bool stopwatchRunning: false
    property int stopwatchDeciseconds: 0
    property bool countdownRunning: false
    property int countdownSeconds: 0

    function formatMinSec(totalSecs) {
        let s = Math.max(0, Math.floor(totalSecs));
        let mins = Math.floor(s / 60);
        let rem = s % 60;
        return mins + ":" + (rem < 10 ? "0" + rem : rem);
    }

    Timer {
        interval: 100
        running: root.stopwatchRunning && root.visible
        repeat: true
        onTriggered: root.stopwatchDeciseconds++
    }

    Timer {
        interval: 1000
        running: root.countdownRunning && root.visible
        repeat: true
        onTriggered: {
            if (root.countdownSeconds > 1) {
                root.countdownSeconds--;
            } else {
                root.countdownSeconds = 0;
                root.countdownRunning = false;
                SoundService.play("alarm");
            }
        }
    }

    component TimerTile: EndWidgetCard {
        property string iconName: "clock"
        property string valueText: "0:00"
        property string labelText: ""
        property bool active: false
        property int shapeType: MaterialShape.Shape.Flower
        property color badgeColor: EndTheme.primary
        property color badgeIconColor: EndTheme.onPrimary
        property var onToggle: null
        property var onReset: null
        default property alias extraSlotContent: extraSlot.data

        implicitWidth: 132
        implicitHeight: 118
        width: 132
        height: 118
        trackX: x
        trackY: y

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (onReset)
                    onReset();
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2

            Item {
                Layout.alignment: Qt.AlignRight
                width: 34
                height: 34

                MaterialShape {
                    anchors.fill: parent
                    shape: shapeType
                    color: badgeColor
                }
                SvgIcon {
                    anchors.centerIn: parent
                    icon: active ? "player-pause" : iconName
                    iconSize: 15
                    iconColor: badgeIconColor
                    flat: true
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (onToggle)
                            onToggle();
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: valueText
                color: EndTheme.onCard
                font.family: SettingsService.fontFamily
                font.pixelSize: 18
                font.weight: Font.Bold
            }
            Text {
                text: labelText
                color: EndTheme.onCardMuted
                font.family: SettingsService.fontFamily
                font.pixelSize: 11
            }

            Item {
                id: extraSlot
                Layout.fillWidth: true
                Layout.preferredHeight: children.length > 0 ? 20 : 0
            }
        }
    }

    Grid {
        columns: root.isVertical ? 1 : 3
        rows: root.isVertical ? 3 : 1
        spacing: 12

        TimerTile {
            iconName: "coffee"
            valueText: FocusTimerService.formattedTime
            labelText: FocusTimerService.activeMode === "focus" ? "Focus" : "Break"
            active: FocusTimerService.isRunning
            shapeType: MaterialShape.Shape.Flower
            badgeColor: EndTheme.primary
            badgeIconColor: EndTheme.onPrimary
            onToggle: function() { FocusTimerService.toggle(); }
            onReset: function() { FocusTimerService.reset(); }
        }

        TimerTile {
            iconName: "3s"
            valueText: root.formatMinSec(root.stopwatchDeciseconds / 10)
            labelText: "Stopwatch"
            active: root.stopwatchRunning
            shapeType: MaterialShape.Shape.Sunny
            badgeColor: EndTheme.secondary
            badgeIconColor: EndTheme.onSecondary
            onToggle: function() { root.stopwatchRunning = !root.stopwatchRunning; }
            onReset: function() { root.stopwatchRunning = false; root.stopwatchDeciseconds = 0; }
        }

        TimerTile {
            iconName: "clock"
            valueText: root.formatMinSec(root.countdownSeconds)
            labelText: "Countdown"
            active: root.countdownRunning
            shapeType: MaterialShape.Shape.Bun
            badgeColor: EndTheme.tertiary
            badgeIconColor: EndTheme.onTertiary
            onToggle: function() {
                if (root.countdownSeconds > 0)
                    root.countdownRunning = !root.countdownRunning;
            }
            onReset: function() { root.countdownRunning = false; root.countdownSeconds = 0; }

            RowLayout {
                anchors.fill: parent
                spacing: 4
                Repeater {
                    model: [1, 5]
                    Rectangle {
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 10
                        color: EndTheme.chipBg
                        border.width: 1
                        border.color: EndTheme.chipBorder

                        Text {
                            anchors.centerIn: parent
                            text: "+" + modelData + "m"
                            color: EndTheme.onCard
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 9
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.countdownSeconds += modelData * 60
                        }
                    }
                }
            }
        }
    }
}
