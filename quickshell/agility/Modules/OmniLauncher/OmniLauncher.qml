import QtQuick
import qs.Core
import qs.Core.Windows

OverlayWindow {
    id: root

    widgetId: "omni"
    enableShadow: true
    preferredWidth: 680
    preferredHeight: 520
    initialFocusItem: content.initialFocusItem

    onWidgetOpened: {
        content.resetAndFocus();
    }

    OmniLauncherContent {
        id: content
        widget: root
        anchors.fill: parent
    }
}
