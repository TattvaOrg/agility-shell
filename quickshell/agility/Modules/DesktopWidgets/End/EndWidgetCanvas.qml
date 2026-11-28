/*
 * Adapted from pctrade/end4-pC (modules/common/widgets/widgetCanvas/WidgetCanvas.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 *
 * Modified for Agility Shell (2026): dedicated Edit Mode grid, alignment guides,
 * keyboard nudging, and floating Done/Lock toolbar using Agility Theme & Services.
 * Combined under AGPL-3.0 Section 13 / GPL-3.0 Section 13.
 */
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs.Core
import qs.Core.Services

MouseArea {
    id: root

    required property var screen
    property bool editMode: SettingsService.desktopWidgetsEditMode
    property int gridSize: EndWidgetStore.gridSize
    property bool snapEnabled: EndWidgetStore.snapToGrid
    property bool showGrid: EndWidgetStore.showGridInEdit
    property bool draggingAny: false
    property bool centerXActive: false
    property bool centerYActive: false
    property var registeredWidgets: []
    property var selectedWidget: null

    readonly property bool isWidgetCanvas: true
    readonly property string wallpaperUrl: {
        let p = WallpaperManager.currentWallpaperPath;
        if (!p) return "";
        return p.startsWith("file://") ? p : ("file://" + p);
    }
    readonly property alias blurSourceItem: blurredTexture

    // Single shared UNDIMMED blurred wallpaper source for all frosted End widget cards.
    // Rendered strictly offscreen and with hideSource so it NEVER paints on the desktop or
    // interferes with desktop composition backdrop dimming.
    Item {
        id: blurredWallpaperHost
        x: -Math.max(4000, Math.ceil(root.width * 2))
        y: -Math.max(4000, Math.ceil(root.height * 2))
        width: Math.max(1, Math.ceil(root.screen ? root.screen.width : root.width))
        height: Math.max(1, Math.ceil(root.screen ? root.screen.height : root.height))

        Image {
            id: rawRealWallpaper
            anchors.fill: parent
            source: root.wallpaperUrl
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(
                Math.max(1, Math.ceil(root.screen ? root.screen.width : root.width)),
                Math.max(1, Math.ceil(root.screen ? root.screen.height : root.height))
            )
            asynchronous: true
            cache: true
            smooth: true
            mipmap: true
        }

        FastBlur {
            id: realWallpaperBlur
            anchors.fill: rawRealWallpaper
            source: rawRealWallpaper
            radius: 36
            transparentBorder: false
        }
    }

    ShaderEffectSource {
        id: blurredTexture
        sourceItem: blurredWallpaperHost
        hideSource: true
        visible: false
        live: true
    }

    acceptedButtons: editMode ? Qt.LeftButton : Qt.NoButton
    hoverEnabled: editMode
    focus: editMode

    function registerWidget(w) {
        if (registeredWidgets.indexOf(w) === -1)
            registeredWidgets = registeredWidgets.concat([w]);
    }

    function unregisterWidget(w) {
        registeredWidgets = registeredWidgets.filter(item => item !== w);
        if (selectedWidget === w)
            selectedWidget = null;
    }

    function selectWidget(w) {
        for (let i = 0; i < registeredWidgets.length; i++) {
            registeredWidgets[i].selected = (registeredWidgets[i] === w);
        }
        selectedWidget = w;
    }

    function clearSelection() {
        for (let i = 0; i < registeredWidgets.length; i++) {
            registeredWidgets[i].selected = false;
        }
        selectedWidget = null;
    }

    function bringToFront(w) {
        if (!w || w.fixedFullWidth)
            return;
        let maxZ = 1;
        for (let i = 0; i < registeredWidgets.length; i++) {
            let other = registeredWidgets[i];
            if (other !== w && !other.fixedFullWidth && other.z > maxZ)
                maxZ = other.z;
        }
        w.z = maxZ + 1;
    }

    function setDragging(active) {
        draggingAny = active;
        if (!active) {
            centerXActive = false;
            centerYActive = false;
        }
    }

    function setCenterActive(xActive, yActive) {
        centerXActive = xActive;
        centerYActive = yActive;
    }

    onPressed: (mouse) => {
        if (!editMode)
            return;
        forceActiveFocus();
        clearSelection();
    }

    onEditModeChanged: {
        if (!editMode) {
            clearSelection();
            draggingAny = false;
            centerXActive = false;
            centerYActive = false;
        } else {
            forceActiveFocus();
        }
    }

    Keys.onPressed: (event) => {
        if (!editMode)
            return;
        if (event.key === Qt.Key_Escape) {
            SettingsService.desktopWidgetsEditMode = false;
            event.accepted = true;
            return;
        }
        if (!selectedWidget)
            return;
        let step = (event.modifiers & Qt.ShiftModifier) ? 1 : gridSize;
        if (event.key === Qt.Key_Left) {
            selectedWidget.nudgeBy(-step, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            selectedWidget.nudgeBy(step, 0);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            selectedWidget.nudgeBy(0, -step);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            selectedWidget.nudgeBy(0, step);
            event.accepted = true;
        } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            EndWidgetStore.setWidgetEnabled(selectedWidget.widgetId, false);
            clearSelection();
            event.accepted = true;
        }
    }

    // Subtle edit-mode backdrop tint & dot grid
    Rectangle {
        anchors.fill: parent
        visible: root.editMode
        color: Qt.rgba(0, 0, 0, 0.14)
        z: -5
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        visible: root.editMode && root.showGrid
        opacity: root.draggingAny ? 0.55 : 0.28
        z: -4

        onVisibleChanged: if (visible) requestPaint()
        onWidthChanged: if (visible) requestPaint()
        onHeightChanged: if (visible) requestPaint()

        onPaint: {
            let ctx = getContext("2d");
            ctx.reset();
            let step = Math.max(16, root.gridSize * 2);
            ctx.fillStyle = Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.45);
            for (let gx = step; gx < width; gx += step) {
                for (let gy = step; gy < height; gy += step) {
                    ctx.fillRect(gx - 1, gy - 1, 2, 2);
                }
            }
        }
    }

    // Center alignment guides
    Rectangle {
        visible: root.editMode && (root.draggingAny || root.centerXActive)
        x: Math.round(root.width / 2 - width / 2)
        y: 0
        width: root.centerXActive ? 2 : 1
        height: root.height
        color: root.centerXActive ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25)
        z: 9990
    }

    Rectangle {
        visible: root.editMode && (root.draggingAny || root.centerYActive)
        x: 0
        y: Math.round(root.height / 2 - height / 2)
        width: root.width
        height: root.centerYActive ? 2 : 1
        color: root.centerYActive ? Theme.accent : Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.25)
        z: 9990
    }

    // Floating Edit Mode Toolbar
    Rectangle {
        id: editBanner
        visible: root.editMode
        z: 10000
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: Math.min(root.width - 32, bannerRow.implicitWidth + 24)
        height: 44
        radius: 22
        color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.92)
        border.width: 1
        border.color: Theme.accent

        RowLayout {
            id: bannerRow
            anchors.centerIn: parent
            spacing: 10

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.accent
            }

            Text {
                text: root.selectedWidget
                    ? ("Editing: " + root.selectedWidget.displayName + " (" + Math.round(root.selectedWidget.width) + "x" + Math.round(root.selectedWidget.height) + ")")
                    : "Edit Mode • Drag widgets or corners • Esc to lock"
                color: Theme.fg
                font.family: SettingsService.fontFamily
                font.pixelSize: 12
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.maximumWidth: Math.max(160, root.width - 340)
            }

            Rectangle {
                implicitWidth: snapLabel.implicitWidth + 16
                implicitHeight: 28
                radius: 14
                color: EndWidgetStore.snapToGrid ? Theme.bgAccent : Theme.bgSecondary
                border.width: 1
                border.color: EndWidgetStore.snapToGrid ? Theme.accent : Theme.border

                Text {
                    id: snapLabel
                    anchors.centerIn: parent
                    text: EndWidgetStore.snapToGrid ? "Snap: On" : "Snap: Off"
                    color: EndWidgetStore.snapToGrid ? Theme.accent : Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        EndWidgetStore.snapToGrid = !EndWidgetStore.snapToGrid;
                        EndWidgetStore.scheduleSave();
                    }
                }
            }

            Rectangle {
                implicitWidth: resetLabel.implicitWidth + 16
                implicitHeight: 28
                radius: 14
                color: Theme.bgSecondary
                border.width: 1
                border.color: Theme.border

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: "Reset"
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Medium
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: EndWidgetStore.resetLayouts()
                }
            }

            Rectangle {
                implicitWidth: doneLabel.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: Theme.accent

                Text {
                    id: doneLabel
                    anchors.centerIn: parent
                    text: "Done"
                    color: Theme.isDark ? "#000000" : "#ffffff"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsService.desktopWidgetsEditMode = false
                }
            }
        }
    }
}
