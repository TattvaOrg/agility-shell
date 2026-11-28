/*
 * Adapted from pctrade/end4-pC (modules/common/widgets/widgetCanvas/AbstractWidget.qml
 * and modules/ii/background/widgets/AbstractBackgroundWidget.qml), originally derived
 * from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 *
 * Modified for Agility Shell (2026): dedicated Edit Mode drag/resize handles,
 * size-mode pill switcher, bounds clamping across resolution/scale changes,
 * and staggered reveal animation. Combined under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services

Item {
    id: root

    required property string widgetId
    required property string displayName
    required property var screen
    required property real screenWidth
    required property real screenHeight
    property var canvas: null
    readonly property bool isEndWidgetFrame: true

    property bool editMode: SettingsService.desktopWidgetsEditMode
    property bool selected: false
    property bool allowDrag: true
    property bool allowResize: true
    property bool fixedFullWidth: false
    property bool isVertical: false
    property bool supportsFlip: false
    property var sizeModes: []
    property string sizeMode: ""

    property real baseWidth: 276
    property real baseHeight: 120
    property real scaleFactor: 1.0
    property real minScale: 0.55
    property real maxScale: 1.85

    property int staggerIndex: 0
    property real revealProgress: 1.0

    default property alias widgetContent: contentHost.data

    readonly property real _staggerStart: Math.min(0.36, staggerIndex * 0.03)
    readonly property real _localProgress: Math.max(0.0, Math.min(1.0,
        (revealProgress - _staggerStart) / Math.max(0.1, 1.0 - _staggerStart)
    ))

    readonly property real marginX: 8
    readonly property real minTopY: 44
    readonly property real marginBottom: 8

    width: fixedFullWidth ? screenWidth : Math.max(48, Math.round(baseWidth * scaleFactor))
    height: Math.max(40, Math.round(baseHeight * scaleFactor))
    z: fixedFullWidth ? -10 : 1

    opacity: _localProgress

    property bool _layoutLoaded: false
    property bool _dragging: false
    property bool _resizing: false

    function findCanvasItem() {
        if (canvas)
            return canvas;
        let p = root.parent;
        while (p) {
            if (p.isWidgetCanvas === true)
                return p;
            p = p.parent;
        }
        return null;
    }

    function clampPosition(nx, ny) {
        if (screenWidth <= 0 || screenHeight <= 0)
            return { x: nx, y: ny };
        if (fixedFullWidth)
            return { x: 0, y: Math.max(0, screenHeight - height) };
        let maxX = Math.max(marginX, screenWidth - width - marginX);
        let maxY = Math.max(minTopY, screenHeight - height - marginBottom);
        return {
            x: Math.round(Math.max(marginX, Math.min(maxX, nx))),
            y: Math.round(Math.max(minTopY, Math.min(maxY, ny)))
        };
    }

    function clampToBounds() {
        if (!_layoutLoaded)
            return;
        if (!fixedFullWidth) {
            // Ensure widget fits on current monitor even if resolution shrank
            let maxFitW = Math.max(80, screenWidth - marginX * 2);
            let maxFitH = Math.max(80, screenHeight - minTopY - marginBottom);
            if (baseWidth * scaleFactor > maxFitW || baseHeight * scaleFactor > maxFitH) {
                let sFit = Math.min(maxFitW / Math.max(1, baseWidth), maxFitH / Math.max(1, baseHeight));
                scaleFactor = Math.max(0.45, Math.min(scaleFactor, Math.round(sFit * 100) / 100));
            }
        }
        let c = clampPosition(x, y);
        x = c.x;
        y = c.y;
    }

    function loadFromStore() {
        let entry = EndWidgetStore.getWidgetLayout(screen, widgetId);
        if (entry.scale !== undefined)
            scaleFactor = Math.max(minScale, Math.min(maxScale, entry.scale));
        else
            scaleFactor = 1.0;

        if (sizeModes.length > 0) {
            let sm = entry.sizeMode || EndWidgetStore.getPref(widgetId, "sizeMode", sizeModes[0]);
            if (sizeModes.indexOf(sm) !== -1)
                sizeMode = sm;
        }
        if (supportsFlip && entry.vertical !== undefined)
            isVertical = Boolean(entry.vertical);

        _layoutLoaded = true;
        if (fixedFullWidth) {
            x = 0;
            y = Math.max(0, screenHeight - height);
        } else {
            let c = clampPosition(entry.x !== undefined ? entry.x : 40, entry.y !== undefined ? entry.y : 80);
            x = c.x;
            y = c.y;
        }
    }

    function saveToStore() {
        if (!_layoutLoaded)
            return;
        let patch = {
            "x": Math.round(x),
            "y": Math.round(y),
            "scale": Math.round(scaleFactor * 100) / 100
        };
        if (sizeModes.length > 0 && sizeMode !== "")
            patch["sizeMode"] = sizeMode;
        if (supportsFlip)
            patch["vertical"] = isVertical;
        EndWidgetStore.setWidgetLayout(screen, widgetId, patch);
    }

    function nudgeBy(dx, dy) {
        if (!allowDrag || fixedFullWidth)
            return;
        let c = clampPosition(x + dx, y + dy);
        x = c.x;
        y = c.y;
        saveToStore();
    }

    onScreenWidthChanged: {
        if (_layoutLoaded && screenWidth > 0 && screenHeight > 0)
            loadFromStore();
    }
    onScreenHeightChanged: {
        if (_layoutLoaded && screenWidth > 0 && screenHeight > 0)
            loadFromStore();
    }
    onBaseWidthChanged: if (_layoutLoaded && !_resizing) clampToBounds()
    onBaseHeightChanged: if (_layoutLoaded && !_resizing) clampToBounds()

    Connections {
        target: EndWidgetStore
        function onLoadedChanged() {
            if (EndWidgetStore.loaded)
                root.loadFromStore();
        }
        function onLayoutRevisionChanged() {
            root.loadFromStore();
        }
    }

    Component.onCompleted: {
        let c = findCanvasItem();
        if (c)
            c.registerWidget(root);
        loadFromStore();
    }

    Component.onDestruction: {
        let c = findCanvasItem();
        if (c)
            c.unregisterWidget(root);
    }

    Item {
        id: contentHost
        width: root.fixedFullWidth ? root.width : root.baseWidth
        height: root.fixedFullWidth ? root.height : root.baseHeight
        scale: (root.fixedFullWidth ? 1.0 : root.scaleFactor) * (0.94 + 0.06 * root._localProgress)
        transformOrigin: Item.TopLeft
        y: (1.0 - root._localProgress) * 10
    }

    // ─── Edit Mode Overlay (inactive when locked so normal widget interactions work) ───
    Item {
        id: editOverlay
        anchors.fill: parent
        visible: root.editMode
        z: 50

        MouseArea {
            id: moveArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: root.allowDrag && !root.fixedFullWidth
                ? (root._dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                : Qt.PointingHandCursor

            property real startMouseX: 0
            property real startMouseY: 0
            property real startWidgetX: 0
            property real startWidgetY: 0

            onPressed: (mouse) => {
                let c = root.findCanvasItem();
                if (c) {
                    c.selectWidget(root);
                    c.bringToFront(root);
                } else {
                    root.selected = true;
                }
                if (!root.allowDrag || root.fixedFullWidth)
                    return;
                let globalPt = mapToItem(root.parent, mouse.x, mouse.y);
                startMouseX = globalPt.x;
                startMouseY = globalPt.y;
                startWidgetX = root.x;
                startWidgetY = root.y;
                root._dragging = true;
                if (c)
                    c.setDragging(true);
            }

            onPositionChanged: (mouse) => {
                if (!root._dragging || !root.allowDrag || root.fixedFullWidth)
                    return;
                let c = root.findCanvasItem();
                let globalPt = mapToItem(root.parent, mouse.x, mouse.y);
                let rawX = startWidgetX + (globalPt.x - startMouseX);
                let rawY = startWidgetY + (globalPt.y - startMouseY);

                let snap = EndWidgetStore.snapToGrid;
                let g = Math.max(4, EndWidgetStore.gridSize);
                if (snap) {
                    rawX = Math.round(rawX / g) * g;
                    rawY = Math.round(rawY / g) * g;
                }

                // Magnetic snap to center lines
                let cx = rawX + root.width / 2;
                let cy = rawY + root.height / 2;
                let nearX = Math.abs(cx - root.screenWidth / 2) < g;
                let nearY = Math.abs(cy - root.screenHeight / 2) < g;
                if (nearX)
                    rawX = Math.round(root.screenWidth / 2 - root.width / 2);
                if (nearY)
                    rawY = Math.round(root.screenHeight / 2 - root.height / 2);

                if (c)
                    c.setCenterActive(nearX, nearY);

                let clamped = root.clampPosition(rawX, rawY);
                root.x = clamped.x;
                root.y = clamped.y;
            }

            onReleased: {
                if (root._dragging) {
                    root._dragging = false;
                    let c = root.findCanvasItem();
                    if (c)
                        c.setDragging(false);
                    root.saveToStore();
                }
            }
        }

        // Selection & hover frame
        Rectangle {
            anchors.fill: parent
            color: root.selected ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.08) : "transparent"
            radius: 18
            border.width: root.selected ? 2 : 1
            border.color: root.selected
                ? Theme.accent
                : (moveArea.containsMouse ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.55) : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22))
        }

        // Top floating label + size mode / flip / hide controls when selected
        Rectangle {
            id: headerPill
            visible: root.selected || moveArea.containsMouse
            anchors.left: parent.left
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            width: headerRow.implicitWidth + 14
            height: 24
            radius: 12
            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.94)
            border.width: 1
            border.color: root.selected ? Theme.accent : Theme.border

            RowLayout {
                id: headerRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    text: root.displayName
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.Bold
                }

                // Size-mode quick pill
                Rectangle {
                    visible: root.selected && root.sizeModes.length > 1
                    implicitWidth: modeText.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Theme.bgAccent

                    Text {
                        id: modeText
                        anchors.centerIn: parent
                        text: root.sizeMode
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let idx = root.sizeModes.indexOf(root.sizeMode);
                            root.sizeMode = root.sizeModes[(idx + 1) % root.sizeModes.length];
                            EndWidgetStore.setPref(root.widgetId, "sizeMode", root.sizeMode);
                            Qt.callLater(() => {
                                root.clampToBounds();
                                root.saveToStore();
                            });
                        }
                    }
                }

                // Vertical/horizontal flip pill
                Rectangle {
                    visible: root.selected && root.supportsFlip
                    implicitWidth: flipText.implicitWidth + 10
                    implicitHeight: 16
                    radius: 8
                    color: Theme.bgAccent

                    Text {
                        id: flipText
                        anchors.centerIn: parent
                        text: root.isVertical ? "Vert" : "Horiz"
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 9
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.isVertical = !root.isVertical;
                            EndWidgetStore.setPref(root.widgetId, "vertical", root.isVertical);
                            Qt.callLater(() => {
                                root.clampToBounds();
                                root.saveToStore();
                            });
                        }
                    }
                }

                // Hide widget button
                Rectangle {
                    visible: root.selected
                    implicitWidth: 16
                    implicitHeight: 16
                    radius: 8
                    color: Theme.bgSecondary

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: Theme.fg
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            EndWidgetStore.setWidgetEnabled(root.widgetId, false);
                            let c = root.findCanvasItem();
                            if (c)
                                c.clearSelection();
                        }
                    }
                }
            }
        }

        // Bottom-right corner resize handle
        Rectangle {
            id: resizeHandle
            visible: root.selected && root.allowResize && !root.fixedFullWidth
            width: 18
            height: 18
            radius: 9
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -6
            anchors.bottomMargin: -6
            color: Theme.accent
            border.width: 2
            border.color: Theme.bg
            z: 60

            // Inner grip dot
            Rectangle {
                anchors.centerIn: parent
                width: 6
                height: 6
                radius: 3
                color: Theme.bg
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.SizeFDiagCursor

                property real startGlobalX: 0
                property real startGlobalY: 0
                property real startScale: 1.0

                onPressed: (mouse) => {
                    let pt = mapToItem(root.parent, mouse.x, mouse.y);
                    startGlobalX = pt.x;
                    startGlobalY = pt.y;
                    startScale = root.scaleFactor;
                    root._resizing = true;
                }

                onPositionChanged: (mouse) => {
                    if (!root._resizing)
                        return;
                    let pt = mapToItem(root.parent, mouse.x, mouse.y);
                    let dx = pt.x - startGlobalX;
                    let dy = pt.y - startGlobalY;
                    let baseDiag = Math.max(60, Math.hypot(root.baseWidth, root.baseHeight));
                    let proj = (dx * root.baseWidth + dy * root.baseHeight) / (baseDiag * Math.max(1, baseDiag)) * 1.4;
                    let nextScale = startScale + proj;

                    // Clamp so resized widget stays inside monitor bounds
                    let maxAllowedW = Math.max(60, root.screenWidth - root.x - root.marginX);
                    let maxAllowedH = Math.max(60, root.screenHeight - root.y - root.marginBottom);
                    let maxFitScale = Math.min(
                        root.maxScale,
                        maxAllowedW / Math.max(1, root.baseWidth),
                        maxAllowedH / Math.max(1, root.baseHeight)
                    );
                    nextScale = Math.max(root.minScale, Math.min(maxFitScale, nextScale));
                    root.scaleFactor = Math.round(nextScale * 100) / 100;
                }

                onReleased: {
                    if (root._resizing) {
                        root._resizing = false;
                        root.clampToBounds();
                        root.saveToStore();
                    }
                }
            }
        }
    }
}
