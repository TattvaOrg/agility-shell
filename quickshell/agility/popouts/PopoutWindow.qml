import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "quickshell:agility-popouts"
    WlrLayershell.keyboardFocus: PopoutService.activePopout !== "" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: PopoutService.activePopout !== ""

    // ─── Click Outside Dismissal (20.5) ───
    MouseArea {
        id: outsideDismissArea
        anchors.fill: parent
        onClicked: PopoutService.close()
    }

    // ─── Slide-down Floating Glass Container (20.1 & 20.5) ───
    GlassCard {
        id: cardContainer
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 16
        radius: 20

        // Spring physics for slide-down entry/exit
        anchors.topMargin: PopoutService.activePopout !== "" ? 48 : -implicitHeight
        opacity: PopoutService.activePopout !== "" ? 1.0 : 0.0

        Behavior on anchors.topMargin {
            NumberAnimation {
                duration: 280
                easing.type: Easing.OutBack
                easing.overshoot: 1.15
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 180 }
        }

        implicitWidth: loader.item ? loader.item.implicitWidth : 360
        implicitHeight: loader.item ? loader.item.implicitHeight : 300

        // Stop clicks from reaching outsideDismissArea
        MouseArea {
            anchors.fill: parent
            z: -1
        }

        Loader {
            id: loader
            anchors.fill: parent
            sourceComponent: {
                if (PopoutService.activePopout === "control_center") return controlCenterComp
                if (PopoutService.activePopout === "wifi") return wifiPopoutComp
                if (PopoutService.activePopout === "bluetooth") return bluetoothPopoutComp
                if (PopoutService.activePopout === "audio_mixer") return audioMixerPopoutComp
                if (PopoutService.activePopout === "session") return sessionMenuComp
                return null
            }
        }
    }

    Component {
        id: controlCenterComp
        ControlCenter {}
    }

    Component {
        id: wifiPopoutComp
        WifiPopout {}
    }

    Component {
        id: bluetoothPopoutComp
        BluetoothPopout {}
    }

    Component {
        id: audioMixerPopoutComp
        AudioMixerPopout {}
    }

    Component {
        id: sessionMenuComp
        SessionMenu {}
    }
}
