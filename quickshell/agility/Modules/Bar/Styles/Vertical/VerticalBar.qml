import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
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

    readonly property bool isConvexStyle: SettingsService.barStyle === "convex"
    readonly property real baseBarWidth: 44
    readonly property real currentHeight: root.height

    readonly property real centerWidth: root.width
    readonly property real centerX: 0
    readonly property real leftWidth: 0
    readonly property real rightWidth: 0
    readonly property bool isOccupied: false
    readonly property bool isExpanded: false
    readonly property string activeBarStyle: "vertical"
    readonly property bool isOverlayActive: false
    readonly property bool isOpen: false
    readonly property bool needsFocus: false
    readonly property real blockX: 0
    readonly property real blockY: 0
    readonly property real blockWidth: root.width
    readonly property real blockHeight: root.height

    anchors.fill: parent

    function close() {
    }

    Rectangle {
        id: railContainer

        readonly property real bgAlpha: (SettingsService.barGlassMode === "solid") ? 1.0 : (SettingsService.barGlassOpacity / 100)
        readonly property color baseBgColor: {
            if (SettingsService.barGlassMode === "solid") {
                return (SettingsService.barSolidTone === "white") ? Theme.solidWhiteBarBg : Qt.rgba(0.04, 0.04, 0.05, 0.95);
            }
            if (SettingsService.barGlassMode === "adaptive")
                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, bgAlpha * 0.75);
            return Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgAlpha);
        }

        anchors.fill: parent
        anchors.topMargin: root.isConvexStyle ? 0 : 8
        anchors.bottomMargin: root.isConvexStyle ? 0 : 8
        anchors.leftMargin: root.isConvexStyle ? 0 : 4
        anchors.rightMargin: root.isConvexStyle ? 0 : 4

        radius: root.isConvexStyle ? 0 : (width / 2)
        color: baseBgColor
        border.width: 1
        border.color: Theme.border

        ThemedShadow {
            anchors.fill: parent
            radius: parent.radius
            opacity: 0.4
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: root.isConvexStyle ? 12 : 16
            anchors.bottomMargin: root.isConvexStyle ? 12 : 16
            anchors.leftMargin: 4
            anchors.rightMargin: 4
            spacing: 8

            // Top Group: App Launcher Logo & Workspaces
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                spacing: 10

                MinflairButton {
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 20
                    height: 1
                    color: Theme.border
                    opacity: 0.6
                }

                Workspaces {
                    Layout.alignment: Qt.AlignHCenter
                    vertical: true
                    compact: true
                    bgColor: "transparent"
                }
            }

            // Expanding spacer
            Item {
                Layout.fillHeight: true
            }

            // Center Group: Compact Vertical Clock
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 32
                Layout.preferredHeight: clockCol.implicitHeight + 8
                radius: 8
                color: Theme.bgSecondary

                ColumnLayout {
                    id: clockCol
                    anchors.centerIn: parent
                    spacing: 1

                    ThemedText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(new Date(), SettingsService.clock24h ? "HH" : "hh")
                        customSize: 11
                        font.weight: Font.Bold
                        color: Theme.accent
                    }

                    ThemedText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Qt.formatDateTime(new Date(), "mm")
                        customSize: 11
                        font.weight: Font.Bold
                        color: Theme.fg
                    }
                }

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        clockCol.children[0].text = Qt.formatDateTime(new Date(), SettingsService.clock24h ? "HH" : "hh");
                        clockCol.children[1].text = Qt.formatDateTime(new Date(), "mm");
                    }
                }
            }

            // Expanding spacer
            Item {
                Layout.fillHeight: true
            }

            // Bottom Group: Indicators & Power
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                spacing: 8

                ControlCenterButton {
                    Layout.alignment: Qt.AlignHCenter
                }

                NotificationsButton {
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 20
                    height: 1
                    color: Theme.border
                    opacity: 0.6
                }

                PowerButton {
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
