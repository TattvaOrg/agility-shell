import QtQuick
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    readonly property bool isDnd: SettingsService.dndEnabled
    readonly property bool isVisible: SettingsService.appletDnd
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed

    implicitHeight: SettingsService.barWidgetHeight
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    implicitWidth: isVisible ? height : 0
    width: implicitWidth
    opacity: isVisible ? 1 : 0
    visible: isVisible || opacity > 0.001
    clip: true

    radius: height / 2
    color: isDnd ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : (isHovered ? Theme.bgSecondary : "transparent")
    border.color: isDnd ? Theme.accent : (isHovered ? Theme.borderSecondary : "transparent")
    border.width: 1
    scale: isPressed ? 0.94 : (isHovered ? 1.05 : 1)

    Behavior on width {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
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

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            SettingsService.dndEnabled = !SettingsService.dndEnabled;
        }
    }

    SvgIcon {
        anchors.centerIn: parent
        icon: root.isDnd ? "bell-slash-duotone" : "bell"
        iconSize: 14
        flat: true
        iconColor: root.isDnd ? Theme.accent : (root.isHovered ? Theme.fg : Theme.muted)

        Behavior on iconColor {
            ColorAnimation {
                duration: Constants.animFast
            }
        }
    }
}
