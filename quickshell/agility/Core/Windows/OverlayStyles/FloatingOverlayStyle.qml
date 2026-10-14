import Qt5Compat.GraphicalEffects
import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    property var widget
    readonly property bool isOpen: widget ? widget.isOpen : false
    readonly property real preferredWidth: widget ? widget.smoothPreferredWidth : 480
    readonly property real preferredHeight: widget ? widget.smoothPreferredHeight : 400
    readonly property real windowRadius: widget ? widget.smoothWindowRadius : Constants.size3Xl
    readonly property real contentPadding: widget ? widget.smoothContentPadding : Constants.sizeLg
    readonly property var notificationService: widget ? widget.notificationService : null
    readonly property bool _windowVisible: widget ? widget._windowVisible : false
    readonly property bool forceVisible: widget ? widget.forceVisible : false
    property alias contentSlot: contentLayoutContainer
    property alias container: mainContainer
    property bool isHandover: false
    readonly property real bounceProgress: widget ? widget.bounceProgress : 0

    anchors.fill: parent

    // Dismiss backdrop when clicking outside the dialog
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        enabled: root.isOpen
        onClicked: {
            if (root.widget && typeof root.widget.close === "function") {
                root.widget.close();
            } else {
                AppState.closeAllWidgets();
            }
        }
    }

    Item {
        id: mainContainer

        readonly property real targetY: widget && widget.positionAtBottom ? (parent.height - preferredHeight - 32) : ((parent.height - preferredHeight) / 2)

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(targetY)
        width: Math.round(preferredWidth)
        height: Math.round(preferredHeight)
        scale: root.isOpen ? (0.94 + 0.06 * bounceProgress) : 0.94
        opacity: root.isOpen ? bounceProgress : 0

        // Prevent click propagation through the popup
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            anchors.fill: parent
            radius: root.windowRadius
            color: Theme.bg
            border.color: Theme.borderSecondary
            border.width: 1

            layer.enabled: true
            layer.effect: DropShadow {
                transparentBorder: true
                color: Theme.shadow
                radius: Constants.sizeXl
                samples: 16
                verticalOffset: 6
                horizontalOffset: 0
            }
        }

        Item {
            id: contentLayoutContainer

            anchors.fill: parent
            anchors.margins: root.contentPadding
            clip: true
        }

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutBack
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutCubic
            }
        }
    }
}
