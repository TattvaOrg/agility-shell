import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Core
import qs.Core.Components
import qs.Core.Services

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "agility-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        bottom: true
    }

    margins {
        bottom: 84
    }

    implicitWidth: 280
    implicitHeight: 56
    width: implicitWidth
    height: implicitHeight
    color: "transparent"
    visible: OsdService.isVisible || scaleAnimation.running

    Rectangle {
        id: container
        anchors.fill: parent
        radius: height / 2
        color: Theme.bg
        border.color: Theme.border
        border.width: 1

        opacity: OsdService.isVisible ? 1.0 : 0.0
        scale: OsdService.isVisible ? 1.0 : 0.88

        Behavior on opacity {
            NumberAnimation { duration: Constants.animFast; easing.type: Easing.OutQuad }
        }

        Behavior on scale {
            id: scaleAnimation
            NumberAnimation { duration: Constants.animNormal; easing.type: Easing.OutBack }
        }

        layer.enabled: true
        layer.effect: DropShadow {
            transparentBorder: true
            color: Theme.shadow
            radius: Constants.sizeMd
            samples: 12
            verticalOffset: 4
            horizontalOffset: 0
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Constants.sizeMd
            anchors.rightMargin: Constants.sizeMd
            spacing: Constants.sizeSm

            SvgIcon {
                icon: OsdService.displayIcon
                iconSize: 22
                iconColor: Theme.accent
                flat: true
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Constants.size3Xs
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    Layout.fillWidth: true

                    ThemedText {
                        text: OsdService.activeType === "volume" ? (OsdService.isMuted ? "Muted" : "Volume") : "Brightness"
                        font.family: Constants.fontFamily
                        font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                        font.bold: true
                        color: Theme.fg
                    }

                    Item { Layout.fillWidth: true }

                    ThemedText {
                        text: OsdService.isMuted ? "0%" : (OsdService.displayValue + "%")
                        font.family: Constants.fontFamily
                        font.pixelSize: Math.round(Constants.sizeSm * SettingsService.fontScale)
                        font.bold: true
                        color: Theme.accent
                    }
                }

                // Progress Bar
                Rectangle {
                    id: track
                    Layout.fillWidth: true
                    implicitHeight: 5
                    radius: 3
                    color: Theme.bgSecondary

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: Math.round(track.width * (Math.min(100, Math.max(0, OsdService.displayValue)) / 100))
                        radius: 3
                        color: Theme.accent

                        Behavior on width {
                            NumberAnimation { duration: Constants.animFast; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
