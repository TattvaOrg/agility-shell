import QtQuick
import ".."

Item {
    id: root

    property string source: ""
    property real size: 20
    property color color: Theme.colText
    property real opacityLevel: 1.0

    implicitWidth: size
    implicitHeight: size

    readonly property string resolvedPath: IconResolver.resolveIcon(source)
    readonly property bool isEmoji: source.length <= 4 && !source.includes("/") && !source.includes(".")

    Text {
        id: emojiText
        anchors.centerIn: parent
        visible: root.isEmoji
        text: root.source
        font.pixelSize: Math.round(root.size * 0.9)
    }

    Image {
        id: iconImage
        anchors.fill: parent
        visible: !root.isEmoji && root.resolvedPath !== ""
        source: root.resolvedPath
        sourceSize.width: Math.round(root.size * 2)
        sourceSize.height: Math.round(root.size * 2)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.opacityLevel
    }
}
