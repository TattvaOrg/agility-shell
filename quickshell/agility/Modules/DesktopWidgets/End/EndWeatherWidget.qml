/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/weather/WeatherWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Uses Agility Shell's WeatherService. Combined under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "weather"
    displayName: "Weather"
    sizeModes: ["1x3", "1x1", "1x2", "2x2", "2x3"]
    sizeMode: EndWidgetStore.getPref("weather", "sizeMode", "1x3")

    baseWidth: sizeMode === "1x1" ? 132 : ((sizeMode === "1x2" || sizeMode === "2x2") ? 276 : 420)
    baseHeight: (sizeMode === "2x2" || sizeMode === "2x3") ? 250 : 118

    Component.onCompleted: WeatherService.refreshWeather(false)

    component MetricPill: Rectangle {
        property string label: ""
        property string value: ""
        property string iconName: "sun"
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 14
        color: EndTheme.chipBg
        border.width: 1
        border.color: EndTheme.chipBorder

        RowLayout {
            anchors.centerIn: parent
            spacing: 5
            SvgIcon {
                icon: iconName
                iconSize: 13
                iconColor: EndTheme.primary
                flat: true
            }
            Text {
                text: value
                color: EndTheme.onCard
                font.family: SettingsService.fontFamily
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }

    EndWidgetCard {
        anchors.fill: parent

        // 1x1
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 2
            visible: root.sizeMode === "1x1"

            Item {
                Layout.alignment: Qt.AlignRight
                width: 34
                height: 34
                MaterialShape {
                    anchors.fill: parent
                    shape: MaterialShape.Shape.Cookie12Sided
                    color: Theme.accent
                }
                SvgIcon {
                    anchors.centerIn: parent
                    icon: "sun"
                    iconSize: 16
                    iconColor: Theme.isDark ? "#000000" : "#ffffff"
                    flat: true
                }
            }

            Item { Layout.fillHeight: true }

            Text {
                text: WeatherService.displayTemp
                color: Theme.fg
                font.family: SettingsService.fontFamily
                font.pixelSize: 28
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: WeatherService.city
                color: Theme.muted
                font.family: SettingsService.fontFamily
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }

        // 1x2
        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12
            visible: root.sizeMode === "1x2"

            Rectangle {
                Layout.preferredWidth: 94
                Layout.fillHeight: true
                radius: 16
                color: Theme.bgSecondary

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 4
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        width: 40
                        height: 40
                        MaterialShape {
                            anchors.fill: parent
                            shape: MaterialShape.Shape.Cookie12Sided
                            color: Theme.accent
                        }
                        SvgIcon {
                            anchors.centerIn: parent
                            icon: "sun"
                            iconSize: 18
                            iconColor: Theme.isDark ? "#000000" : "#ffffff"
                            flat: true
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: WeatherService.displayTemp
                        color: Theme.fg
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: WeatherService.city
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: WeatherService.conditionText
                    color: Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    MetricPill { iconName: "info"; value: WeatherService.humidity + "%" }
                    MetricPill { iconName: "refresh"; value: WeatherService.windSpeed + "km/h" }
                }
            }
        }

        // 1x3 (matches reference screenshot right upper)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sizeMode === "1x3"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: WeatherService.displayTemp
                    color: EndTheme.primary
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 38
                    font.weight: Font.Bold
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        Layout.fillWidth: true
                        text: WeatherService.conditionText
                        color: EndTheme.onCard
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: WeatherService.city
                        color: EndTheme.onCardMuted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Item {
                    width: 48
                    height: 48
                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: EndTheme.primary
                    }
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "sun"
                        iconSize: 22
                        iconColor: EndTheme.onPrimary
                        flat: true
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                MetricPill { iconName: "info"; value: WeatherService.humidity + "%" }
                MetricPill { iconName: "sun"; value: WeatherService.displayFeelsLike }
                MetricPill { iconName: "refresh"; value: WeatherService.windSpeed + " km/h" }
            }
        }

        // 2x2 and 2x3
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: root.sizeMode === "2x2" || root.sizeMode === "2x3"

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Item {
                    width: 48
                    height: 48
                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Theme.accent
                    }
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "sun"
                        iconSize: 22
                        iconColor: Theme.isDark ? "#000000" : "#ffffff"
                        flat: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: WeatherService.displayTemp
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 34
                        font.weight: Font.Bold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: WeatherService.conditionText + " • " + WeatherService.city
                        color: Theme.muted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: Theme.bgSecondary
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "refresh"
                        iconSize: 14
                        iconColor: Theme.fg
                        flat: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: WeatherService.refreshWeather(true)
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 8
                columnSpacing: 8

                MetricPill { Layout.fillHeight: true; iconName: "info"; value: "Humidity: " + WeatherService.humidity + "%" }
                MetricPill { Layout.fillHeight: true; iconName: "sun"; value: "Feels: " + WeatherService.displayFeelsLike }
                MetricPill { Layout.fillHeight: true; iconName: "refresh"; value: "Wind: " + WeatherService.windSpeed + " km/h" }
                MetricPill { Layout.fillHeight: true; iconName: "moon"; value: WeatherService.city }
            }
        }
    }
}
