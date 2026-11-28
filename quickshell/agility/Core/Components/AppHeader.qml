import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

ColumnLayout {
    id: root

    property string title: ""
    property string category: ""
    property string subtitle: ""
    property bool showDivider: false
    property bool canGoBack: false
    property string backText: "Back"
    signal backClicked()
    default property alias actions: rightSlot.data

    Layout.fillWidth: true
    spacing: 0

    Item {
        Layout.fillWidth: true
        implicitHeight: 52

        RowLayout {
            id: headerRow

            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: Constants.sizeMd

            // macOS Back Navigation Button
            RowLayout {
                visible: root.canGoBack
                spacing: 4
                Layout.alignment: Qt.AlignVCenter

                Rectangle {
                    width: 26
                    height: 26
                    radius: 5
                    color: backHover.hovered ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"

                    HoverHandler {
                        id: backHover
                    }

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "chevron-left"
                        iconSize: 14
                        flat: true
                        iconColor: Theme.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backClicked()
                    }
                }

                ThemedText {
                    text: root.backText
                    customSize: 13
                    font.weight: Font.Medium
                    color: Theme.accent

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.backClicked()
                    }
                }
            }

            ColumnLayout {
                spacing: 1
                Layout.alignment: Qt.AlignVCenter
                Layout.maximumWidth: parent.width - (rightSlot.width > 0 ? rightSlot.width + Constants.sizeMd : 0)

                ThemedText {
                    text: root.title
                    customSize: 16
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                ThemedText {
                    visible: root.subtitle !== ""
                    text: root.subtitle
                    customSize: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Item {
                Layout.fillWidth: true
            }

            RowLayout {
                id: rightSlot

                Layout.alignment: Qt.AlignVCenter
                spacing: Constants.sizeSm
            }
        }
    }

    Divider {
        visible: root.showDivider
    }
}
