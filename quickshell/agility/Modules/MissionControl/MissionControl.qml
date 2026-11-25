import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Services

PanelWindow {
    id: root

    property string widgetId: "missioncontrol"
    property bool isOpen: false
    property Item initialFocusItem: content.initialFocusItem

    signal widgetOpened()
    signal widgetClosed()
    signal fullyClosed()

    function close() {
        isOpen = false;
    }

    surfaceFormat.opaque: false
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: root.isOpen || closeAnim.running

    onIsOpenChanged: {
        if (isOpen) {
            closeDelayTimer.stop();
            if (!AppState.isWidgetOpen(widgetId))
                AppState.openWidget(widgetId);
            content.refresh();
            root.widgetOpened();
            openAnim.restart();
            Qt.callLater(function() {
                if (content.initialFocusItem)
                    content.initialFocusItem.forceActiveFocus();
            });
        } else {
            root.widgetClosed();
            openAnim.stop();
            closeAnim.restart();
        }
    }

    Timer {
        id: closeDelayTimer
        interval: 220
        repeat: false
        onTriggered: {
            if (AppState.isWidgetOpen(widgetId))
                AppState.closeWidget(widgetId);
            root.fullyClosed();
        }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: backdropRect; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; from: 1.05; to: 1.0; duration: 240; easing.type: Easing.OutCubic }
    }

    ParallelAnimation {
        id: closeAnim
        NumberAnimation { target: backdropRect; property: "opacity"; from: 1; to: 0; duration: 180; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "opacity"; from: 1; to: 0; duration: 160; easing.type: Easing.InCubic }
        NumberAnimation { target: content; property: "scale"; from: 1.0; to: 0.96; duration: 180; easing.type: Easing.InCubic }
        onFinished: {
            closeDelayTimer.start();
        }
    }

    // Fullscreen Acrylic Dark Frosted Backdrop
    Rectangle {
        id: backdropRect
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.06, 0.10, 0.78)
        opacity: 0

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: root.close()
        }
    }

    MissionControlContent {
        id: content
        widget: root
        anchors.fill: parent
        opacity: 0
    }
}
