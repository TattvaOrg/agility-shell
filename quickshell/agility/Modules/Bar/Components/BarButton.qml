import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property var widget: null
    property string widgetId: ""
    property string icon: ""
    property int iconSize: Constants.sizeLg
    property int fontSize: Constants.sizeSm
    property color iconColor: Theme.fg
    property bool hasBackground: false
    property color backgroundColor: Theme.bgSecondary
    property color hoverBackgroundColor: Theme.bgTertiary

    implicitHeight: hasBackground ? SettingsService.barWidgetHeight : (svgIcon.implicitHeight > 0 ? svgIcon.implicitHeight : iconSize)
    implicitWidth: hasBackground ? height : (svgIcon.implicitWidth > 0 ? svgIcon.implicitWidth : iconSize)
    Layout.preferredHeight: hasBackground ? SettingsService.barWidgetHeight : implicitHeight
    Layout.preferredWidth: implicitWidth
    radius: DisplayProfileService.gameModeActive ? 0 : (hasBackground ? height / 2 : Constants.sizeLg)
    color: hasBackground ? ((mouseArea.containsMouse || mouseArea.pressed) ? hoverBackgroundColor : backgroundColor) : "transparent"
    border.width: (DisplayProfileService.gameModeActive && hasBackground) ? 1 : 0
    border.color: (DisplayProfileService.gameModeActive && hasBackground) ? Theme.border : "transparent"
    scale: DisplayProfileService.gameModeActive ? 1 : (mouseArea.pressed ? 0.95 : (mouseArea.containsMouse ? 1.05 : 1))

    SvgIcon {
        id: svgIcon

        anchors.centerIn: parent
        icon: root.icon
        iconSize: root.iconSize
        flat: true
        iconColor: (!root.hasBackground && mouseArea.containsMouse) ? Theme.accent : root.iconColor
    }

    Timer {
        id: hoverTimer

        interval: 160
        repeat: false
        onTriggered: {
            if (SettingsService.barOpenOnHover && mouseArea.containsMouse) {
                if (root.widgetId !== "" && root.widgetId !== "powerMenu") {
                    if (!AppState.isWidgetOpen(root.widgetId))
                        AppState.openWidget(root.widgetId);
                } else if (root.widget && !root.widget.isOpen) {
                    root.widget.isOpen = true;
                }
            }
        }
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: {
            if (SettingsService.barOpenOnHover)
                hoverTimer.restart();
        }
        onExited: {
            hoverTimer.stop();
        }
        onClicked: {
            hoverTimer.stop();
            if (root.widgetId !== "")
                AppState.toggleWidget(root.widgetId);
            else if (root.widget)
                root.widget.isOpen = !root.widget.isOpen;
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Constants.animFast
        }

    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutBack
        }

    }

}
