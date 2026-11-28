import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core

/*
 * Frosted glass widget surface that samples the REAL (undimmed) blurred active
 * wallpaper directly beneath the card, tinted with Material 3 Expressive colors
 * so cards glow cleanly against the dimmed desktop composition.
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

    readonly property var _canvas: _frame ? _frame.findCanvasItem() : null
    readonly property var blurSource: _canvas ? _canvas.blurSourceItem : null
    readonly property bool hasWallpaperBlur: blurSource !== null && _canvas && _canvas.wallpaperUrl !== ""

    readonly property real _scale: _frame ? (_frame.fixedFullWidth ? 1.0 : _frame.scaleFactor) : 1.0
    readonly property real _sampleX: (_frame ? _frame.x : 0) + trackX * _scale
    readonly property real _sampleY: (_frame ? _frame.y : 0) + trackY * _scale
    readonly property real _sampleW: Math.max(1, width * _scale)
    readonly property real _sampleH: Math.max(1, height * _scale)

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

    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.cardRadius
        color: root.hasWallpaperBlur ? "transparent" : Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.72)
        antialiasing: true
    }

    // Real undimmed blurred wallpaper slice clipped to card radius
    Item {
        id: glassLayer
        anchors.fill: parent
        visible: root.hasWallpaperBlur

        layer.enabled: root.hasWallpaperBlur
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: glassLayer.width
                height: glassLayer.height
                radius: root.cardRadius
            }
        }

        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: root.blurSource
            sourceRect: Qt.rect(root._sampleX, root._sampleY, root._sampleW, root._sampleH)
            live: true
            smooth: true
        }
    }

    // Translucent Material 3 tint + glass rim over the blurred wallpaper
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
