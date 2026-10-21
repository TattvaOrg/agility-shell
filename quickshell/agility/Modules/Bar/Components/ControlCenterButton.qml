import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property var notificationService: null
    property var controlCenterWidget: null
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed
    readonly property bool isActive: AppState.isWidgetOpen("controlCenter")

    implicitHeight: SettingsService.barWidgetHeight
    implicitWidth: height
    width: implicitWidth
    height: implicitHeight
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth
    Layout.alignment: Qt.AlignVCenter
    color: isActive ? (Theme.isBarSolidWhite ? Theme.barBgTertiary : Theme.bgAccent) : (isHovered ? Theme.barBgSecondary : "transparent")
    radius: DisplayProfileService.gameModeActive ? 0 : height / 2
    visible: true
    scale: DisplayProfileService.gameModeActive ? 1 : (isPressed ? 0.92 : (isHovered ? 1.05 : 1))

    SvgIcon {
        id: tuneIcon

        anchors.centerIn: parent
        icon: "tune"
        iconColor: root.isActive ? (Theme.isBarSolidWhite ? Theme.barFg : Theme.accent) : Theme.barFg
        iconSize: Constants.sizeLg
        flat: true

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
                AppState.openWidget("controlCenter");
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
            AppState.toggleWidget("controlCenter");
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
