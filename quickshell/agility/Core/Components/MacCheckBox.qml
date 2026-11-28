import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Services

Item {
    id: root

    property bool checked: false
    property bool enabled: true
    property string text: ""
    property int checkSize: 16

    signal toggled(bool checked)

    implicitWidth: root.text !== "" ? (box.width + labelText.implicitWidth + 8) : box.width
    implicitHeight: Math.max(box.height, root.text !== "" ? labelText.implicitHeight : 0)
    opacity: root.enabled ? 1.0 : 0.45

    RowLayout {
        anchors.fill: parent
        spacing: 8

        Rectangle {
            id: box
            Layout.preferredWidth: root.checkSize
            Layout.preferredHeight: root.checkSize
            radius: 4

            // macOS Checkbox styling: Apple System Blue (#007AFF) when checked
            color: root.checked ? "#007AFF" : (Theme.isDark ? Qt.rgba(1, 1, 1, 0.08) : "#FFFFFF")
            border.width: 1
            border.color: root.checked
                ? "#007AFF"
                : (mouseArea.containsMouse ? (Theme.isDark ? "#8E8E93" : "#8E8E93") : (Theme.isDark ? "#545458" : "#C7C7CC"))

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            Behavior on border.color {
                ColorAnimation { duration: 120 }
            }

            SvgIcon {
                anchors.centerIn: parent
                icon: "mac-check"
                iconSize: 10
                iconColor: "#FFFFFF"
                flat: true
                visible: root.checked
                scale: root.checked ? 1.0 : 0.5
                opacity: root.checked ? 1.0 : 0.0

                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutBack }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        ThemedText {
            id: labelText
            visible: root.text !== ""
            text: root.text
            customSize: 12
            color: root.enabled ? Theme.fg : Theme.muted
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: root.enabled
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
