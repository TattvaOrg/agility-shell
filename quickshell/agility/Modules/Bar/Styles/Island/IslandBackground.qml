import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property bool enableShadow: true
    property real radius: height / 2
    default property alias content: contentSlot.data

    ThemedShadow {
        anchors.fill: shape
        radius: shape.radius
        active: root.enableShadow && !DisplayProfileService.gameModeActive && (SystemInfoService.powerProfile !== "power-saver")
        visible: active && HyprlandService.hyprShadow && opacity > 0.001
    }

    Rectangle {
        id: shape

        anchors.fill: parent
        radius: root.radius
        color: {
            if (SettingsService.barGlassMode === "solid")
                return (SettingsService.barSolidTone === "white") ? Qt.rgba(1.0, 1.0, 1.0, 1.0) : Qt.rgba(0.04, 0.04, 0.05, 1.0);
            return Theme.bg;
        }
        antialiasing: true
        layer.enabled: true
        layer.smooth: true
        layer.samples: 4

        Behavior on color {
            ColorAnimation {
                duration: Constants.animNormal
            }

        }

    }

    Item {
        id: contentSlot

        anchors.fill: parent
    }

}
