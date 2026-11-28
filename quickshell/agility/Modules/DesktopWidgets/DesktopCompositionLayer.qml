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

            WlrLayershell.layer: WlrLayer.Bottom
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

            readonly property string wallSource: WallpaperManager.currentWallpaperPath !== ""
                ? ("file://" + WallpaperManager.currentWallpaperPath)
                : ""
            readonly property size wallSourceSize: Qt.size(
                Math.max(1, Math.ceil(modelData.width * modelData.devicePixelRatio)),
                Math.max(1, Math.ceil(modelData.height * modelData.devicePixelRatio))
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

                // Background dimming layer
                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: SettingsService.desktopBackdropDimEnabled
                        ? (SettingsService.desktopBackdropDimStrength * root.compositionProgress)
                        : 0.0
                }

                // Centered shaped focal crop of the active wallpaper
                Item {
                    id: shapeContainer
                    anchors.centerIn: parent
                    width: compWindow.shapeDiameter
                    height: compWindow.shapeDiameter
                    visible: SettingsService.desktopCenterShapeEnabled
                    scale: 0.88 + 0.12 * root.compositionProgress
                    opacity: Math.min(1.0, root.compositionProgress * 1.15)

                    // Mask shape painted once per shape change (never per-frame during animation)
                    MaterialShape {
                        id: shapeMask
                        anchors.fill: parent
                        shapeName: SettingsService.desktopCenterShape
                        color: "#ffffff"
                        visible: false
                    }

                    // Soft ambient shadow behind the central shape
                    DropShadow {
                        anchors.fill: shapeMask
                        source: shapeMask
                        radius: 28
                        samples: 25
                        verticalOffset: 8
                        color: Qt.rgba(0, 0, 0, 0.55)
                        transparentBorder: true
                    }

                    // Brighter, slightly larger focal crop masked to the central shape
                    Item {
                        id: croppedFocalHost
                        anchors.fill: parent
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: shapeMask
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.bgSecondary
                            visible: compWindow.wallSource === ""
                        }

                        Image {
                            id: focalWallpaper
                            anchors.centerIn: parent
                            width: compWindow.width
                            height: compWindow.height
                            source: compWindow.wallSource
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: compWindow.wallSourceSize
                            asynchronous: true
                            cache: true
                            smooth: true
                            mipmap: true
                            // Slightly larger crop than the dimmed backdrop, subtle lift in brightness
                            scale: 1.08 + (1.0 - root.compositionProgress) * 0.06
                            visible: compWindow.wallSource !== ""
                        }

                        // Subtle warm/luminous inner rim
                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(1, 1, 1, 0.03)
                        }
                    }

                    // Crisp subtle outline around the central organic shape
                    MaterialShape {
                        anchors.fill: parent
                        shapeName: SettingsService.desktopCenterShape
                        color: "transparent"
                        borderWidth: 0.006
                        borderColor: Qt.rgba(Theme.fg.r, Theme.fg.g, Theme.fg.b, 0.22)
                    }
                }
            }
        }
    }
}
