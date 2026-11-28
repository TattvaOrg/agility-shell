import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components

Rectangle {
    id: rowRoot

    property string iconName: ""
    property string labelText: ""
    property string statusText: ""
    property string badgeColor: ""
    property bool isActive: false
    property bool hasChevron: false
    property bool isExpanded: false

    signal rowClicked()
    signal chevronClicked()

    Layout.fillWidth: true
    Layout.preferredHeight: 34
    radius: 7
    scale: tapHandler.pressed ? 0.985 : 1
    color: isActive ? Theme.accent : (hoverHandler.hovered ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05)) : "transparent")
    border.color: "transparent"
    border.width: 0

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Constants.sizeSm
        anchors.rightMargin: Constants.sizeSm
        spacing: Constants.sizeSm

        // macOS Squircle Icon Badge with original project SVG
        Rectangle {
            visible: rowRoot.badgeColor !== ""
            width: 24
            height: 24
            radius: 6
            color: rowRoot.badgeColor !== "" ? rowRoot.badgeColor : "transparent"
            Layout.alignment: Qt.AlignVCenter

            SvgIcon {
                anchors.centerIn: parent
                icon: rowRoot.iconName
                iconSize: 14
                flat: true
                iconColor: "#FFFFFF"
            }
        }

        // Standard Flat Icon fallback when no badge color is provided
        SvgIcon {
            visible: rowRoot.badgeColor === ""
            icon: rowRoot.iconName
            iconSize: 15
            flat: true
            iconColor: rowRoot.isActive ? "#FFFFFF" : (hoverHandler.hovered ? Theme.fg : Theme.muted)
            Layout.alignment: Qt.AlignVCenter

            Behavior on iconColor {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }

        ThemedText {
            text: rowRoot.labelText
            customSize: 13
            font.weight: rowRoot.isActive ? Font.DemiBold : Font.Normal
            color: rowRoot.isActive ? "#FFFFFF" : (hoverHandler.hovered ? Theme.fg : Theme.muted)
            elide: Text.ElideRight
            Layout.fillWidth: true

            Behavior on color {
                ColorAnimation {
                    duration: Constants.animFast
                }
            }
        }

        Rectangle {
            visible: rowRoot.statusText !== ""
            implicitHeight: Constants.sizeLg + 2
            implicitWidth: Math.max(statusLabel.implicitWidth + 10, 18)
            radius: height / 2
            color: rowRoot.isActive ? Qt.rgba(1, 1, 1, 0.25) : Theme.bgSecondary
            Layout.alignment: Qt.AlignVCenter

            ThemedText {
                id: statusLabel

                anchors.centerIn: parent
                text: rowRoot.statusText
                customSize: 10
                font.weight: rowRoot.isActive ? Font.Bold : Font.Normal
                color: rowRoot.isActive ? "#FFFFFF" : Theme.muted
            }
        }

        SvgIcon {
            visible: rowRoot.hasChevron
            icon: "chevron-down"
            iconSize: 12
            flat: true
            rotation: rowRoot.isExpanded ? 0 : -90
            iconColor: rowRoot.isActive ? "#FFFFFF" : (hoverHandler.hovered ? Theme.fg : Theme.muted)
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: Constants.size3Xs

            Behavior on rotation {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutQuad
                }
            }
        }
    }

    HoverHandler {
        id: hoverHandler
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        id: tapHandler
        onTapped: rowRoot.rowClicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Constants.animFast
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuart
        }
    }
}
