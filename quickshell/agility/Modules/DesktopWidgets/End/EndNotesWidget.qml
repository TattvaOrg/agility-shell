/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/notes/NotesWidget.qml),
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

    widgetId: "notes"
    displayName: "Notes"
    baseWidth: 276
    baseHeight: 250

    property bool editing: false
    property var pendingNoteId: null
    property var items: EndWidgetStore.getPref("notes", "items", [])
    signal textFocusRequested(bool active)

    onEditingChanged: textFocusRequested(editing)

    Connections {
        target: EndWidgetStore
        function onLoadedChanged() {
            if (EndWidgetStore.loaded)
                root.items = EndWidgetStore.getPref("notes", "items", []);
        }
    }

    function saveItems(next) {
        items = next;
        EndWidgetStore.setPref("notes", "items", next);
    }

    function openNew() {
        pendingNoteId = null;
        noteEditor.text = "";
        editing = true;
        noteEditor.forceActiveFocus();
    }

    function openExisting(note) {
        pendingNoteId = note.id;
        noteEditor.text = note.content || "";
        editing = true;
        noteEditor.forceActiveFocus();
    }

    function commitNote() {
        let txt = noteEditor.text.trim();
        if (txt.length > 0) {
            if (pendingNoteId !== null) {
                let next = items.map(n => n.id === pendingNoteId ? { "id": n.id, "content": txt } : n);
                saveItems(next);
            } else {
                let nextId = Date.now();
                let next = items.concat([{ "id": nextId, "content": txt }]);
                saveItems(next);
            }
        }
        editing = false;
    }

    function deleteNote(id) {
        saveItems(items.filter(n => n.id !== id));
    }

    EndWidgetCard {
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10
            visible: !root.editing

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Notes"
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
                        onClicked: root.openNew()
                    }
                }
            }

            ListView {
                id: notesList
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 6
                model: root.items

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: notesList.width
                    height: 48
                    radius: 14
                    opacity: 0.94
                    readonly property color pillBg: {
                        let m = index % 3;
                        if (m === 0) return EndTheme.tertiary;
                        if (m === 1) return EndTheme.primary;
                        return EndTheme.secondary;
                    }
                    readonly property color pillFg: {
                        let m = index % 3;
                        if (m === 0) return EndTheme.onTertiary;
                        if (m === 1) return EndTheme.onPrimary;
                        return EndTheme.onSecondary;
                    }
                    color: pillBg

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: modelData.content || ""
                            color: pillFg
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            maximumLineCount: 1

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openExisting(modelData)
                            }
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
                                onClicked: root.deleteNote(modelData.id)
                            }
                        }
                    }
                }
            }
        }

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
                    implicitWidth: saveNoteTxt.implicitWidth + 18
                    implicitHeight: 28
                    radius: 14
                    color: Theme.accent
                    Text {
                        id: saveNoteTxt
                        anchors.centerIn: parent
                        text: "Save"
                        color: Theme.isDark ? "#000000" : "#ffffff"
                        font.family: SettingsService.fontFamily
                        font.pixelSize: 11
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.commitNote()
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
                    id: noteEditor
                    anchors.fill: parent
                    anchors.margins: 10
                    wrapMode: TextArea.Wrap
                    placeholderText: "Type your note..."
                    placeholderTextColor: Theme.muted
                    color: Theme.fg
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 12
                    background: null
                    Keys.onEscapePressed: root.editing = false
                    Keys.onReturnPressed: (event) => {
                        if (event.modifiers & Qt.ControlModifier) {
                            root.commitNote();
                            event.accepted = true;
                        }
                    }
                }
            }
        }
    }
}
