import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core
import qs.Core.Services

/*
 * Direct-wallpaper masked glass widget card surface matching DesktopCompositionLayer's
 * central shape. Cards directly render the undimmed active wallpaper crop masked
 * strictly to their rounded boundary with a luminous glass tint, ambient drop shadow,
 * and top specular highlight so they stay transparent, bright, and completely immune
 * to desktop composition backdrop dimming.
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

    readonly property string wallpaperSource: {
        let p = WallpaperManager.currentWallpaperPath;
        if (!p) return "";
        return p.startsWith("file://") ? p : ("file://" + p);
    }

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
    readonly property point _canvasPt: _canvas ? root.mapToItem(_canvas, 0, 0) : Qt.point(0, 0)

    readonly property color resolvedTint: tintOpacity >= 0
        ? Qt.rgba(tint.r, tint.g, tint.b, tintOpacity)
        : tint

    // Mask shape for card body
    Rectangle {
        id: cardMask
        anchors.fill: parent
        radius: root.cardRadius
        color: "#ffffff"
        visible: false
    }

    // Soft ambient shadow behind card
    DropShadow {
        anchors.fill: cardMask
        source: cardMask
        visible: root.shadowed
        transparentBorder: true
        color: Qt.rgba(0, 0, 0, Theme.isDark ? 0.45 : 0.22)
        radius: 16
        samples: 17
        verticalOffset: 5
    }

    // Direct undimmed wallpaper host masked to the card (matching central shape composition)
    Item {
        id: cardFocalHost
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: cardMask
        }

        // Fallback surface if wallpaper path is empty
        Rectangle {
            anchors.fill: parent
            color: Theme.bgSecondary
            visible: root.wallpaperSource === ""
        }

        // Direct real undimmed wallpaper registered with desktop coordinates
        Image {
            id: directWallpaper
            x: -root._canvasPt.x
            y: -root._canvasPt.y
            width: _canvas ? _canvas.width : 1920
            height: _canvas ? _canvas.height : 1080
            source: root.wallpaperSource
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(
                Math.max(1, Math.ceil(_canvas ? _canvas.width : 1920)),
                Math.max(1, Math.ceil(_canvas ? _canvas.height : 1080))
            )
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
            visible: root.wallpaperSource !== ""
        }

        // Translucent Material 3 glass wash over the direct wallpaper
        Rectangle {
            anchors.fill: parent
            color: root.resolvedTint
        }

        // Inner subtle luminous highlight
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(1, 1, 1, Theme.isDark ? 0.04 : 0.08)
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
