import QtQuick
import qs.Core
import qs.Core.Services
import qs.Core.Windows

OverlayWindow {
    id: root

    property var notificationService: null
    widgetId: "controlCenter"
    enableShadow: true
    preferredWidth: Math.max(500, content.implicitWidth) + (contentPadding * 2)
    preferredHeight: Math.max(520, content.implicitHeight) + (contentPadding * 2)
    initialFocusItem: null

    onWidgetOpened: {
        content.resetViews();
    }

    ControlCenterContent {
        id: content

        widget: root
        notificationService: root.notificationService
        anchors.fill: parent
    }
}
