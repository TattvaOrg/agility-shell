import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property bool isExpanded: false
    property bool isClipboardToastActive: false
    property string clipboardToastText: ""

    function showClipboardToast(text) {
        if (!SettingsService.dynamicIslandEnabled)
            return;
        root.clipboardToastText = text.trim().replace(/\s+/g, " ");
        root.isClipboardToastActive = true;
        clipboardTimer.restart();
    }

    Timer {
        id: clipboardTimer
        interval: 3500
        repeat: false
        onTriggered: {
            root.isClipboardToastActive = false;
        }
    }

    Connections {
        target: ClipboardService.model
        function onRowsInserted(parent, first, last) {
            if (first === 0 && ClipboardService.model.count > 0) {
                let itm = ClipboardService.model.get(0);
                if (itm && itm.text && !itm.isImage) {
                    root.showClipboardToast(itm.text);
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: islandWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:dynamic-island"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            focusable: false
            visible: SettingsService.settingsLoaded && SettingsService.dynamicIslandEnabled && !DisplayProfileService.gameModeActive

            anchors {
                top: true
            }

            // Determine active state: expanded, clipboard toast, music, timer, or idle
            readonly property bool hasMusic: MprisService.isPlaying || (MprisService.activePlayer !== null && Boolean(MprisService.activePlayer.trackTitle))
            readonly property bool hasTimer: FocusTimerService.isRunning
            readonly property bool hasToast: root.isClipboardToastActive
            readonly property bool isBatteryLow: SystemInfoService.hasBattery && SystemInfoService.batteryLevel <= 15 && SystemInfoService.batteryStatus === "Discharging"

            readonly property real targetWidth: {
                if (root.isExpanded)
                    return 390;
                if (hasToast)
                    return 340;
                if (hasMusic)
                    return 280;
                if (hasTimer)
                    return 230;
                if (isBatteryLow)
                    return 240;
                return 180;
            }

            readonly property real targetHeight: {
                if (root.isExpanded)
                    return 165;
                if (hasToast)
                    return 42;
                return 36;
            }

            implicitWidth: targetWidth + 40
            implicitHeight: targetHeight + 30

            mask: Region {
                item: islandCard
            }

            // Island Capsule Card
            Rectangle {
                id: islandCard
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter

                width: islandWindow.targetWidth
                height: islandWindow.targetHeight
                radius: root.isExpanded ? 24 : (height / 2)

                color: Theme.isDark ? Qt.rgba(0.04, 0.05, 0.07, 0.94) : Qt.rgba(0.96, 0.96, 0.98, 0.95)
                border.width: 1
                border.color: islandHover.containsMouse ? Theme.accent : Theme.border
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutBack
                        easing.overshoot: 1.1
                    }
                }

                Behavior on radius {
                    NumberAnimation {
                        duration: Constants.animNormal
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    id: islandHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton
                    onClicked: {
                        if (islandWindow.hasMusic || islandWindow.hasTimer) {
                            root.isExpanded = !root.isExpanded;
                        }
                    }
                }

                // ─────────────────────────────────────────────
                // 1. COLLAPSED VIEW
                // ─────────────────────────────────────────────
                Item {
                    id: compactView
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    visible: !root.isExpanded

                    // 1A. CLIPBOARD TOAST STATE
                    RowLayout {
                        anchors.fill: parent
                        visible: islandWindow.hasToast
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                            radius: 12
                            color: Qt.rgba(0.2, 0.8, 0.4, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "clipboard"
                                iconSize: 14
                                flat: true
                                iconColor: "#4ade80"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Copied: " + root.clipboardToastText
                            color: Theme.text
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        SvgIcon {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            icon: "check"
                            iconSize: 14
                            flat: true
                            iconColor: "#4ade80"
                        }
                    }

                    // 1B. MUSIC ACTIVITY STATE
                    RowLayout {
                        anchors.fill: parent
                        visible: !islandWindow.hasToast && islandWindow.hasMusic
                        spacing: 8

                        // Spinning Vinyl / Album Art Thumbnail
                        Item {
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24

                            Rectangle {
                                id: vinylDisc
                                anchors.fill: parent
                                radius: 12
                                color: Theme.bgSecondary
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
                                    fillMode: Image.PreserveAspectCrop
                                    visible: status === Image.Ready
                                }

                                SvgIcon {
                                    anchors.centerIn: parent
                                    icon: "music"
                                    iconSize: 12
                                    flat: true
                                    iconColor: Theme.accent
                                    visible: !MprisService.activePlayer || !MprisService.activePlayer.trackArtUrl
                                }

                                RotationAnimation on rotation {
                                    running: MprisService.isPlaying && !root.isExpanded
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 7000
                                }
                            }
                        }

                        // Track Title & Artist
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: MprisService.activePlayer ? (MprisService.activePlayer.trackTitle || "Audio Playing") : ""
                                color: Theme.text
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: MprisService.activePlayer ? (MprisService.activePlayer.trackArtist || MprisService.activePlayerName) : ""
                                color: Theme.muted
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }

                        // Bouncing Audio Bars Visualizer
                        RowLayout {
                            Layout.preferredHeight: 16
                            spacing: 2

                            Repeater {
                                model: 4

                                Rectangle {
                                    required property int index
                                    width: 3
                                    radius: 1.5
                                    color: Theme.accent

                                    SequentialAnimation on height {
                                        running: MprisService.isPlaying
                                        loops: Animation.Infinite
                                        NumberAnimation {
                                            from: 4
                                            to: [14, 8, 16, 10][index]
                                            duration: [300, 420, 260, 380][index]
                                            easing.type: Easing.InOutQuad
                                        }
                                        NumberAnimation {
                                            from: [14, 8, 16, 10][index]
                                            to: 4
                                            duration: [300, 420, 260, 380][index]
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 1C. FOCUS TIMER ACTIVITY STATE
                    RowLayout {
                        anchors.fill: parent
                        visible: !islandWindow.hasToast && !islandWindow.hasMusic && islandWindow.hasTimer
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Qt.rgba(0.9, 0.4, 0.1, 0.2)

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "clock"
                                iconSize: 12
                                flat: true
                                iconColor: "#fb923c"
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: FocusTimerService.activeMode === "focus" ? "Focus Session" : "Break"
                            color: Theme.text
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            text: FocusTimerService.formattedTime
                            color: "#fb923c"
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            font.family: "monospace"
                        }
                    }

                    // 1D. LOW BATTERY ALERT STATE
                    RowLayout {
                        anchors.fill: parent
                        visible: !islandWindow.hasToast && !islandWindow.hasMusic && !islandWindow.hasTimer && islandWindow.isBatteryLow
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            radius: 11
                            color: Qt.rgba(0.9, 0.2, 0.2, 0.2)

                            Text {
                                anchors.centerIn: parent
                                text: "⚡"
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Battery Low (" + SystemInfoService.batteryPercentage + ")"
                            color: "#ef4444"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                        }
                    }

                    // 1E. IDLE STATE
                    RowLayout {
                        anchors.fill: parent
                        visible: !islandWindow.hasToast && !islandWindow.hasMusic && !islandWindow.hasTimer && !islandWindow.isBatteryLow
                        spacing: 8

                        SvgIcon {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            icon: "rocket"
                            iconSize: 14
                            flat: true
                            iconColor: Theme.accent
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "Agility"
                            color: Theme.textSecondary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: Qt.formatTime(SystemInfoService.currentTime, "hh:mm")
                            color: Theme.muted
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }
                }

                // ─────────────────────────────────────────────
                // 2. EXPANDED VIEW (Media Controller / Focus Timer)
                // ─────────────────────────────────────────────
                ColumnLayout {
                    id: expandedView
                    anchors.fill: parent
                    anchors.margins: 12
                    visible: root.isExpanded
                    spacing: 8

                    // Top Bar with App Badge and Close Button
                    RowLayout {
                        Layout.fillWidth: true

                        Rectangle {
                            Layout.preferredHeight: 20
                            Layout.preferredWidth: appBadge.implicitWidth + 16
                            radius: 10
                            color: Qt.rgba(1, 1, 1, 0.08)

                            Text {
                                id: appBadge
                                anchors.centerIn: parent
                                text: islandWindow.hasMusic ? MprisService.activePlayerName : "Focus Timer"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                                color: Theme.accent
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            radius: 10
                            color: closeMouse.containsMouse ? Theme.surfaceHover : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "✕"
                                font.pixelSize: 11
                                color: Theme.muted
                            }

                            MouseArea {
                                id: closeMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.isExpanded = false
                            }
                        }
                    }

                    // 2A. EXPANDED MUSIC PLAYER
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: islandWindow.hasMusic
                        spacing: 12

                        // Big Album Art
                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 64
                            radius: 12
                            color: Theme.bgSecondary
                            clip: true

                            Image {
                                anchors.fill: parent
                                source: MprisService.activePlayer ? (MprisService.activePlayer.trackArtUrl || "") : ""
                                fillMode: Image.PreserveAspectCrop
                                visible: status === Image.Ready
                            }

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "music"
                                iconSize: 28
                                flat: true
                                iconColor: Theme.accent
                                visible: !MprisService.activePlayer || !MprisService.activePlayer.trackArtUrl
                            }
                        }

                        // Track Info & Controls
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                Layout.fillWidth: true
                                text: MprisService.activePlayer ? (MprisService.activePlayer.trackTitle || "No Track") : ""
                                font.pixelSize: 13
                                font.weight: Font.Bold
                                color: Theme.text
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: MprisService.activePlayer ? (MprisService.activePlayer.trackArtist || "Unknown Artist") : ""
                                font.pixelSize: 11
                                color: Theme.muted
                                elide: Text.ElideRight
                            }

                            // Interactive Media Buttons
                            RowLayout {
                                spacing: 14

                                // Previous
                                SvgIcon {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    icon: "chevron-left"
                                    iconSize: 18
                                    flat: true
                                    iconColor: prevMouse.containsMouse ? Theme.accent : Theme.textSecondary

                                    MouseArea {
                                        id: prevMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (MprisService.activePlayer)
                                                MprisService.activePlayer.previous();
                                        }
                                    }
                                }

                                // Play / Pause
                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: Theme.accent

                                    Text {
                                        anchors.centerIn: parent
                                        text: MprisService.isPlaying ? "❚❚" : "▶"
                                        font.pixelSize: 11
                                        color: Theme.bg
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (MprisService.activePlayer)
                                                MprisService.activePlayer.togglePlaying();
                                        }
                                    }
                                }

                                // Next
                                SvgIcon {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    icon: "chevron-right"
                                    iconSize: 18
                                    flat: true
                                    iconColor: nextMouse.containsMouse ? Theme.accent : Theme.textSecondary

                                    MouseArea {
                                        id: nextMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: {
                                            if (MprisService.activePlayer)
                                                MprisService.activePlayer.next();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 2B. EXPANDED FOCUS TIMER
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: !islandWindow.hasMusic && islandWindow.hasTimer
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                text: FocusTimerService.formattedTime
                                font.pixelSize: 26
                                font.weight: Font.Bold
                                font.family: "monospace"
                                color: "#fb923c"
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: FocusTimerService.activeMode === "focus" ? "Stay Focused" : "Rest & Recharge"
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    color: Theme.text
                                }

                                Text {
                                    text: "Session in progress"
                                    font.pixelSize: 10
                                    color: Theme.muted
                                }
                            }

                            // Timer Play/Pause Toggle
                            Rectangle {
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 14
                                color: "#fb923c"

                                Text {
                                    anchors.centerIn: parent
                                    text: FocusTimerService.isRunning ? "❚❚" : "▶"
                                    font.pixelSize: 11
                                    color: Theme.bg
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: FocusTimerService.toggleTimer()
                                }
                            }
                        }

                        // Mode Selector Pills
                        RowLayout {
                            spacing: 8

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 64
                                radius: 11
                                color: FocusTimerService.activeMode === "focus" ? Qt.rgba(0.9, 0.4, 0.1, 0.3) : "transparent"
                                border.width: 1
                                border.color: FocusTimerService.activeMode === "focus" ? "#fb923c" : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Focus"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: FocusTimerService.activeMode === "focus" ? "#fb923c" : Theme.muted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: FocusTimerService.setMode("focus")
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 64
                                radius: 11
                                color: FocusTimerService.activeMode === "shortBreak" ? Qt.rgba(0.2, 0.8, 0.4, 0.3) : "transparent"
                                border.width: 1
                                border.color: FocusTimerService.activeMode === "shortBreak" ? "#4ade80" : Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Break"
                                    font.pixelSize: 10
                                    font.weight: Font.DemiBold
                                    color: FocusTimerService.activeMode === "shortBreak" ? "#4ade80" : Theme.muted
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: FocusTimerService.setMode("shortBreak")
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.preferredHeight: 22
                                Layout.preferredWidth: 54
                                radius: 11
                                color: resetHover.containsMouse ? Theme.surfaceHover : "transparent"
                                border.width: 1
                                border.color: Theme.border

                                Text {
                                    anchors.centerIn: parent
                                    text: "Reset"
                                    font.pixelSize: 10
                                    color: Theme.muted
                                }

                                MouseArea {
                                    id: resetHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: FocusTimerService.resetTimer()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
