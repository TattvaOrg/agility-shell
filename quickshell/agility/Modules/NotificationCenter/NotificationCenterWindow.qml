import QtQuick
import qs.Core
import qs.Core.Services
import qs.Core.Windows

OverlayWindow {
    id: root

    property var notificationService: null
    widgetId: "notificationsCenter"
    enableShadow: true
    preferredWidth: 440 + (contentPadding * 2)
    preferredHeight: 520 + (contentPadding * 2)
    initialFocusItem: null

    NotificationCenter {
        id: content

        anchors.fill: parent
        notificationService: root.notificationService
    }
}
