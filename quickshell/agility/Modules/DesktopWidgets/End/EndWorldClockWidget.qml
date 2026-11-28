/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/worldclock/WorldClockWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "worldClock"
    displayName: "World Clock"
    sizeModes: ["2x2", "4x1"]
    sizeMode: EndWidgetStore.getPref("worldClock", "sizeMode", "2x2")
    supportsFlip: sizeMode === "4x1"
    isVertical: EndWidgetStore.getPref("worldClock", "vertical", false)

    baseWidth: sizeMode === "4x1" ? (isVertical ? 132 : 564) : 276
    baseHeight: sizeMode === "4x1" ? (isVertical ? 508 : 118) : 250

    property var timezones: EndWidgetStore.getPref("worldClock", "timezones", ["Asia/Manila", "Asia/Kolkata", "Asia/Tokyo", "Asia/Seoul"])
    property var cityEntries: []
    property string localTime: ""
    property string localDate: ""

    function formatZone(tz, now) {
        let city = tz.split("/").pop().replace(/_/g, " ");
        try {
            let parts = new Intl.DateTimeFormat("en-US", {
                timeZone: tz,
                hour: "2-digit",
                minute: "2-digit",
                hour12: !SettingsService.clock24h
            }).formatToParts(now);
            let h24 = parseInt(new Intl.DateTimeFormat("en-US", {
                timeZone: tz, hour: "numeric", hour12: false
            }).format(now)) || 0;
            let timeTxt = new Intl.DateTimeFormat("en-US", {
                timeZone: tz,
                hour: "2-digit",
                minute: "2-digit",
                hour12: !SettingsService.clock24h
            }).format(now);
            let offTxt = "";
            try {
                let tzPart = new Intl.DateTimeFormat("en-US", {
                    timeZone: tz, timeZoneName: "shortOffset"
                }).formatToParts(now).find(p => p.type === "timeZoneName");
                offTxt = tzPart ? tzPart.value.replace("GMT", "UTC") : "";
            } catch (e2) { offTxt = ""; }
            return {
                name: city,
                time: timeTxt,
                offset: offTxt,
                isDay: h24 >= 6 && h24 < 19
            };
        } catch (e) {
            return { name: city, time: "--:--", offset: "", isDay: true };
        }
    }

    function refreshTimes() {
        let now = new Date();
        let h = now.getHours();
        let m = now.getMinutes();
        if (!SettingsService.clock24h) {
            let ampm = h >= 12 ? "PM" : "AM";
            let h12 = h % 12 || 12;
            localTime = h12 + ":" + (m < 10 ? "0" + m : m) + " " + ampm;
        } else {
            localTime = (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
        }
        localDate = Qt.locale().toString(now, "dddd, MMMM d yyyy");
        let list = [];
        let zones = root.timezones || [];
        for (let i = 0; i < Math.min(4, zones.length); i++) {
            list.push(formatZone(zones[i], now));
        }
        cityEntries = list;
    }

    Timer {
        interval: 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshTimes()
    }

    // 2x2 Card (matches screenshot middle-left)
    EndWidgetCard {
        anchors.fill: parent
        visible: root.sizeMode === "2x2"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                SvgIcon {
                    icon: "clock"
                    iconSize: 14
                    iconColor: EndTheme.primary
                    flat: true
                }
                Text {
                    Layout.fillWidth: true
                    text: WeatherService.city !== "Loading..." ? WeatherService.city : "Local Time"
                    color: EndTheme.onCard
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: root.localTime
                    color: EndTheme.onCard
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 32
                    font.weight: Font.Bold
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: root.localDate
                    color: EndTheme.onCardMuted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 11
                }
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 2
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    model: root.cityEntries
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: modelData.isDay ? Qt.rgba(EndTheme.primary.r, EndTheme.primary.g, EndTheme.primary.b, 0.24) : EndTheme.chipBg
                        border.width: 1
                        border.color: modelData.isDay ? Qt.rgba(EndTheme.primary.r, EndTheme.primary.g, EndTheme.primary.b, 0.45) : EndTheme.chipBorder

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    color: EndTheme.onCard
                                    font.family: SettingsService.fontFamily
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: modelData.offset
                                    color: EndTheme.onCardMuted
                                    font.family: SettingsService.fontFamily
                                    font.pixelSize: 8
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.time
                                    color: EndTheme.onCard
                                    font.family: SettingsService.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                }
                                SvgIcon {
                                    icon: modelData.isDay ? "sun" : "moon"
                                    iconSize: 11
                                    iconColor: modelData.isDay ? EndTheme.primary : EndTheme.onCardMuted
                                    flat: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // 4x1 Strip
    GridLayout {
        anchors.fill: parent
        visible: root.sizeMode === "4x1"
        columns: root.isVertical ? 1 : 4
        rowSpacing: 12
        columnSpacing: 12

        Repeater {
            model: root.cityEntries
            delegate: EndWidgetCard {
                required property var modelData
                Layout.preferredWidth: 132
                Layout.preferredHeight: 118
                trackX: x
                trackY: y

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Theme.fg
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        SvgIcon {
                            icon: modelData.isDay ? "sun" : "moon"
                            iconSize: 12
                            iconColor: modelData.isDay ? Theme.accent : Theme.muted
                            flat: true
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Text {
                        text: modelData.time
                        color: Theme.accent
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }
                    Text {
                        text: modelData.offset
                        color: Theme.muted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
