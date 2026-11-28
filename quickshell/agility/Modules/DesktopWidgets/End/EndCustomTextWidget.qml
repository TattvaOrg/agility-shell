/*
 * Adapted from pctrade/end4-pC (modules/ii/background/widgets/customtext/CustomTextWidget.qml),
 * originally derived from end-4/dots-hyprland (illogical-impulse), GNU GPL v3.0.
 * Modified for Agility Shell (2026) under AGPL-3.0 §13 / GPL-3.0 §13.
 */
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.Core
import qs.Core.Services

EndWidgetFrame {
    id: root

    widgetId: "customText"
    displayName: "Custom Text"

    property string contentText: EndWidgetStore.getPref("customText", "content", "Stay focused")
    property bool editing: false
    signal textFocusRequested(bool active)

    onEditingChanged: textFocusRequested(editing)

    baseWidth: Math.max(160, Math.round(editor.implicitWidth + 32))
    baseHeight: Math.max(60, Math.round(editor.implicitHeight + 24))

    Connections {
        target: EndWidgetStore
        function onLoadedChanged() {
            if (EndWidgetStore.loaded)
                root.contentText = EndWidgetStore.getPref("customText", "content", "Stay focused");
        }
    }

    function finishEdit(save) {
        if (!editing)
            return;
        if (save) {
            contentText = editor.text;
            EndWidgetStore.setPref("customText", "content", contentText);
        } else {
            editor.text = contentText;
        }
        editing = false;
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: root.editing ? Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.78) : "transparent"
        border.width: root.editing ? 1.5 : 0
        border.color: Theme.accent
    }

    TextEdit {
        id: editor
        anchors.centerIn: parent
        enabled: root.editing
        text: root.contentText
        textFormat: TextEdit.PlainText
        selectByMouse: true
        color: Theme.fg
        selectionColor: Theme.accent
        horizontalAlignment: TextEdit.AlignHCenter
        font.family: SettingsService.fontFamily
        font.pixelSize: 42
        font.weight: Font.Bold

        layer.enabled: true
        layer.effect: DropShadow {
            radius: 10
            samples: 15
            verticalOffset: 2
            color: Qt.rgba(0, 0, 0, 0.55)
            transparentBorder: true
        }

        Keys.onEscapePressed: root.finishEdit(false)
        Keys.onReturnPressed: (event) => {
            if (event.modifiers & Qt.ControlModifier) {
                root.finishEdit(true);
                event.accepted = true;
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: !root.editing && !root.editMode
        cursorShape: Qt.PointingHandCursor
        onDoubleClicked: {
            root.editing = true;
            editor.forceActiveFocus();
            editor.cursorPosition = editor.length;
        }
    }
}
