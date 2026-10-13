import QtQuick
import QtQuick.Layouts
import ".."

Rectangle {
    id: root

    property string icon: ""
    property real iconSize: 18
    property bool flat: true
    property bool isActive: false
    property color bgColor: isActive ? Theme.colAccent : (flat ? "transparent" : Theme.colPillBg)
    property color hoverColor: Theme.colAccent
    property color iconColor: isActive ? "#FFFFFF" : (hovered ? hoverColor : Theme.colText)
    property color hoverBgColor: Theme.colCardBg
    property alias hovered: mouseArea.containsMouse
    property bool disabled: false
    property real padding: 6
    property real radiusValue: height / 2

    signal clicked(var mouse)

    color: {
        if (disabled) return flat ? "transparent" : Theme.colPillBg
        if (mouseArea.pressed) return Theme.colAccent
        if (hovered && !isActive) return hoverBgColor
        return bgColor
    }

    radius: radiusValue
    implicitWidth: iconSize + padding * 2
    implicitHeight: iconSize + padding * 2
    scale: disabled ? 1.0 : (mouseArea.pressed ? 0.92 : (hovered ? 1.06 : 1.0))

    Behavior on scale { NumberAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 150 } }

    SvgIcon {
        anchors.centerIn: parent
        icon: root.icon
        iconSize: root.iconSize
        iconColor: root.iconColor
        opacityLevel: root.disabled ? 0.4 : 1.0
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (!root.disabled) root.clicked(mouse)
        }
    }
}
