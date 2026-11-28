import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

SettingRowTemplate {
    id: root

    property var model: []
    property var currentValue

    signal activated(var value)

    Rectangle {
        id: controlContainer

        property real indicatorX: 0
        property real indicatorWidth: 0

        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitHeight: 28
        implicitWidth: row.implicitWidth
        radius: 7
        color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)
        border.width: 1
        border.color: Theme.borderSecondary

        // macOS Segmented Elevated Active Indicator Thumb
        Rectangle {
            id: activeIndicator

            x: controlContainer.indicatorX + 2
            y: 2
            width: Math.max(0, controlContainer.indicatorWidth - 4)
            height: controlContainer.height - 4
            radius: 5
            color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.20) : "#FFFFFF"
            border.width: Theme.isDark ? 0.5 : 0.5
            border.color: Theme.isDark ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.08)
            layer.enabled: !Theme.isDark

            layer.effect: DropShadow {
                transparentBorder: true
                color: "#00000022"
                radius: 2
                samples: 5
                verticalOffset: 1
            }

            Behavior on x {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: Constants.animFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            id: row
            anchors.fill: parent

            Repeater {
                model: root.model

                delegate: Item {
                    property bool isActive: root.currentValue === modelData.value

                    width: Math.max(50, textItem.implicitWidth + 16)
                    height: controlContainer.height
                    onIsActiveChanged: {
                        if (isActive) {
                            controlContainer.indicatorX = x;
                            controlContainer.indicatorWidth = width;
                        }
                    }
                    Component.onCompleted: {
                        if (isActive) {
                            controlContainer.indicatorX = x;
                            controlContainer.indicatorWidth = width;
                        }
                    }
                    onXChanged: {
                        if (isActive)
                            controlContainer.indicatorX = x;
                    }
                    onWidthChanged: {
                        if (isActive)
                            controlContainer.indicatorWidth = width;
                    }

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: 5
                        color: mouseArea.containsMouse && !isActive ? (Theme.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)) : "transparent"

                        ThemedText {
                            id: textItem
                            anchors.centerIn: parent
                            text: modelData.text
                            font.weight: isActive ? Font.DemiBold : Font.Normal
                            customSize: 11
                            color: isActive ? (Theme.isDark ? "#FFFFFF" : "#1D1D1F") : (mouseArea.containsMouse ? Theme.fg : Theme.muted)

                            Behavior on color {
                                ColorAnimation {
                                    duration: Constants.animFast
                                }
                            }
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!isActive)
                                    root.activated(modelData.value);
                            }
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Constants.animFast
                            }
                        }
                    }
                }
            }
        }
    }
}
