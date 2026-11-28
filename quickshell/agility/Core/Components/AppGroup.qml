import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Components
import qs.Core.Services

ColumnLayout {
    id: root

    property string title: ""
    property string icon: ""
    property string badge: ""
    property bool showDividers: true
    default property alias groupContent: contentLayout.data

    Layout.fillWidth: true
    spacing: 6

    // Section Header outside the inset card (macOS System Settings standard)
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 12
        Layout.rightMargin: 12
        spacing: 6
        visible: root.title !== ""

        ThemedText {
            text: root.title.toUpperCase()
            customSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 0.8
            color: Theme.muted
            Layout.fillWidth: true
        }

        ThemedText {
            visible: root.badge !== ""
            text: root.badge
            customSize: 10
            color: Theme.muted
        }
    }

    // Inset Grouped Card Container
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: contentLayout.implicitHeight + 22
        radius: 10
        color: Theme.isDark ? "#28282A" : "#FFFFFF"
        border.width: 1
        border.color: Theme.isDark ? "#38383A" : "#E5E5EA"

        Item {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 10
            anchors.bottomMargin: 10

            ColumnLayout {
                id: contentLayout

                anchors.fill: parent
                spacing: 10
            }

            // Hairline dividers between rows
            Repeater {
                model: contentLayout.children.length

                Rectangle {
                    property var targetChild: contentLayout.children[index]

                    height: 1
                    color: Theme.isDark ? "#38383A" : "#E5E5EA"
                    x: 0
                    width: parent.width
                    y: targetChild ? targetChild.y + targetChild.height + 4.5 : 0
                    visible: {
                        if (!root.showDividers)
                            return false;

                        if (!targetChild || !targetChild.visible || ('delegate' in targetChild && 'model' in targetChild))
                            return false;

                        for (let i = index + 1; i < contentLayout.children.length; i++) {
                            let c = contentLayout.children[i];
                            if (c.visible && !('delegate' in c && 'model' in c))
                                return true;
                        }
                        return false;
                    }
                }
            }
        }
    }
}
