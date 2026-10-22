import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var widget: null
    property date now: new Date()

    implicitWidth: 320
    implicitHeight: 250
    width: implicitWidth
    height: implicitHeight

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Constants.sizeXs
        spacing: Constants.sizeXs

        // SECTION 1: Clock & Date Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            ThemedText {
                text: {
                    if (SettingsService.clock24h)
                        return Qt.formatDateTime(root.now, "HH:mm");

                    let h = root.now.getHours() % 12 || 12;
                    let m = root.now.getMinutes().toString().padStart(2, "0");
                    return h + ":" + m;
                }
                font.bold: true
                customSize: Constants.size4Xl - 6
                color: Theme.barFg
            }

            ColumnLayout {
                spacing: Constants.size3Xs
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    visible: !SettingsService.clock24h
                    color: Theme.barBgSecondary
                    radius: Constants.sizeXs - 2
                    Layout.preferredWidth: apText.implicitWidth + 8
                    Layout.preferredHeight: Constants.sizeLg

                    ThemedText {
                        id: apText

                        anchors.centerIn: parent
                        text: root.now.getHours() >= 12 ? "PM" : "AM"
                        font.bold: true
                        customSize: Constants.sizeXs - 2
                        color: Theme.isLightBar ? Theme.barFg : Theme.accent
                    }
                }

                ThemedText {
                    text: Qt.formatDateTime(root.now, ":ss")
                    customSize: Constants.sizeMd
                    font.bold: true
                    color: Theme.barMuted
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Dynamic Day / Night Large Icon
            SvgIcon {
                readonly property int currentHour: root.now.getHours()
                readonly property bool isDay: currentHour >= 6 && currentHour < 18

                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: Constants.size2Xs
                icon: isDay ? "sun" : "moon-filled"
                iconSize: 34
                iconColor: Theme.isLightBar ? (isDay ? "#e58e00" : Theme.barFg) : Theme.accent
                flat: true
            }
        }

        // Subtitle: Date & Day
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            SvgIcon {
                icon: "calendar"
                iconSize: 14
                iconColor: Theme.isLightBar ? Theme.barFg : Theme.accent
                flat: true
            }

            ThemedText {
                text: Qt.formatDateTime(root.now, "dddd, MMMM d")
                customSize: Constants.sizeSm
                color: Theme.barMuted
                font.bold: true
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            Layout.topMargin: Constants.size3Xs
            Layout.bottomMargin: Constants.size3Xs
            color: Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.08)
        }

        // SECTION 2: Focus & Pomodoro Timer
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeXs

            SvgIcon {
                icon: "clock"
                iconSize: 14
                iconColor: Theme.isLightBar ? Theme.barFg : Theme.accent
                flat: true
            }

            ThemedText {
                text: "Focus Timer"
                font.bold: true
                customSize: Constants.sizeSm
                color: Theme.barFg
            }

            Item {
                Layout.fillWidth: true
            }

            // Status Badge
            Rectangle {
                radius: Constants.sizeXs - 2
                color: FocusTimerService.isRunning
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12))
                    : Theme.barBgSecondary
                Layout.preferredWidth: statusText.implicitWidth + 12
                Layout.preferredHeight: 18

                ThemedText {
                    id: statusText
                    anchors.centerIn: parent
                    text: FocusTimerService.isRunning
                        ? (FocusTimerService.activeMode === "focus" ? "FOCUSING" : "BREAK")
                        : (FocusTimerService.remainingSeconds === 0 ? "DONE" : "READY")
                    customSize: Constants.sizeXs - 3
                    font.bold: true
                    color: FocusTimerService.isRunning
                        ? (Theme.isLightBar ? Theme.barFg : Theme.accent)
                        : Theme.barMuted
                }
            }
        }

        // Countdown Digits & Controls
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd

            ThemedText {
                text: FocusTimerService.formattedTime
                font.bold: true
                customSize: Constants.size4Xl - 6
                color: FocusTimerService.isRunning
                    ? (Theme.isLightBar ? Theme.barFg : Theme.accent)
                    : Theme.barFg
            }

            Item {
                Layout.fillWidth: true
            }

            // Start / Pause Button
            Rectangle {
                id: playBtn
                radius: Constants.sizeXs
                Layout.preferredWidth: playRow.implicitWidth + 14
                Layout.preferredHeight: 28
                color: playMouse.containsMouse
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.16))
                    : (FocusTimerService.isRunning
                        ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.08) : Qt.rgba(255, 255, 255, 0.1))
                        : (Theme.isLightBar ? Theme.barFg : Theme.accent))

                RowLayout {
                    id: playRow
                    anchors.centerIn: parent
                    spacing: Constants.size3Xs

                    SvgIcon {
                        icon: FocusTimerService.isRunning ? "player-pause" : "player-play"
                        iconSize: 12
                        iconColor: playBtn.color === Theme.barFg || (!FocusTimerService.isRunning && !Theme.isLightBar)
                            ? Theme.barBg
                            : (Theme.isLightBar ? Theme.barFg : Theme.accent)
                        flat: true
                    }

                    ThemedText {
                        text: FocusTimerService.isRunning ? "Pause" : "Start"
                        font.bold: true
                        customSize: Constants.sizeXs
                        color: playBtn.color === Theme.barFg || (!FocusTimerService.isRunning && !Theme.isLightBar)
                            ? Theme.barBg
                            : (Theme.isLightBar ? Theme.barFg : Theme.accent)
                    }
                }

                MouseArea {
                    id: playMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FocusTimerService.toggle()
                }
            }

            // Reset Button
            Rectangle {
                id: resetBtn
                radius: Constants.sizeXs
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                color: resetMouse.containsMouse
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.1) : Qt.rgba(255, 255, 255, 0.12))
                    : Theme.barBgSecondary

                SvgIcon {
                    anchors.centerIn: parent
                    icon: "refresh"
                    iconSize: 13
                    iconColor: Theme.barMuted
                    flat: true
                }

                MouseArea {
                    id: resetMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FocusTimerService.reset()
                }
            }
        }

        // Progress Bar
        Rectangle {
            id: progressTrack
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            radius: 2
            color: Theme.barBgSecondary
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * FocusTimerService.progress
                radius: 2
                color: Theme.isLightBar ? Theme.barFg : Theme.accent

                Behavior on width {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }

        // Mode Chips
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.size2Xs

            // Focus Chip
            Rectangle {
                readonly property bool isSelected: FocusTimerService.activeMode === "focus"
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                radius: Constants.sizeXs - 2
                color: isSelected
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14))
                    : (focusChipMouse.containsMouse ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.06)) : "transparent")
                border.width: isSelected ? 1 : 0
                border.color: Theme.isLightBar ? Theme.barFg : Theme.accent

                ThemedText {
                    anchors.centerIn: parent
                    text: "25m Focus"
                    customSize: Constants.sizeXs - 2
                    font.bold: parent.isSelected
                    color: parent.isSelected ? Theme.barFg : Theme.barMuted
                }

                MouseArea {
                    id: focusChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FocusTimerService.setMode("focus")
                }
            }

            // Short Break Chip
            Rectangle {
                readonly property bool isSelected: FocusTimerService.activeMode === "shortBreak"
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                radius: Constants.sizeXs - 2
                color: isSelected
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14))
                    : (shortChipMouse.containsMouse ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.06)) : "transparent")
                border.width: isSelected ? 1 : 0
                border.color: Theme.isLightBar ? Theme.barFg : Theme.accent

                ThemedText {
                    anchors.centerIn: parent
                    text: "5m Short Break"
                    customSize: Constants.sizeXs - 2
                    font.bold: parent.isSelected
                    color: parent.isSelected ? Theme.barFg : Theme.barMuted
                }

                MouseArea {
                    id: shortChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FocusTimerService.setMode("shortBreak")
                }
            }

            // Long Break Chip
            Rectangle {
                readonly property bool isSelected: FocusTimerService.activeMode === "longBreak"
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                radius: Constants.sizeXs - 2
                color: isSelected
                    ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.12) : Qt.rgba(255, 255, 255, 0.14))
                    : (longChipMouse.containsMouse ? (Theme.isLightBar ? Qt.rgba(0, 0, 0, 0.06) : Qt.rgba(255, 255, 255, 0.06)) : "transparent")
                border.width: isSelected ? 1 : 0
                border.color: Theme.isLightBar ? Theme.barFg : Theme.accent

                ThemedText {
                    anchors.centerIn: parent
                    text: "15m Long Break"
                    customSize: Constants.sizeXs - 2
                    font.bold: parent.isSelected
                    color: parent.isSelected ? Theme.barFg : Theme.barMuted
                }

                MouseArea {
                    id: longChipMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: FocusTimerService.setMode("longBreak")
                }
            }
        }
    }
}
