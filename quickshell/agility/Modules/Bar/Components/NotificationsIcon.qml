import QtQuick
import qs.Core
import qs.Core.Components

SvgIcon {
    property var notificationService

    icon: (notificationService && notificationService.unreadCount > 0) ? "bell-dot" : "bell"
    iconColor: (notificationService && notificationService.dndEnabled) ? Theme.muted : Theme.fg
    iconSize: Constants.sizeLg
    flat: true
}
