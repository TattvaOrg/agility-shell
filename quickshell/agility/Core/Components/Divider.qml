import QtQuick
import QtQuick.Layouts
import qs.Core
import qs.Core.Services

Rectangle {
    id: root

    property bool vertical: false

    color: Theme.border
    implicitWidth: vertical ? 1 : 0
    implicitHeight: vertical ? 0 : 1
    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    Layout.preferredHeight: visible ? implicitHeight : 0
    Layout.preferredWidth: visible ? implicitWidth : 0
    Layout.topMargin: visible ? undefined : 0
    Layout.bottomMargin: visible ? undefined : 0
    Layout.leftMargin: visible ? undefined : 0
    Layout.rightMargin: visible ? undefined : 0
}
