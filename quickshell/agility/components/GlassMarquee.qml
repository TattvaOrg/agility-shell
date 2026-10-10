import QtQuick
import ".."

Item {
    id: root

    property string text: ""
    property color color: Theme.colText
    property string fontName: Theme.fontMain
    property int fontSize: 13
    property int fontWeight: Font.Normal
    property int speed: 30 // pixels per second
    property int pauseDuration: 1200 // ms before starting scroll
    property bool running: true

    clip: true
    implicitHeight: sampleText.implicitHeight
    implicitWidth: 120

    Text {
        id: sampleText
        visible: false
        text: root.text
        font.family: root.fontName
        font.pixelSize: root.fontSize
        font.weight: root.fontWeight
    }

    readonly property bool overflows: sampleText.implicitWidth > root.width
    readonly property real scrollDistance: sampleText.implicitWidth - root.width + 30

    Item {
        id: scrollContent
        width: sampleText.implicitWidth
        height: parent.height
        x: overflows ? -scrollOffset : 0

        property real scrollOffset: 0.0

        SequentialAnimation {
            id: marqueeAnim
            running: root.running && root.overflows
            loops: Animation.Infinite

            PauseAnimation { duration: root.pauseDuration }

            NumberAnimation {
                target: scrollContent
                property: "scrollOffset"
                from: 0.0
                to: root.scrollDistance
                duration: Math.max(1000, (root.scrollDistance / root.speed) * 1000)
                easing.type: Easing.Linear
            }

            PauseAnimation { duration: root.pauseDuration }

            NumberAnimation {
                target: scrollContent
                property: "scrollOffset"
                from: root.scrollDistance
                to: 0.0
                duration: 600
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.color
            font.family: root.fontName
            font.pixelSize: root.fontSize
            font.weight: root.fontWeight
        }
    }
}
