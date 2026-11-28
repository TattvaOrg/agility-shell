import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core

/*
 * Expressive Material 3 widget card surface matching pctrade/end4-pC's
 * reference screenshot. Cards render with vibrant elevated containers,
 * ambient drop shadows, and top specular highlights so they stay completely
 * undimmed and punchy on top of the dimmed desktop composition backdrop.
 */
Item {
    id: root

    property real cardRadius: 26
    property color tint: EndTheme.glassTint
    property real tintOpacity: -1
    property bool shadowed: true
    property bool showBorder: true

    // Host frame reference (auto-resolved if nested inside an EndWidgetFrame)
    property var widgetFrame: null
    property real trackX: 0
    property real trackY: 0

    readonly property var _frame: {
        if (widgetFrame)
            return widgetFrame;
        let p = root.parent;
        while (p) {
            if (p.isEndWidgetFrame === true)
                return p;
            p = p.parent;
        }
        return null;
    }

    readonly property color resolvedTint: tintOpacity >= 0
        ? Qt.rgba(tint.r, tint.g, tint.b, tintOpacity)
        : tint

    // Soft ambient shadow behind card
    DropShadow {
        anchors.fill: cardBody
        source: cardBody
        visible: root.shadowed
        transparentBorder: true
        color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.45 : 0.22)
        radius: 16
        samples: 17
        verticalOffset: 5
    }

    // Elevated M3 card container body (crisp, elevated, completely undimmed)
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.cardRadius
        color: EndTheme.cardBg
        antialiasing: true
    }

    // Translucent Material 3 tint + glass rim over the card
    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: root.resolvedTint
        border.width: root.showBorder ? 1 : 0
        border.color: EndTheme.glassBorder
        antialiasing: true

        // Subtle top specular highlight
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: root.cardRadius * 0.45
            anchors.rightMargin: root.cardRadius * 0.45
            height: 1
            color: EndTheme.glassHighlight
            visible: root.showBorder
        }
    }
}
