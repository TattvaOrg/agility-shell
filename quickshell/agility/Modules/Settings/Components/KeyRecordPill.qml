import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

FocusScope {
    id: root

    property string keyText: ""
    property string placeholder: "Click to record shortcut"
    property bool isRecording: false

    signal keyRecorded(string key)
    signal cleared()

    implicitHeight: 34
    implicitWidth: Math.max(160, contentRow.implicitWidth + Constants.sizeSm * 2)
    Layout.preferredHeight: implicitHeight
    Layout.preferredWidth: implicitWidth

    function formatKeyEvent(event) {
        let k = event.key;

        // Cancel on escape with no modifiers
        if (k === Qt.Key_Escape && event.modifiers === 0) {
            return "CANCEL";
        }

        // Standalone modifiers - keep waiting
        if (k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Shift ||
            k === Qt.Key_Meta || k === Qt.Key_Super_L || k === Qt.Key_Super_R ||
            k === Qt.Key_AltGr || k === Qt.Key_Hyper_L || k === Qt.Key_Hyper_R) {
            return "";
        }

        let parts = [];
        if (event.modifiers & Qt.MetaModifier) parts.push("Mod");
        if (event.modifiers & Qt.ControlModifier) parts.push("Ctrl");
        if (event.modifiers & Qt.AltModifier) parts.push("Alt");
        if (event.modifiers & Qt.ShiftModifier) parts.push("Shift");

        let keyName = "";
        if (k >= Qt.Key_A && k <= Qt.Key_Z) {
            keyName = String.fromCharCode(k);
        } else if (k >= Qt.Key_0 && k <= Qt.Key_9) {
            keyName = String.fromCharCode(k);
        } else {
            switch (k) {
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    keyName = "Return"; break;
                case Qt.Key_Space:
                    keyName = "Space"; break;
                case Qt.Key_Tab:
                case Qt.Key_Backtab:
                    keyName = "Tab"; break;
                case Qt.Key_Backspace:
                    keyName = "Backspace"; break;
                case Qt.Key_Delete:
                    keyName = "Delete"; break;
                case Qt.Key_Insert:
                    keyName = "Insert"; break;
                case Qt.Key_Home:
                    keyName = "Home"; break;
                case Qt.Key_End:
                    keyName = "End"; break;
                case Qt.Key_PageUp:
                    keyName = "Page_Up"; break;
                case Qt.Key_PageDown:
                    keyName = "Page_Down"; break;
                case Qt.Key_Up:
                    keyName = "Up"; break;
                case Qt.Key_Down:
                    keyName = "Down"; break;
                case Qt.Key_Left:
                    keyName = "Left"; break;
                case Qt.Key_Right:
                    keyName = "Right"; break;
                case Qt.Key_Escape:
                    keyName = "Escape"; break;
                case Qt.Key_Print:
                    keyName = "Print"; break;
                case Qt.Key_Minus:
                    keyName = "minus"; break;
                case Qt.Key_Equal:
                    keyName = "equal"; break;
                case Qt.Key_BracketLeft:
                    keyName = "bracketleft"; break;
                case Qt.Key_BracketRight:
                    keyName = "bracketright"; break;
                case Qt.Key_Semicolon:
                    keyName = "semicolon"; break;
                case Qt.Key_Apostrophe:
                    keyName = "apostrophe"; break;
                case Qt.Key_QuoteLeft:
                    keyName = "grave"; break;
                case Qt.Key_Backslash:
                    keyName = "backslash"; break;
                case Qt.Key_Comma:
                    keyName = "comma"; break;
                case Qt.Key_Period:
                    keyName = "period"; break;
                case Qt.Key_Slash:
                    keyName = "slash"; break;
                case Qt.Key_F1: keyName = "F1"; break;
                case Qt.Key_F2: keyName = "F2"; break;
                case Qt.Key_F3: keyName = "F3"; break;
                case Qt.Key_F4: keyName = "F4"; break;
                case Qt.Key_F5: keyName = "F5"; break;
                case Qt.Key_F6: keyName = "F6"; break;
                case Qt.Key_F7: keyName = "F7"; break;
                case Qt.Key_F8: keyName = "F8"; break;
                case Qt.Key_F9: keyName = "F9"; break;
                case Qt.Key_F10: keyName = "F10"; break;
                case Qt.Key_F11: keyName = "F11"; break;
                case Qt.Key_F12: keyName = "F12"; break;
                default:
                    if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 33 && event.text.charCodeAt(0) <= 126) {
                        keyName = event.text.toUpperCase();
                    } else {
                        keyName = "";
                    }
                    break;
            }
        }

        if (!keyName) return "";
        parts.push(keyName);
        return parts.join("+");
    }

    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Constants.sizeXs
        color: root.isRecording ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14) : (mouseArea.containsMouse ? Theme.bgSecondary : (Theme.isDark ? Theme.bgSecondary : Theme.bg))
        border.color: root.isRecording ? Theme.accent : (mouseArea.containsMouse ? Theme.accent : Theme.border)
        border.width: root.isRecording ? 1.5 : 1

        Behavior on color {
            ColorAnimation { duration: Constants.animFast }
        }
        Behavior on border.color {
            ColorAnimation { duration: Constants.animFast }
        }

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Constants.sizeXs

            SvgIcon {
                icon: root.isRecording ? "record-icon" : "keyboard"
                iconSize: Constants.sizeSm
                iconColor: root.isRecording ? Theme.accent : (root.keyText !== "" ? Theme.accent : Theme.muted)
                flat: true
                Layout.alignment: Qt.AlignVCenter

                SequentialAnimation on opacity {
                    running: root.isRecording
                    loops: Animation.Infinite
                    PropertyAnimation { to: 0.3; duration: 500; easing.type: Easing.InOutQuad }
                    PropertyAnimation { to: 1.0; duration: 500; easing.type: Easing.InOutQuad }
                }
            }

            ThemedText {
                text: {
                    if (root.isRecording)
                        return "Press keys... (Esc to cancel)";
                    if (root.keyText !== "")
                        return root.keyText;
                    return root.placeholder;
                }
                font.family: Constants.fontFamily
                font.pixelSize: Math.round(11 * SettingsService.fontScale)
                font.bold: root.isRecording || root.keyText !== ""
                color: root.isRecording ? Theme.accent : (root.keyText !== "" ? Theme.accent : Theme.muted)
                Layout.alignment: Qt.AlignVCenter
            }

            SvgIconButton {
                icon: "x"
                visible: !root.isRecording && root.keyText !== ""
                iconSize: 12
                iconColor: Theme.muted
                hoverColor: Theme.danger
                flat: true
                padding: 2
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    root.keyText = "";
                    root.cleared();
                    root.keyRecorded("");
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.isRecording = true;
                keyListener.forceActiveFocus();
            }
        }
    }

    Item {
        id: keyListener
        anchors.fill: parent
        focus: true

        Keys.onPressed: (event) => {
            if (!root.isRecording)
                return;

            let res = root.formatKeyEvent(event);
            if (res === "CANCEL") {
                root.isRecording = false;
                event.accepted = true;
                return;
            }
            if (res !== "") {
                root.keyText = res;
                root.isRecording = false;
                root.keyRecorded(res);
                event.accepted = true;
            }
        }

        onActiveFocusChanged: {
            if (!activeFocus && root.isRecording) {
                root.isRecording = false;
            }
        }
    }
}
