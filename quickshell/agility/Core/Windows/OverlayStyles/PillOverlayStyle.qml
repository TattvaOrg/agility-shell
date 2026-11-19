import Qt5Compat.GraphicalEffects
import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Modules.Bar

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

        readonly property real pillThickness: SettingsService.pillBarThickness > 0 ? SettingsService.pillBarThickness : 38
        readonly property real barBottom: BarStyleConfig.barMarginTop("pill") + pillThickness
        readonly property real targetYTop: Math.round(barBottom + 8)
        readonly property real targetYBottom: Math.round(parent.height - preferredHeight - 24)
        readonly property bool isBottom: widget ? widget.positionAtBottom : false
        readonly property real targetY: isBottom ? targetYBottom : targetYTop

        // Slide distance: slides up into the pill bar when at top, or down when at bottom
        readonly property real slideDistance: isBottom ? 48 : Math.max(36, targetYTop)
        readonly property real currentY: isBottom
            ? Math.round(targetY + (1 - bounceProgress) * slideDistance)
            : Math.round(targetY - (1 - bounceProgress) * slideDistance)

        anchors.horizontalCenter: parent.horizontalCenter
        y: currentY
        width: Math.round(preferredWidth)
        height: Math.round(preferredHeight)
        scale: 0.96 + 0.04 * bounceProgress
        opacity: Math.min(1, Math.max(0, bounceProgress))

        // Prevent click propagation through the popup
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Rectangle {
            anchors.fill: parent
            radius: root.windowRadius > 0 ? root.windowRadius : Constants.size3Xl
            color: {
                if (SettingsService.barGlassMode === "solid")
                    return (SettingsService.barSolidTone === "white") ? Theme.solidWhiteBarBg : Qt.rgba(0.04, 0.04, 0.05, 1.0);
                return Theme.bg;
            }
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
            opacity: !root.isOpen ? Math.min(1, Math.max(0, (bounceProgress - 0.25) / 0.75)) : Math.min(1, Math.max(0, (bounceProgress - 0.1) / 0.9))
        }
    }
}
