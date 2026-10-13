import QtQuick
import ".."
import "../components"

Item {
    id: root

    implicitHeight: 36
    implicitWidth: chipRow.implicitWidth

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: chipRow.implicitWidth
        contentHeight: parent.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick
        clip: true

        Row {
            id: chipRow
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: LauncherService.categoryList

                GlassPill {
                    id: pill
                    text: modelData.name
                    iconSource: modelData.icon
                    pillHeight: 30
                    active: LauncherService.selectedCategory === modelData.id
                    activeColor: Theme.colAccent

                    onClicked: {
                        LauncherService.setCategory(modelData.id)
                    }
                }
            }
        }
    }
}
