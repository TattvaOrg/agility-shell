import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar
import qs.Modules.Bar.Components

Item {
    id: root

    property var notificationService: null
    property var mainPanelWidget: null
    property var controlCenterWidget: null
    property var notificationsCenterWidget: null

    readonly property bool isWaffle: SettingsService.desktopPreset === "bottom_waffle"
    readonly property bool isCompact: SettingsService.desktopPreset === "compact_island"

    readonly property real baseBarHeight: isWaffle ? 46 : (isCompact ? 36 : 42)
    readonly property real currentHeight: baseBarHeight

    readonly property real centerWidth: pillContainer.implicitWidth
    readonly property real centerX: Math.round((root.width - centerWidth) / 2)
    readonly property real leftWidth: 0
    readonly property real rightWidth: 0
    readonly property bool isOccupied: false
    readonly property bool isExpanded: false
    readonly property string activeBarStyle: "material"
    readonly property bool isOverlayActive: false
    readonly property bool isOpen: false
    readonly property bool needsFocus: false
    readonly property real blockX: centerX
    readonly property real blockY: isWaffle ? (root.height - baseBarHeight) : 0
    readonly property real blockWidth: centerWidth
    readonly property real blockHeight: baseBarHeight

    anchors {
        top: isWaffle ? undefined : parent.top
        bottom: isWaffle ? parent.bottom : undefined
        left: parent.left
        right: parent.right
    }
    height: root.baseBarHeight
    implicitWidth: pillContainer.implicitWidth

    Rectangle {
        id: pillContainer

        readonly property real targetWidth: isWaffle ? root.width : (isCompact ? Math.min(root.width - 48, 640) : Math.min(root.width - 32, root.width * 0.94))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: root.baseBarHeight - (isWaffle ? 0 : 4)
        width: targetWidth
        implicitWidth: width
        radius: isWaffle ? 0 : MaterialTheme.pillRadius
        color: MaterialTheme.pillBackground
        border.width: isWaffle ? 0 : 1
        border.color: MaterialTheme.pillBorder

        Behavior on width {
            NumberAnimation { duration: MaterialTheme.animDurationNormal; easing.type: Easing.OutCubic }
        }
        Behavior on height {
            NumberAnimation { duration: MaterialTheme.animDurationNormal; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: MaterialTheme.animDurationNormal }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: isWaffle ? 12 : 16
            anchors.rightMargin: isWaffle ? 12 : 16
            spacing: 10

            // 1. App Launcher / Logo Button
            Rectangle {
                implicitWidth: 32
                implicitHeight: 32
                radius: 16
                color: launcherMouse.containsMouse ? MaterialTheme.m3primaryContainer : MaterialTheme.m3secondaryContainer

                Text {
                    anchors.centerIn: parent
                    text: isWaffle ? "🪟" : "⚡"
                    font.pixelSize: 15
                }

                MouseArea {
                    id: launcherMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.toggleWidget("launcher")
                }
            }

            // 2. Workspaces Pill
            Rectangle {
                implicitHeight: 28
                implicitWidth: workspacesComp.implicitWidth + 12
                radius: 14
                color: MaterialTheme.m3surfaceContainerHigh
                border.width: 1
                border.color: MaterialTheme.withAlpha(MaterialTheme.m3outlineVariant, 0.4)

                Workspaces {
                    id: workspacesComp
                    anchors.centerIn: parent
                    compact: true
                }
            }

            Item { Layout.fillWidth: true }

            // 3. Center Music / Media Chip
            Rectangle {
                visible: MprisService.activePlayer !== null
                implicitHeight: 28
                implicitWidth: Math.min(220, mediaChipRow.implicitWidth + 16)
                radius: 14
                color: MaterialTheme.m3surfaceContainerHigh

                RowLayout {
                    id: mediaChipRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: MprisService.isPlaying ? "🎵" : "⏸"
                        font.pixelSize: 11
                    }

                    Text {
                        Layout.maximumWidth: 160
                        elide: Text.ElideRight
                        text: (MprisService.activePlayer && MprisService.activePlayer.trackTitle) ? MprisService.activePlayer.trackTitle : "Media"
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        font.bold: true
                        color: MaterialTheme.m3onSurface
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (MprisService.activePlayer) MprisService.activePlayer.togglePlaying();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // 4. System Status Pill (Volume + Battery)
            Rectangle {
                implicitHeight: 28
                implicitWidth: statusRow.implicitWidth + 16
                radius: 14
                color: MaterialTheme.m3surfaceContainerHigh

                RowLayout {
                    id: statusRow
                    anchors.centerIn: parent
                    spacing: 8

                    // Audio
                    Text {
                        text: AudioService.micMuted ? "🔇" : "🔊"
                        font.pixelSize: 12
                    }

                    // Battery
                    RowLayout {
                        spacing: 2
                        Text {
                            text: SystemInfoService.batteryStatus === "Charging" ? "⚡" : "🔋"
                            font.pixelSize: 11
                        }
                        Text {
                            text: SystemInfoService.batteryPercentage
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 11
                            font.bold: true
                            color: MaterialTheme.m3onSurface
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.toggleWidget("controlCenter")
                }
            }

            // 5. Date & Time Pill
            Rectangle {
                implicitHeight: 28
                implicitWidth: clockRow.implicitWidth + 16
                radius: 14
                color: MaterialTheme.m3primaryContainer

                RowLayout {
                    id: clockRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: Qt.formatTime(SystemInfoService.currentTime, SettingsService.clock24h ? "HH:mm" : "hh:mm")
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 12
                        font.bold: true
                        color: MaterialTheme.m3onPrimaryContainer
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.toggleWidget("dashboard")
                }
            }

            // 6. Quick Settings / Control Center Toggle
            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: ccMouse.containsMouse ? MaterialTheme.m3surfaceContainerHighest : MaterialTheme.m3surfaceContainerLow

                Text {
                    anchors.centerIn: parent
                    text: "⚙"
                    font.pixelSize: 13
                    color: MaterialTheme.m3onSurface
                }

                MouseArea {
                    id: ccMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.toggleWidget("controlCenter")
                }
            }

            // 7. Power Menu Button
            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                color: powerMouse.containsMouse ? "#ffb4ab" : MaterialTheme.m3surfaceContainerLow

                Text {
                    anchors.centerIn: parent
                    text: "⏻"
                    font.pixelSize: 12
                    color: powerMouse.containsMouse ? "#690005" : MaterialTheme.m3onSurface
                }

                MouseArea {
                    id: powerMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.toggleWidget("powerMenu")
                }
            }
        }
    }
}
