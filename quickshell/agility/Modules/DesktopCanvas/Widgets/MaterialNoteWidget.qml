import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Services
import qs.Core.Utils

Rectangle {
    id: root

    implicitWidth: 320
    implicitHeight: 200
    radius: MaterialTheme.cardRadius
    color: MaterialTheme.cardBackground
    border.width: 1
    border.color: MaterialTheme.cardBorder

    property bool hovered: noteMouseArea.containsMouse

    scale: hovered ? 1.02 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: MaterialTheme.animDurationFast
            easing.type: Easing.OutCubic
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: MaterialTheme.animDurationNormal
        }
    }

    MouseArea {
        id: noteMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        // Header Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: MaterialTheme.chipRadius
                color: MaterialTheme.m3primaryContainer

                Text {
                    anchors.centerIn: parent
                    text: "📝"
                    font.pixelSize: 13
                }
            }

            Text {
                text: "Quick Note"
                font.family: SettingsService.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: MaterialTheme.m3onSurface
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                implicitHeight: 20
                implicitWidth: savedBadgeText.implicitWidth + 14
                radius: 10
                color: MaterialTheme.m3secondaryContainer

                Text {
                    id: savedBadgeText
                    anchors.centerIn: parent
                    text: "Synced"
                    font.family: SettingsService.fontFamily
                    font.pixelSize: 10
                    font.bold: true
                    color: MaterialTheme.m3onSecondaryContainer
                }
            }
        }

        // Editable Note Field
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: noteEdit.implicitHeight
            clip: true

            TextArea {
                id: noteEdit
                width: parent.width
                text: SettingsService.noteContent
                wrapMode: Text.Wrap
                color: MaterialTheme.m3onSurface
                font.family: SettingsService.fontFamily
                font.pixelSize: 12
                background: Item {}
                padding: 4
                selectByMouse: true

                onTextChanged: {
                    if (SettingsService.noteContent !== text) {
                        SettingsService.noteContent = text;
                        saveNoteTimer.restart();
                    }
                }
            }
        }
    }

    Timer {
        id: saveNoteTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (SettingsService.settingsLoaded) {
                SettingsService.saveSettings();
            }
        }
    }
}
