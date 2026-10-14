import QtQuick
import qs.Core
import qs.Core.Windows

OverlayWindow {
    id: root

    widgetId: "launcher"
    enableShadow: true
    preferredWidth: content.implicitWidth + (contentPadding * 2)
    preferredHeight: content.implicitHeight + (contentPadding * 2)
    initialFocusItem: content.initialFocusItem
    onWidgetOpened: {
        content.resetLauncher();
        if (content.initialFocusItem && content.initialFocusItem.textField)
            content.initialFocusItem.textField.forceActiveFocus();
    }

    LauncherContent {
        id: content

        widget: root
        anchors.fill: parent
    }

}
