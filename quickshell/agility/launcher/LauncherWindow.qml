import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"

PanelWindow {
    id: root

    property var screenModel: null
    screen: screenModel

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:agility-launcher"
    WlrLayershell.keyboardFocus: LauncherService.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: 0

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    visible: LauncherService.isOpen

    // ─── Dimmed Backdrop & Click Outside to Dismiss ───
    Rectangle {
        id: backdropDim
        anchors.fill: parent
        color: Theme.isGlass ? "#55000000" : "#66000000"
        opacity: LauncherService.isOpen ? 1.0 : 0.0

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: LauncherService.close()
        }
    }

    // ─── Centered Spotlight / Dash Modal Card ───
    GlassCard {
        id: modalCard
        width: Math.min(680, parent.width - 32)
        height: Math.min(520, parent.height - 48)
        anchors.centerIn: parent
        radius: 24

        opacity: LauncherService.isOpen ? 1.0 : 0.0
        scale: LauncherService.isOpen ? 1.0 : 0.94
        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.12 }
        }

        // Prevent clicks on modal from closing it
        MouseArea {
            anchors.fill: parent
            z: -1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            // ─── Search Input Bar ───
            GlassCard {
                id: searchBarCard
                width: parent.width
                height: 48
                radius: 16
                isTile: true

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter

                    GlassIcon {
                        source: "magnifying-glass"
                        size: 20
                        color: Theme.colAccent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 70
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.fontMain
                        font.pixelSize: 15
                        color: Theme.colText
                        selectionColor: Theme.colAccent
                        selectedTextColor: "#FFFFFF"
                        clip: true
                        focus: LauncherService.isOpen

                        Text {
                            anchors.fill: parent
                            visible: !searchInput.text && !searchInput.inputMethodComposing
                            text: "Search apps, calc (12*8), or shortcuts (g:, gh:, yt:)..."
                            color: Theme.colTextSec
                            font.family: Theme.fontMain
                            font.pixelSize: 15
                            opacity: 0.65
                        }

                        onTextChanged: {
                            LauncherService.updateSearch(text)
                        }

                        Keys.onPressed: function(event) {
                            if (event.key === Qt.Key_Escape) {
                                LauncherService.close()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab) {
                                LauncherService.selectNext()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab) {
                                LauncherService.selectPrevious()
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                LauncherService.launchSelected()
                                event.accepted = true
                            }
                        }
                    }

                    // Clear button
                    GlassIcon {
                        visible: searchInput.text.length > 0
                        source: "x-circle"
                        size: 18
                        color: Theme.colTextSec
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInput.text = ""
                                searchInput.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            // ─── Category Filter Chips ───
            CategoryChips {
                id: categoryChips
                width: parent.width
            }

            // ─── Special Preview Cards & App Results ───
            Item {
                width: parent.width
                height: parent.height - searchBarCard.height - categoryChips.height - 24

                Column {
                    anchors.fill: parent
                    spacing: 8

                    // 1. Web Search Shortcut Card
                    GlassCard {
                        id: webShortcutCard
                        width: parent.width
                        height: 52
                        radius: 14
                        isTile: true
                        visible: LauncherService.hasWebShortcut

                        property bool isSelected: LauncherService.selectedIndex === 0

                        rimColor: isSelected ? Theme.colAccent : Theme.borderColor
                        rimWidth: isSelected ? 2.0 : 1.0

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter

                            GlassIcon {
                                source: LauncherService.webShortcutIcon
                                size: 22
                                color: Theme.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    text: "Search " + LauncherService.webShortcutEngine + ": \"" + LauncherService.webShortcutQuery + "\""
                                    color: Theme.colText
                                    font.family: Theme.fontMain
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    text: "Press Enter to open in browser"
                                    color: Theme.colTextSec
                                    font.family: Theme.fontMain
                                    font.pixelSize: 11
                                    opacity: 0.75
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LauncherService.openWebUrl(LauncherService.webShortcutUrl)
                                LauncherService.close()
                            }
                        }
                    }

                    // 2. In-line Calculator Evaluation Card
                    GlassCard {
                        id: mathCard
                        width: parent.width
                        height: 52
                        radius: 14
                        isTile: true
                        visible: LauncherService.hasMathResult

                        property int myIndex: LauncherService.hasWebShortcut ? 1 : 0
                        property bool isSelected: LauncherService.selectedIndex === myIndex

                        rimColor: isSelected ? Theme.colAccent : Theme.borderColor
                        rimWidth: isSelected ? 2.0 : 1.0

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 12
                            anchors.verticalCenter: parent.verticalCenter

                            GlassIcon {
                                source: "calculator"
                                size: 22
                                color: Theme.colAccent
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Row {
                                    spacing: 8
                                    Text {
                                        text: LauncherService.mathExpression
                                        color: Theme.colTextSec
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                    }
                                    Text {
                                        text: "= " + LauncherService.mathResult
                                        color: Theme.colAccent
                                        font.family: Theme.fontMono
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                }

                                Text {
                                    text: "Press Enter to copy result to clipboard"
                                    color: Theme.colTextSec
                                    font.family: Theme.fontMain
                                    font.pixelSize: 10
                                    opacity: 0.75
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                LauncherService.copyToClipboard(LauncherService.mathResult)
                                LauncherService.close()
                            }
                        }
                    }

                    // 3. Search Results or Pinned Favorites List
                    ListView {
                        id: resultsListView
                        width: parent.width
                        height: parent.height - (webShortcutCard.visible ? webShortcutCard.height + 8 : 0) - (mathCard.visible ? mathCard.height + 8 : 0)
                        clip: true
                        spacing: 6
                        boundsBehavior: Flickable.StopAtBounds

                        model: LauncherService.searchResults

                        delegate: GlassCard {
                            id: appItemCard
                            width: resultsListView.width
                            height: 48
                            radius: 12
                            isTile: true

                            property int actualIndex: index + (LauncherService.hasWebShortcut ? 1 : 0) + (LauncherService.hasMathResult ? 1 : 0)
                            property bool isSelected: LauncherService.selectedIndex === actualIndex

                            rimColor: isSelected ? Theme.colAccent : (mouseArea.containsMouse ? "#30FFFFFF" : Theme.borderColor)
                            rimWidth: isSelected ? 2.0 : 1.0

                            dropletColorTop: isSelected ? Qt.rgba(Theme.colAccent.r, Theme.colAccent.g, Theme.colAccent.b, 0.20) : (mouseArea.containsMouse ? "#2AFFFFFF" : dropletColorTop)

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12
                                anchors.verticalCenter: parent.verticalCenter

                                GlassIcon {
                                    source: (modelData.app && (modelData.app.resolved_icon || modelData.app.icon)) ? (modelData.app.resolved_icon || modelData.app.icon) : "application-x-executable"
                                    size: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 90
                                    spacing: 2

                                    Text {
                                        text: (modelData.app && modelData.app.name) ? modelData.app.name : ""
                                        color: isSelected ? Theme.colAccent : Theme.colText
                                        font.family: Theme.fontMain
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: parent.width
                                    }

                                    Text {
                                        text: (modelData.app && (modelData.app.generic_name || modelData.app.comment || modelData.app.exec)) ? (modelData.app.generic_name || modelData.app.comment || modelData.app.exec) : ""
                                        color: Theme.colTextSec
                                        font.family: Theme.fontMain
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        opacity: 0.7
                                        width: parent.width
                                    }
                                }

                                GlassPill {
                                    visible: isSelected
                                    text: "Launch"
                                    pillHeight: 24
                                    active: true
                                    activeColor: Theme.colAccent
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: mouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.app) {
                                        LauncherService.launchApp(modelData.app)
                                    }
                                }
                            }
                        }

                        // Empty State Placeholder
                        Item {
                            anchors.fill: parent
                            visible: LauncherService.searchResults.length === 0 && !LauncherService.hasMathResult && !LauncherService.hasWebShortcut

                            Column {
                                anchors.centerIn: parent
                                spacing: 8

                                GlassIcon {
                                    source: "magnifying-glass"
                                    size: 36
                                    color: Theme.colTextSec
                                    opacity: 0.4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }

                                Text {
                                    text: LauncherService.searchQuery === "" ? "No applications found" : "No results for \"" + LauncherService.searchQuery + "\""
                                    color: Theme.colTextSec
                                    font.family: Theme.fontMain
                                    font.pixelSize: 13
                                    opacity: 0.75
                                    anchors.horizontalCenter: parent.horizontalCenter
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Force focus onto text input when modal opens
    Connections {
        target: LauncherService
        function onIsOpenChanged() {
            if (LauncherService.isOpen) {
                searchInput.text = ""
                searchInput.forceActiveFocus()
            }
        }
    }
}
