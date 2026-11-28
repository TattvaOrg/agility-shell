import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core

/*
 * Expressive Material 3 frosted glass widget card surface matching pctrade/end4-pC's
 * reference screenshot. Cards render with translucent glass, ambient drop shadows,
 * undimmed blurred wallpaper backdrop sampling, and top specular highlights so they stay
 * transparent, luminous, and completely unaffected by desktop composition dimming.
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

    readonly property point _canvasPt: (_canvas && blurSource) ? root.mapToItem(_canvas, 0, 0) : Qt.point(0, 0)
    readonly property real _sampleX: Math.max(0, Math.min(_canvas ? _canvas.width - 1 : 0, _canvasPt.x))
    readonly property real _sampleY: Math.max(0, Math.min(_canvas ? _canvas.height - 1 : 0, _canvasPt.y))
    readonly property real _sampleW: Math.max(1, Math.min(_canvas ? (_canvas.width - _sampleX) : width, width))
    readonly property real _sampleH: Math.max(1, Math.min(_canvas ? (_canvas.height - _sampleY) : height, height))

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

    // Elevated M3 card container body (transparent when wallpaper blur active, translucent glass fallback)
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.cardRadius
        color: root.hasWallpaperBlur ? "transparent" : EndTheme.cardBg
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
