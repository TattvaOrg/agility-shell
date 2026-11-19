import QtQuick
import qs.Core
import qs.Core.Windows

OverlayWindow {
    id: root

    widgetId: "missioncontrol"
    enableShadow: true
    preferredWidth: 1240
    preferredHeight: 740
    initialFocusItem: content.initialFocusItem

    onWidgetOpened: {
        content.refresh();
    }

    MissionControlContent {
        id: content
        widget: root
        anchors.fill: parent
    }
}
