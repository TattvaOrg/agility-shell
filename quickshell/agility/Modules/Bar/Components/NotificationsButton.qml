import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property var notificationService: null
    property var notificationsCenterWidget: null
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed
    readonly property bool isActive: AppState.isWidgetOpen("notificationsCenter")

    implicitHeight: SettingsService.barWidgetHeight
    implicitWidth: height
    width: implicitWidth
    height: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter
    color: isActive ? (Theme.isLightBar ? Theme.barBgTertiary : Theme.bgAccent) : (isHovered ? Theme.barBgSecondary : "transparent")
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
    visible: true
    scale: DisplayProfileService.gameModeActive ? 1 : (isPressed ? 0.92 : (isHovered ? 1.05 : 1))

    NotificationsIcon {
        id: notifIcon

        anchors.centerIn: parent
        notificationService: root.notificationService
        iconColor: root.isActive ? (Theme.isLightBar ? Theme.barFg : Theme.accent) : ((notificationService && notificationService.dndEnabled) ? Theme.barMuted : Theme.barFg)

        Behavior on iconColor {
            ColorAnimation {
                duration: Constants.animFast
            }

        }

    }

    Timer {
        id: hoverTimer

        interval: 160
        repeat: false
        onTriggered: {
            if (SettingsService.barOpenOnHover && root.isHovered && !root.isActive) {
                AppState.openWidget("notificationsCenter");
            }
        }
    }

    MouseArea {
        id: mouseArea

        z: 10
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (SettingsService.barOpenOnHover)
                hoverTimer.restart();
        }
        onExited: {
            hoverTimer.stop();
        }
        onClicked: {
            hoverTimer.stop();
            AppState.toggleWidget("notificationsCenter");
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Constants.animFast
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutBack
        }

    }

}
