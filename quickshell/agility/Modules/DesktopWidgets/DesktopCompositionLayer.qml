/*
 * Desktop wallpaper composition layer (dimmed active wallpaper + centered
 * organic shaped focal crop), visually inspired by pctrade/end4-pC's
 * CenteredWallpaper. Uses Agility Shell's WallpaperManager, Theme, and
 * SettingsService.
 */
import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import qs.Modules.DesktopWidgets.End

Item {
    id: root

    readonly property bool animAllowed: SettingsService.desktopCompositionAnimEnabled
        && HyprlandService.enableAnimations
        && !DisplayProfileService.gameModeActive
        && SystemInfoService.powerProfile !== "power-saver"

    readonly property int animDuration: Math.max(120, Math.round(520 / Math.max(0.4, SettingsService.desktopCompositionAnimSpeed)))
    readonly property bool compositionWanted: SettingsService.settingsLoaded
        && SettingsService.desktopCompositionEnabled
        && !DisplayProfileService.gameModeActive

    // Single animation driver (0 = off/normal wallpaper, 1 = composed presentation)
    property real compositionProgress: 0.0
    property bool _initialized: false

    function syncToTarget() {
        let target = root.compositionWanted ? 1.0 : 0.0;
        if (!root._initialized || !root.animAllowed) {
            revealAnim.stop();
            root.compositionProgress = target;
            if (SettingsService.settingsLoaded)
                root._initialized = true;
            return;
        }
        if (Math.abs(root.compositionProgress - target) < 0.001) {
            revealAnim.stop();
            root.compositionProgress = target;
            return;
        }
        if (revealAnim.running && Math.abs(revealAnim.to - target) < 0.001)
            return;
        revealAnim.stop();
        revealAnim.duration = root.animDuration;
        revealAnim.to = target;
        revealAnim.start();
    }

    onCompositionWantedChanged: syncToTarget()
    onAnimAllowedChanged: syncToTarget()
    Component.onCompleted: syncToTarget()

    NumberAnimation {
        id: revealAnim
        target: root
        property: "compositionProgress"
        easing.type: Easing.OutCubic
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: compWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "quickshell:desktop-composition"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            focusable: false
            visible: root.compositionProgress > 0.001 || root.compositionWanted

            // Completely click-through so normal windows and desktop clicks pass through
            mask: Region {}

            readonly property string wallSource: {
                let p = WallpaperManager.currentWallpaperPath;
                if (!p) return "";
                return p.startsWith("file://") ? p : ("file://" + p);
            }
            readonly property size wallSourceSize: Qt.size(
                Math.max(1, Math.ceil(modelData.width * (Screen.devicePixelRatio || 1.0))),
                Math.max(1, Math.ceil(modelData.height * (Screen.devicePixelRatio || 1.0)))
            )
            readonly property real shapeDiameter: Math.max(140, Math.round(
                Math.min(compWindow.width, compWindow.height) * SettingsService.desktopCenterShapeSize
            ))

            Item {
                id: compRoot
                anchors.fill: parent
                opacity: root.compositionProgress

                // Fallback base when no wallpaper path is loaded yet
                Rectangle {
                    anchors.fill: parent
                    color: Theme.bg
                    visible: compWindow.wallSource === ""
                }

                // Full-screen active wallpaper
                Image {
                    id: backdropImage
                    anchors.fill: parent
                    source: compWindow.wallSource
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: compWindow.wallSourceSize
                    asynchronous: true
                    cache: true
                    smooth: true
                    mipmap: true
                    visible: compWindow.wallSource !== ""
                }

                // Background dimming layer with cutouts for End widgets
                Canvas {
                    id: dimLayerCanvas
                    anchors.fill: parent
                    opacity: SettingsService.desktopBackdropDimEnabled
                        ? (SettingsService.desktopBackdropDimStrength * root.compositionProgress)
                        : 0.0
                    visible: opacity > 0.001

                    function repaint() {
                        requestPaint();
                    }

                    Connections {
                        target: EndWidgetStore
                        function onLayoutRevisionChanged() { dimLayerCanvas.repaint(); }
                        function onVisibilityChanged() { dimLayerCanvas.repaint(); }
                    }

                    Connections {
                        target: SettingsService
                        function onDesktopWidgetProviderChanged() { dimLayerCanvas.repaint(); }
                        function onDesktopWidgetsEditModeChanged() { dimLayerCanvas.repaint(); }
                        function onDesktopCenterShapeChanged() { dimLayerCanvas.repaint(); }
                        function onDesktopCenterShapeEnabledChanged() { dimLayerCanvas.repaint(); }
                    }

                    onWidthChanged: repaint()
                    onHeightChanged: repaint()
                    Component.onCompleted: repaint()

                    onPaint: {
                        let ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        ctx.fillStyle = "#000000";
                        ctx.fillRect(0, 0, width, height);

                        // 1. Cut out central organic shape so the focal wallpaper shines through undimmed
                        if (SettingsService.desktopCenterShapeEnabled && centerShapeHelper.morph) {
                            let cubics = centerShapeHelper.morph.asCubics(1.0);
                            if (cubics && cubics.length > 0) {
                                ctx.save();
                                ctx.globalCompositeOperation = "destination-out";
                                let size = compWindow.shapeDiameter;
                                let ox = Math.round((width - size) / 2);
                                let oy = Math.round((height - size) / 2);

                                ctx.translate(ox, oy);
                                ctx.scale(size, size);
                                ctx.beginPath();
                                ctx.moveTo(cubics[0].anchor0X, cubics[0].anchor0Y);
                                for (let i = 0; i < cubics.length; i++) {
                                    let c = cubics[i];
                                    ctx.bezierCurveTo(c.control0X, c.control0Y, c.control1X, c.control1Y, c.anchor1X, c.anchor1Y);
                                }
                                ctx.closePath();
                                ctx.fill();
                                ctx.restore();
                            }
                        }

                        // 2. If End widgets are active, cut out the areas where widgets are placed
                        // so the undimmed wallpaper shines through, keeping widgets immune to dimming
                        if (SettingsService.desktopWidgetProvider === "end") {
                            ctx.save();
                            ctx.globalCompositeOperation = "destination-out";

                            let vis = EndWidgetStore.visibility;
                            for (let wid in vis) {
                                if (vis[wid] !== true || wid === "visualizer") continue;
                                if (wid === "clock" && EndWidgetStore.getPref("clock", "style", "digital") === "digital") continue;
                                let layout = EndWidgetStore.getWidgetLayout(compWindow.modelData, wid);
                                let dims = EndWidgetStore.baseDimensions(wid, layout.sizeMode || "", Boolean(layout.vertical));
                                let s = layout.scale || 1.0;
                                let w = Math.round(dims.w * s);
                                let h = Math.round(dims.h * s);
                                let x = Math.round(layout.x);
                                let y = Math.round(layout.y);

                                let rad = Math.min(26, Math.round(26 * s));
                                ctx.beginPath();
                                ctx.moveTo(x + rad, y);
                                ctx.lineTo(x + w - rad, y);
                                ctx.quadraticCurveTo(x + w, y, x + w, y + rad);
                                ctx.lineTo(x + w, y + h - rad);
                                ctx.quadraticCurveTo(x + w, y + h, x + w - rad, y + h);
                                ctx.lineTo(x + rad, y + h);
                                ctx.quadraticCurveTo(x, y + h, x, y + h - rad);
                                ctx.lineTo(x, y + rad);
                                ctx.quadraticCurveTo(x, y, x + rad, y);
                                ctx.closePath();
                                ctx.fill();
                            }
                            ctx.restore();
                        }
                    }
                }

                // Helper to provide shape morph geometry for canvas cutout
                MaterialShape {
                    id: centerShapeHelper
                    width: compWindow.shapeDiameter
                    height: compWindow.shapeDiameter
                    shapeName: SettingsService.desktopCenterShape
                    visible: false
                    onRoundedPolygonChanged: dimLayerCanvas.repaint()
                }

                // Crisp subtle outline around the central organic shape
                MaterialShape {
                    anchors.centerIn: parent
                    width: compWindow.shapeDiameter
                    height: compWindow.shapeDiameter
                    visible: SettingsService.desktopCenterShapeEnabled
                    shapeName: SettingsService.desktopCenterShape
                    color: "transparent"
                    borderWidth: 0.006
                    borderColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.28)
                }
            }
        }
    }
}
