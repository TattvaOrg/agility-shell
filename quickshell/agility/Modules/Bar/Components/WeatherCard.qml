import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Rectangle {
    id: root

    property bool isOpen: false

    signal closeRequested()

    width: 270
    implicitHeight: mainLayout.implicitHeight + Constants.sizeLg * 2
    radius: Constants.sizeMd
    color: Theme.bg
    border.color: Theme.borderSecondary
    border.width: 1

    opacity: isOpen ? 1 : 0
    scale: isOpen ? 1 : 0.94
    visible: opacity > 0.001

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }
    }

    Behavior on scale {
        NumberAnimation {
            duration: Constants.animNormal
            easing.type: Easing.OutCubic
        }
    }

    layer.enabled: true
    layer.effect: DropShadow {
        transparentBorder: true
        color: Theme.shadow
        radius: Constants.sizeLg
        samples: 16
        verticalOffset: 6
        horizontalOffset: 0
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Constants.sizeMd
        spacing: Constants.sizeSm

        // Header: Location & Refresh Button
        RowLayout {
            Layout.fillWidth: true

            SvgIcon {
                icon: "sparkles"
                iconSize: 13
                flat: true
                iconColor: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            ThemedText {
                text: WeatherService.city
                customSize: 13
                font.weight: Font.Bold
                color: Theme.fg
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                width: 24
                height: 24
                radius: 12
                color: refreshHover.hovered ? Theme.bgSecondary : "transparent"
                Layout.alignment: Qt.AlignVCenter

                SvgIcon {
                    anchors.centerIn: parent
                    icon: "refresh"
                    iconSize: 12
                    flat: true
                    iconColor: WeatherService.isFetching ? Theme.accent : Theme.muted
                    rotation: WeatherService.isFetching ? 360 : 0

                    Behavior on rotation {
                        NumberAnimation {
                            duration: 800
                            loops: Animation.Infinite
                        }
                    }
                }

                HoverHandler {
                    id: refreshHover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: WeatherService.refreshWeather(true)
                }
            }
        }

        // Current Weather Hero
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeMd

            SvgIcon {
                icon: WeatherService.conditionIcon
                iconSize: 38
                flat: true
                iconColor: Theme.accent
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: 0
                Layout.fillWidth: true

                ThemedText {
                    text: WeatherService.displayTemp
                    customSize: 26
                    font.weight: Font.Bold
                    color: Theme.fg
                }

                ThemedText {
                    text: WeatherService.conditionText + " • Feels " + WeatherService.displayFeelsLike
                    customSize: 11
                    color: Theme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        // Quick Stats: Humidity & Wind
        RowLayout {
            Layout.fillWidth: true
            spacing: Constants.sizeSm

            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: Constants.sizeXs
                color: Theme.bgSecondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    ThemedText {
                        text: "💧"
                        customSize: 10
                    }
                    ThemedText {
                        text: WeatherService.humidity + "% Humidity"
                        customSize: 10
                        color: Theme.muted
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: Constants.sizeXs
                color: Theme.bgSecondary

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 4

                    ThemedText {
                        text: "💨"
                        customSize: 10
                    }
                    ThemedText {
                        text: WeatherService.windSpeed + " km/h"
                        customSize: 10
                        color: Theme.muted
                    }
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSecondary
            opacity: 0.5
        }

        // 3-Day Forecast Section Header
        ThemedText {
            text: "3-DAY FORECAST"
            customSize: 9
            font.weight: Font.Bold
            font.letterSpacing: 0.8
            color: Theme.muted
            Layout.topMargin: 2
        }

        // 3-Day Forecast Rows
        Repeater {
            model: WeatherService.dailyForecast

            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Constants.sizeSm

                ThemedText {
                    text: modelData.day
                    customSize: 11
                    font.weight: Font.Medium
                    color: Theme.fg
                    Layout.preferredWidth: 60
                }

                SvgIcon {
                    icon: modelData.icon
                    iconSize: 14
                    flat: true
                    iconColor: Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }

                ThemedText {
                    text: modelData.condition
                    customSize: 10
                    color: Theme.muted
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                ThemedText {
                    text: modelData.max + " / " + modelData.min
                    customSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.fg
                    Layout.alignment: Qt.AlignRight
                }
            }
        }
    }
}
