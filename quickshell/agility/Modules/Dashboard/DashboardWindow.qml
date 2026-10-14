import QtQuick
import qs.Core
import qs.Core.Services
import qs.Core.Windows

OverlayWindow {
    id: root

    widgetId: "dashboard"
    enableShadow: true
    preferredWidth: 640 + (contentPadding * 2)
    preferredHeight: 560 + (contentPadding * 2)

    DashboardContent {
        id: content

        widget: root
        anchors.fill: parent
        isVertical: false
    }
}
