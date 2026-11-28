import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core
import qs.Core.Services

/*
 * Lightweight Material 3 translucent glass widget card surface.
 * Because the Wayland desktop dimming layer cuts out End widget areas,
 * the active wallpaper shines through from the background layer at full brightness,
 * completely immune to desktop backdrop dimming with zero duplicate textures or RAM overhead.
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
        anchors.fill: cardSurface
        source: cardSurface
        visible: root.shadowed
        transparentBorder: true
        color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.35 : 0.18)
        radius: 16
        samples: 17
        verticalOffset: 4
    }

    // Card glass surface (transparent cut-through with subtle tint)
    Rectangle {
        id: cardSurface
        anchors.fill: parent
        radius: root.cardRadius
        color: root.resolvedTint

        // Subtle luminous inner highlight
        Rectangle {
            anchors.fill: parent
            radius: root.cardRadius
            color: Qt.rgba(1, 1, 1, Theme.isDark ? 0.02 : 0.05)
        }
    }

    // Translucent Material 3 glass rim over the card
    Rectangle {
        anchors.fill: parent
        radius: root.cardRadius
        color: "transparent"
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
