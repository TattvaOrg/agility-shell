/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/visualizer/VisualizerWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Driven by Agility Shell's CavaService & MprisService. Combined under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import qs.Core
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "visualizer"
    displayName: "Audio Visualizer"
    sizeModes: ["bars", "ring"]
    sizeMode: EndWidgetStore.getPref("visualizer", "style", "bars")
    fixedFullWidth: sizeMode === "bars"
    allowDrag: sizeMode === "ring"
    allowResize: sizeMode === "ring"

    baseWidth: sizeMode === "ring" ? 320 : 600
    baseHeight: sizeMode === "ring" ? 320 : 180

    readonly property var rawData: CavaService.cavaData
    readonly property bool activeAudio: CavaService.isCavaActive && rawData && rawData.length > 0
    readonly property int barCount: Math.max(12, Math.floor(width / 12))

    onSizeModeChanged: {
        if (sizeMode === "bars") {
            x = 0;
            y = Math.max(0, screenHeight - height);
        }
    }

    // Bars Visualizer (spans bottom of screen like reference screenshot)
    Item {
        anchors.fill: parent
        visible: root.sizeMode === "bars"
        opacity: root.activeAudio ? 0.92 : (root.editMode ? 0.35 : 0.0)

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8

            Repeater {
                model: root.barCount
                Rectangle {
                    required property int index
                    width: 4
                    radius: 2

                    readonly property real normVal: {
                        if (!root.activeAudio)
                            return root.editMode ? (0.15 + 0.35 * Math.abs(Math.sin(index * 0.4))) : 0.02;
                        let len = root.rawData.length;
                        let pos = (index / Math.max(1, root.barCount - 1)) * (len - 1);
                        let lo = Math.floor(pos);
                        let hi = Math.min(len - 1, Math.ceil(pos));
                        let mix = pos - lo;
                        let v = (root.rawData[lo] * (1 - mix)) + (root.rawData[hi] * mix);
                        return Math.max(0.02, Math.min(1.0, v / 100.0));
                    }

                    height: Math.max(4, Math.round(normVal * 170))
                    anchors.bottom: parent.bottom
                    color: Qt.rgba(
                        EndTheme.primary.r * normVal + EndTheme.secondary.r * (1 - normVal),
                        EndTheme.primary.g * normVal + EndTheme.secondary.g * (1 - normVal),
                        EndTheme.primary.b * normVal + EndTheme.secondary.b * (1 - normVal),
                        0.92
                    )

                    Behavior on height {
                        enabled: root.visible && root.activeAudio
                        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }

    // Ring Visualizer
    Item {
        anchors.fill: parent
        visible: root.sizeMode === "ring"
        opacity: root.activeAudio ? 0.92 : (root.editMode ? 0.5 : 0.0)

        Behavior on opacity {
            NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
        }

        Repeater {
            model: 36
            Item {
                required property int index
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                rotation: index * 10

                readonly property real normVal: {
                    if (!root.activeAudio)
                        return 0.12;
                    let v = root.rawData[index % root.rawData.length] || 0;
                    return Math.max(0.06, Math.min(1.0, v / 100.0));
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 44 - height
                    width: 5
                    height: Math.round(8 + parent.normVal * 34)
                    radius: 2.5
                    color: Theme.accent

                    Behavior on height {
                        enabled: root.visible && root.activeAudio
                        NumberAnimation { duration: 110; easing.type: Easing.OutQuad }
                    }
                }
            }
        }
    }
}
