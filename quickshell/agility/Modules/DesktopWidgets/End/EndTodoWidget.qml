/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/todo/TodoWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "todo"
    displayName: "To-Do"
    baseWidth: 276
    baseHeight: 250

    property bool editing: false
    property var items: EndWidgetStore.getPref("todo", "items", [])
    signal textFocusRequested(bool active)

    onEditingChanged: textFocusRequested(editing)

    Connections {
        target: EndWidgetStore
        function onLoadedChanged() {
            if (EndWidgetStore.loaded)
                root.items = EndWidgetStore.getPref("todo", "items", []);
        }
    }

    function saveItems(next) {
        items = next;
        EndWidgetStore.setPref("todo", "items", next);
    }

    function toggleItem(idx) {
        let next = items.map((it, i) => i === idx ? { "content": it.content, "done": !it.done } : it);
        saveItems(next);
    }

    function deleteItem(idx) {
        let next = items.filter((_, i) => i !== idx);
        saveItems(next);
    }

    function addItem(txt) {
        let trimmed = txt.trim();
        if (trimmed.length === 0)
            return;
        let next = items.concat([{ "content": trimmed, "done": false }]);
        saveItems(next);
    }

    EndWidgetCard {
        anchors.fill: parent

        // List View
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: !root.editing

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "To-Do"
                    color: EndTheme.onCard
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }

                Rectangle {
                    width: 34
                    height: 34
                    radius: 17
                    color: EndTheme.chipBg
                    border.width: 1
                    border.color: EndTheme.chipBorder

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "plus"
                        iconSize: 14
                        iconColor: EndTheme.onCard
                        flat: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            taskInput.text = "";
                            root.editing = true;
                            taskInput.forceActiveFocus();
                        }
                    }
                }
            }

            ListView {
                id: todoList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.items

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: todoList.width
                    height: 48
                    radius: 14
                    opacity: modelData.done ? 0.65 : 0.94
                    readonly property color pillBg: {
                        let m = index % 3;
                        if (m === 0) return EndTheme.secondary;
                        if (m === 1) return EndTheme.tertiary;
                        return EndTheme.primary;
                    }
                    readonly property color pillFg: {
                        let m = index % 3;
                        if (m === 0) return EndTheme.onSecondary;
                        if (m === 1) return EndTheme.onTertiary;
                        return EndTheme.onPrimary;
                    }
                    color: pillBg

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData.done ? Qt.rgba(pillFg.r, pillFg.g, pillFg.b, 0.20) : "transparent"
                            border.width: 1.8
                            border.color: pillFg

                            SvgIcon {
                                anchors.centerIn: parent
                                visible: modelData.done
                                icon: "check"
                                iconSize: 11
                                iconColor: pillFg
                                flat: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleItem(index)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: modelData.content || ""
                            color: pillFg
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            font.strikeout: Boolean(modelData.done)
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            width: 22
                            height: 22
                            radius: 11
                            color: "transparent"

                            SvgIcon {
                                anchors.centerIn: parent
                                icon: "trash"
                                iconSize: 12
                                iconColor: Qt.rgba(pillFg.r, pillFg.g, pillFg.b, 0.65)
                                flat: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteItem(index)
                            }
                        }
                    }
                }
            }
        }

        // Inline Add View
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: root.editing

            RowLayout {
                Layout.fillWidth: true

                Rectangle {
                    width: 28
                    height: 28
                    radius: 14
                    color: Theme.bgSecondary
                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "chevron-left"
                        iconSize: 13
                        iconColor: Theme.fg
                        flat: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.editing = false
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    implicitWidth: saveTaskTxt.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: Theme.accent
                    Text {
                        id: saveTaskTxt
                        anchors.centerIn: parent
                        text: "Add"
                        color: Theme.isDark ? "#000000" : "#ffffff"
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.addItem(taskInput.text);
                            root.editing = false;
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: Theme.bgSecondary
                border.width: 1
                border.color: Theme.border

                TextArea {
                    id: taskInput
                    anchors.fill: parent
                    anchors.margins: 10
                    wrapMode: TextArea.Wrap
                    placeholderText: "Type a task..."
                    placeholderTextColor: Theme.muted
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    background: null
                    Keys.onEscapePressed: root.editing = false
                    Keys.onReturnPressed: (event) => {
                        if (!(event.modifiers & Qt.ShiftModifier)) {
                            root.addItem(taskInput.text);
                            root.editing = false;
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
