import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import ".."

Item {
    id: root

    property string icon: ""
    property real iconSize: 18
    property color iconColor: Theme.colText
    property bool useOriginalColors: false
    property real opacityLevel: 1.0

    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property string resolvedSource: {
        if (!icon || icon === "") return ""
        if (icon.startsWith("file://") || icon.startsWith("image://") || icon.startsWith("qrc:/") || icon.startsWith("/")) {
            return icon
        }
        return IconResolver.resolveIcon(icon)
    }

    Image {
        id: iconImage
        anchors.fill: parent
        source: root.resolvedSource
        sourceSize.width: Math.round(root.iconSize * 2)
        sourceSize.height: Math.round(root.iconSize * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: root.useOriginalColors
        opacity: root.opacityLevel
    }

    ColorOverlay {
        id: overlay
        anchors.fill: iconImage
        source: iconImage
        color: root.iconColor
        opacity: root.opacityLevel
        visible: !root.useOriginalColors && iconImage.status === Image.Ready
    }
}
