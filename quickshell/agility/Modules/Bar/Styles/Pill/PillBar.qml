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

    readonly property real baseBarHeight: BarStyleConfig.barHeight("pill")
    readonly property real currentHeight: baseBarHeight
    readonly property real thicknessScale: Math.max(0.68, Math.min(1.4, root.baseBarHeight / 38.0))

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
    implicitWidth: pillContainer.implicitWidth

    function close() {
    }

    Rectangle {
        id: pillContainer

        readonly property real minPillWidth: Math.max(
            Math.max(leftGroup.implicitWidth, rightGroup.implicitWidth) * 2 + centerGroup.implicitWidth + (Constants.sizeLg * 4),
            480
        )
        readonly property real targetPillWidth: Math.round(root.width * (SettingsService.pillBarWidthPercent / 100))
        readonly property bool isFullWidth: SettingsService.pillBarWidthPercent >= 100

        readonly property real bgAlpha: (SettingsService.barGlassMode === "solid") ? 1.0 : (SettingsService.barGlassOpacity / 100)
        readonly property color baseBgColor: {
            if (SettingsService.barGlassMode === "adaptive")
                return Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, bgAlpha * 0.65);
            return Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgAlpha);
        }

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        height: root.baseBarHeight
        width: Math.max(minPillWidth, Math.min(root.width - (isFullWidth ? 0 : Constants.sizeMd * 2), targetPillWidth))
        implicitWidth: width
        radius: isFullWidth ? Constants.sizeSm : height / 2
        color: baseBgColor
        border.color: SettingsService.barGlassMode === "adaptive" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.4) : Theme.borderSecondary
        border.width: 1

        gradient: SettingsService.barGlassMode === "gradient" ? gradientDef : null

        Gradient {
            id: gradientDef
            GradientStop { position: 0.0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, pillContainer.bgAlpha * 0.95) }
            GradientStop { position: 1.0; color: Qt.rgba(Theme.bgSecondary.r, Theme.bgSecondary.g, Theme.bgSecondary.b, pillContainer.bgAlpha * 0.7) }
        }

        Behavior on width {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Constants.animFast
            }
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            color: Theme.shadow
            radius: Constants.sizeSm
            samples: 12
            verticalOffset: 2
            horizontalOffset: 0
        }

        readonly property bool isDistributed: SettingsService.pillWidgetLayout === "distributed"

        // Center Group (Clock, Weather & Live Playing Media)
        // Mathematically pinned to the exact horizontal center of the pill container at all times
        RowLayout {
            id: centerGroup

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(Constants.sizeSm * root.thicknessScale)
            z: 10

            ClockButton {
                id: clockBtn
                Layout.alignment: Qt.AlignVCenter
            }

            WeatherPill {
                id: weatherPill
                Layout.alignment: Qt.AlignVCenter
            }

            MediaButton {
                id: mediaBtn
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Left Navigation (Material 3 Bar Icon, Compositor Workspaces, Active Window)
        RowLayout {
            id: leftGroup

            anchors.left: pillContainer.isDistributed ? parent.left : undefined
            anchors.right: pillContainer.isDistributed ? undefined : centerGroup.left
            anchors.leftMargin: pillContainer.isDistributed ? Math.round(Constants.sizeLg * root.thicknessScale) : 0
            anchors.rightMargin: pillContainer.isDistributed ? 0 : Math.round(Constants.sizeLg * root.thicknessScale)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(Constants.sizeSm * root.thicknessScale)

            MinflairButton {
                id: minflairBtn
                Layout.alignment: Qt.AlignVCenter
                iconSize: Math.round((Constants.size2Xl + 4) * root.thicknessScale)
            }

            Workspaces {
                id: workspacesWidget
                Layout.alignment: Qt.AlignVCenter
                visible: true
            }

            // Subtle Visual Divider
            Rectangle {
                width: 1
                height: Math.round(16 * root.thicknessScale)
                color: Theme.borderSecondary
                Layout.alignment: Qt.AlignVCenter
                opacity: 0.6
            }

            ActiveWindowPill {
                id: activeWindowPill
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Right Quick Controls (Battery, Network, DND, Recording, Tray, QuickSettings, Notifications, Power)
        RowLayout {
            id: rightGroup

            anchors.right: pillContainer.isDistributed ? parent.right : undefined
            anchors.left: pillContainer.isDistributed ? undefined : centerGroup.right
            anchors.rightMargin: pillContainer.isDistributed ? Math.round(Constants.sizeLg * root.thicknessScale) : 0
            anchors.leftMargin: pillContainer.isDistributed ? 0 : Math.round(Constants.sizeLg * root.thicknessScale)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(Constants.sizeSm * root.thicknessScale)

            // Subtle Visual Divider
            Rectangle {
                width: 1
                height: Math.round(16 * root.thicknessScale)
                color: Theme.borderSecondary
                Layout.alignment: Qt.AlignVCenter
                opacity: 0.6
            }

            NetworkPill {
                id: netPill
                Layout.alignment: Qt.AlignVCenter
            }

            DndPill {
                id: dndPill
                Layout.alignment: Qt.AlignVCenter
            }

            BatteryPill {
                id: batteryPill
                Layout.alignment: Qt.AlignVCenter
            }

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
