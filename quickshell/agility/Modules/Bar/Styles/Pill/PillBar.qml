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

    readonly property real baseBarHeight: BarStyleConfig.barHeight("pill")
    readonly property real currentHeight: baseBarHeight
    readonly property real centerWidth: pillContainer.implicitWidth
    readonly property real centerX: Math.round((root.width - centerWidth) / 2)
    readonly property real leftWidth: 0
    readonly property real rightWidth: 0
    readonly property bool isOccupied: false
    readonly property bool isExpanded: false
    readonly property string activeBarStyle: "pill"
    readonly property bool isOverlayActive: false
    readonly property bool isOpen: false
    readonly property bool needsFocus: false
    readonly property real blockX: centerX
    readonly property real blockY: 0
    readonly property real blockWidth: centerWidth
    readonly property real blockHeight: baseBarHeight

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: root.baseBarHeight

    function close() {
    }

    Rectangle {
        id: pillContainer

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: root.baseBarHeight
        implicitWidth: contentRow.implicitWidth + (Constants.sizeLg * 2)
        radius: height / 2
        color: Theme.bg
        border.color: Theme.borderSecondary
        border.width: 1

        RowLayout {
            id: contentRow

            anchors.centerIn: parent
            spacing: Constants.sizeSm

            // Left Section (Material 3 Star button, Launcher, Workspaces)
            MinflairButton {
                id: minflairBtn
                Layout.alignment: Qt.AlignVCenter
            }

            BarButton {
                id: appMenuBtn
                widgetId: "launcher"
                icon: "apps"
                iconSize: Constants.sizeLg
                Layout.alignment: Qt.AlignVCenter
            }

            Workspaces {
                id: workspacesWidget
                Layout.alignment: Qt.AlignVCenter
                visible: true
            }

            // Subtle Divider
            Rectangle {
                width: 1
                height: 16
                color: Theme.borderSecondary
                Layout.alignment: Qt.AlignVCenter
                opacity: 0.6
            }

            // Center Section (Clock & Media)
            ClockButton {
                id: clockBtn
                Layout.alignment: Qt.AlignVCenter
            }

            MediaButton {
                id: mediaBtn
                Layout.alignment: Qt.AlignVCenter
            }

            // Subtle Divider
            Rectangle {
                width: 1
                height: 16
                color: Theme.borderSecondary
                Layout.alignment: Qt.AlignVCenter
                opacity: 0.6
            }

            // Right Section (Recording, Tray, CC, Notif, Power)
            RecordingIndicator {
                id: recIndicator
                Layout.alignment: Qt.AlignVCenter
                visible: RecorderService.running
            }

            SystemTrayGroup {
                id: systemTray
                Layout.alignment: Qt.AlignVCenter
            }

            ControlCenterButton {
                id: ccBtn
                Layout.alignment: Qt.AlignVCenter
                controlCenterWidget: root.controlCenterWidget
            }

            NotificationsButton {
                id: notifBtn
                Layout.alignment: Qt.AlignVCenter
                notificationsCenterWidget: root.notificationsCenterWidget
                notificationService: root.notificationService
            }

            PowerButton {
                id: powerBtn
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
