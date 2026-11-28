/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/calendar/CalendarWidget.qml),
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

    widgetId: "calendar"
    displayName: "Calendar"
    sizeModes: ["1x2", "1x1", "2x2", "2x3"]
    sizeMode: EndWidgetStore.getPref("calendar", "sizeMode", "1x2")

    baseWidth: sizeMode === "1x1" ? 132 : (sizeMode === "2x3" ? 420 : 276)
    baseHeight: (sizeMode === "1x1" || sizeMode === "1x2") ? 118 : 250

    property int monthShift: 0
    readonly property var today: new Date()
    readonly property var viewingDate: {
        let d = new Date();
        d.setDate(1);
        d.setMonth(d.getMonth() + monthShift);
        return d;
    }

    function getMonthMatrix(date) {
        let year = date.getFullYear();
        let month = date.getMonth();
        let firstOfMonth = new Date(year, month, 1);
        let startOffset = (firstOfMonth.getDay() + 6) % 7;
        let daysInMonth = new Date(year, month + 1, 0).getDate();
        let daysInPrev = new Date(year, month, 0).getDate();

        let cells = [];
        for (let i = 0; i < startOffset; i++)
            cells.push({ day: daysInPrev - startOffset + i + 1, currentMonth: false, isToday: false });

        for (let d = 1; d <= daysInMonth; d++) {
            let isT = (monthShift === 0 && d === today.getDate() && month === today.getMonth() && year === today.getFullYear());
            cells.push({ day: d, currentMonth: true, isToday: isT });
        }

        let nextDay = 1;
        while (cells.length < 42)
            cells.push({ day: nextDay++, currentMonth: false, isToday: false });

        let weeks = [];
        for (let i = 0; i < cells.length; i += 7)
            weeks.push(cells.slice(i, i + 7));
        return weeks;
    }

    function getCurrentWeek() {
        let matrix = getMonthMatrix(viewingDate);
        for (let w = 0; w < matrix.length; w++) {
            if (matrix[w].some(c => c.isToday))
                return matrix[w];
        }
        return matrix[0];
    }

    EndWidgetCard {
        anchors.fill: parent
        clip: true

        // 1x1: Compact Day Card
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: root.sizeMode === "1x1"

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                color: Theme.accent

                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Text {
                        text: root.today.toLocaleDateString(Qt.locale(), "MMM").toUpperCase()
                        color: Theme.isDark ? "#000000" : "#ffffff"
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    Text {
                        text: root.today.toLocaleDateString(Qt.locale(), "ddd").toUpperCase()
                        color: Theme.isDark ? "#000000" : "#ffffff"
                        opacity: 0.75
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Text {
                    anchors.centerIn: parent
                    text: root.today.getDate()
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 48
                    font.weight: Font.Black
                }
            }
        }

        // 1x2: Current Week Strip (matches screenshot top-right)
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            visible: root.sizeMode === "1x2"

            Rectangle {
                implicitHeight: 26
                implicitWidth: monthPillText.implicitWidth + 20
                radius: 13
                color: EndTheme.primary

                Text {
                    id: monthPillText
                    anchors.centerIn: parent
                    text: root.today.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: EndTheme.onPrimary
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Grid {
                columns: 7
                rowSpacing: 4
                columnSpacing: 0
                Layout.fillWidth: true

                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Item {
                        width: (276 - 28) / 7
                        height: 18
                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            color: EndTheme.onCardMuted
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 10
                            font.weight: Font.Bold
                        }
                    }
                }

                Repeater {
                    model: root.getCurrentWeek()
                    Item {
                        required property var modelData
                        width: (276 - 28) / 7
                        height: 28
                        Rectangle {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            radius: 13
                            color: modelData.isToday ? EndTheme.primary : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.isToday ? EndTheme.onPrimary : EndTheme.onCard
                                opacity: modelData.currentMonth ? 1.0 : 0.35
                                font.family: SettingsService.fontFamily
                                font.pixelSize: 11
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // 2x2: Full Month Interactive Calendar
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            visible: root.sizeMode === "2x2"

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.fillWidth: true
                    text: root.viewingDate.toLocaleDateString(Qt.locale(), "MMMM yyyy")
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "chevron-left"
                        iconSize: 12
                        iconColor: Theme.fg
                        flat: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthShift--
                    }
                }

                Rectangle {
                    implicitWidth: 24
                    implicitHeight: 24
                    radius: 12
                    color: Theme.bgSecondary
                    border.width: 1
                    border.color: Theme.border
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "chevron-right"
                        iconSize: 12
                        iconColor: Theme.fg
                        flat: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.monthShift++
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                Repeater {
                    model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.muted
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.Bold
                    }
                }
            }

            Grid {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                Repeater {
                    model: {
                        let flat = [];
                        let m = root.getMonthMatrix(root.viewingDate);
                        for (let i = 0; i < m.length; i++) flat = flat.concat(m[i]);
                        return flat;
                    }
                    Item {
                        required property var modelData
                        width: (276 - 28) / 7
                        height: 27
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData.isToday ? Theme.accent : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.day
                                color: modelData.isToday ? (Theme.isDark ? "#000000" : "#ffffff") : Theme.fg
                                opacity: modelData.currentMonth ? 1.0 : 0.3
                                font.family: SettingsService.fontFamily
                                font.pixelSize: 10
                                font.weight: modelData.isToday ? Font.Bold : Font.Normal
                            }
                        }
                    }
                }
            }
        }

        // 2x3: Split Summary + Month Grid
        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14
            visible: root.sizeMode === "2x3"

            ColumnLayout {
                Layout.preferredWidth: 112
                Layout.fillHeight: true
                spacing: 4

                Item {
                    width: 42
                    height: 42
                    MaterialShape {
                        anchors.fill: parent
                        shape: MaterialShape.Shape.Gem
                        color: Theme.accent
                    }
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "calendar"
                        iconSize: 18
                        iconColor: Theme.isDark ? "#000000" : "#ffffff"
                        flat: true
                    }
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: root.today.toLocaleDateString(Qt.locale(), "MMMM").toUpperCase()
                    color: Theme.muted
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
                Text {
                    text: root.today.toLocaleDateString(Qt.locale(), "dddd")
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.today.getDate()
                    color: Theme.accent
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 56
                    font.weight: Font.Black
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: Theme.bgSecondary

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            Text {
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData
                                color: Theme.muted
                                font.family: SettingsService.fontFamily
                                font.pixelSize: 10
                                font.weight: Font.Bold
                            }
                        }
                    }

                    Grid {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 7
                        rowSpacing: 2

                        Repeater {
                            model: {
                                let flat = [];
                                let m = root.getMonthMatrix(root.today);
                                for (let i = 0; i < m.length; i++) flat = flat.concat(m[i]);
                                return flat;
                            }
                            Item {
                                required property var modelData
                                width: (262 - 20) / 7
                                height: 26
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 23
                                    height: 23
                                    radius: 11.5
                                    color: modelData.isToday ? Theme.accent : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        color: modelData.isToday ? (Theme.isDark ? "#000000" : "#ffffff") : Theme.fg
                                        opacity: modelData.currentMonth ? 1.0 : 0.3
                                        font.family: SettingsService.fontFamily
                                        font.pixelSize: 10
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
