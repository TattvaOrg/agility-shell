import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

BarButton {
    id: root

    property int iconSize: Math.round((Constants.size2Xl + 4) * (SettingsService.barWidgetHeight / 28.0))
    property bool enableIntervalAnim: true

    widgetId: "dashboard"
    implicitWidth: minflair.implicitWidth
    implicitHeight: minflair.implicitHeight
    height: implicitHeight

    AnimatedMinflair {
        id: minflair

        anchors.centerIn: parent
        iconSize: root.iconSize
        enableIntervalAnim: root.enableIntervalAnim

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }

        }

    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                AppState.toggleWidget("launcher");
            }
        }
    }

}
