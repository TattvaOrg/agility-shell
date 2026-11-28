import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

SettingRowTemplate {
    id: root

    property alias customSize: root.labelSize
    property var model: []
    property int currentIndex: 0
    property int comboWidth: 160
    property string fallbackText: "Auto"
    property var iconMap: ({})
    property var textMap: ({})
    property bool searchable: false
    property var _filteredModel: root.model

    signal activated(int index)

    function closePopup() {
        if (internalCombo && internalCombo.popup && internalCombo.popup.visible)
            internalCombo.popup.close();
    }

    onVisibleChanged: {
        if (!visible)
            closePopup();
    }

    ComboBox {
        id: internalCombo

        function updateIndex() {
            if (root.searchable && root.model) {
                let activeStr = root.model[root.currentIndex];
                let idx = root._filteredModel.indexOf(activeStr);
                internalCombo.currentIndex = Math.max(0, idx);
            } else {
                internalCombo.currentIndex = root.currentIndex;
            }
        }

        z: 10
        opacity: root.enabled ? 1 : 0.5
        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
        implicitWidth: Math.max(root.comboWidth, 120)
        implicitHeight: 26
        model: root.searchable ? root._filteredModel : root.model

        onActivated: (index) => {
            if (root.searchable) {
                let selectedItem = root._filteredModel[index];
                let originalIndex = root.model.indexOf(selectedItem);
                if (originalIndex !== -1)
                    root.activated(originalIndex);
            } else {
                root.activated(index);
            }
        }

        Keys.onUpPressed: (event) => { event.accepted = true; }
        Keys.onDownPressed: (event) => { event.accepted = true; }

        Component.onCompleted: {
            internalCombo.updateIndex();
        }

        Connections {
            target: root
            function onCurrentIndexChanged() { Qt.callLater(internalCombo.updateIndex); }
            function onModelChanged() { Qt.callLater(internalCombo.updateIndex); }
            function on_FilteredModelChanged() {
                if (root.searchable)
                    Qt.callLater(internalCombo.updateIndex);
            }
        }

        Connections {
            target: internalCombo
            function onModelChanged() { Qt.callLater(internalCombo.updateIndex); }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        // macOS PopUpButton Double Chevrons Indicator (⌃⌄)
        indicator: Item {
            x: internalCombo.width - width - 8
            y: (internalCombo.height - height) / 2
            width: 10
            height: 16

            SvgIcon {
                anchors.centerIn: parent
                icon: "mac-double-chevron"
                iconSize: 13
                flat: true
                iconColor: internalCombo.popup.visible ? "#007AFF" : (Theme.isDark ? "#8E8E93" : "#636366")

                Behavior on iconColor {
                    ColorAnimation { duration: Constants.animFast }
                }
            }
        }

        // Selected Text Display
        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 24
            spacing: 6

            ThemedText {
                Layout.fillWidth: true
                text: {
                    let txt = root.searchable && root.model ? root.model[root.currentIndex] : internalCombo.displayText;
                    if (!txt)
                        return root.fallbackText;

                    if (root.textMap && typeof txt === "string" && root.textMap[txt] !== undefined)
                        return root.textMap[txt];

                    return txt.split('-').map((word) => {
                        return word.charAt(0).toUpperCase() + word.slice(1);
                    }).join('-');
                }
                font.weight: Font.Medium
                customSize: 12
                color: Theme.isDark ? "#FFFFFF" : "#1D1D1F"
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }

        // macOS PopUpButton Background
        background: Rectangle {
            radius: 5
            color: {
                if (internalCombo.down || internalCombo.popup.visible)
                    return Theme.isDark ? "#3A3A3C" : "#EBEBEF";
                if (internalCombo.hovered)
                    return Theme.isDark ? "#323234" : "#F5F5F7";
                return Theme.isDark ? "#2C2C2E" : "#FFFFFF";
            }
            border.width: 1
            border.color: internalCombo.popup.visible
                ? "#007AFF"
                : (Theme.isDark ? "#3A3A3C" : "#D1D1D6")

            Behavior on color {
                ColorAnimation { duration: Constants.animFast }
            }
            Behavior on border.color {
                ColorAnimation { duration: Constants.animFast }
            }
        }

        // macOS Menu Popup Window
        popup: Popup {
            width: Math.max(internalCombo.width, 160)
            implicitHeight: Math.min(contentItem.implicitHeight + (padding * 2), 240)
            padding: 4
            y: internalCombo.height + 4

            onAboutToShow: {
                if (root.searchable) {
                    popupSearchInput.text = "";
                    popupSearchInput.forceActiveFocus();
                }
                popupListView.updateCurrentIndex();
            }
            onClosed: {
                if (root.searchable)
                    root._filteredModel = root.model;
            }
            transformOrigin: Item.Top

            enter: Transition {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 100 }
                NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 120; easing.type: Easing.OutCubic }
            }

            exit: Transition {
                NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 }
            }

            contentItem: ColumnLayout {
                spacing: 4

                TextField {
                    id: popupSearchInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 24
                    leftPadding: 8
                    rightPadding: 8
                    visible: root.searchable
                    placeholderText: "Search..."
                    font.pixelSize: 11
                    color: Theme.fg
                    selectionColor: "#007AFF"
                    selectedTextColor: "#FFFFFF"
                    onTextEdited: {
                        if (root.searchable) {
                            let query = text.toLowerCase();
                            if (query === "")
                                root._filteredModel = root.model;
                            else
                                root._filteredModel = root.model.filter((item) => {
                                    return typeof item === "string" && item.toLowerCase().includes(query);
                                });
                            popupListView.currentIndex = 0;
                        }
                    }
                    Keys.onUpPressed: (event) => {
                        if (popupListView.currentIndex > 0)
                            popupListView.currentIndex--;
                        event.accepted = true;
                    }
                    Keys.onDownPressed: (event) => {
                        if (popupListView.currentIndex < popupListView.count - 1)
                            popupListView.currentIndex++;
                        event.accepted = true;
                    }
                    Keys.onReturnPressed: (event) => {
                        if (popupListView.currentIndex >= 0 && popupListView.currentIndex < root._filteredModel.length) {
                            let selectedItem = root._filteredModel[popupListView.currentIndex];
                            let originalIndex = root.model.indexOf(selectedItem);
                            if (originalIndex !== -1)
                                root.activated(originalIndex);
                            internalCombo.popup.close();
                        }
                        event.accepted = true;
                    }

                    background: Rectangle {
                        color: Theme.isDark ? "#1E1E1E" : "#EBEBEF"
                        radius: 4
                    }
                }

                ListView {
                    id: popupListView

                    function updateCurrentIndex() {
                        if (root.searchable && root._filteredModel) {
                            let activeStr = root.model[root.currentIndex];
                            let idx = root._filteredModel.indexOf(activeStr);
                            popupListView.currentIndex = idx !== -1 ? idx : 0;
                        } else {
                            popupListView.currentIndex = internalCombo.currentIndex;
                        }
                    }

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: contentHeight
                    clip: true
                    spacing: 1
                    model: internalCombo.delegateModel

                    ScrollIndicator.vertical: ScrollIndicator {}
                }
            }

            background: Rectangle {
                color: Theme.isDark ? "#282828" : "#F6F6F6"
                border.width: 1
                border.color: Theme.isDark ? "#3E3E42" : "#D1D1D6"
                radius: 6

                layer.enabled: true
                layer.effect: DropShadow {
                    transparentBorder: true
                    color: "#00000030"
                    radius: 8
                    samples: 17
                    verticalOffset: 3
                }
            }
        }

        // macOS Menu Item Delegate
        delegate: ItemDelegate {
            id: delegateItem

            width: ListView.view.width
            height: 24

            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }

            readonly property bool isSelected: popupListView.currentIndex === index
            readonly property bool isHoveredOrActive: delegateItem.hovered || delegateItem.down

            background: Rectangle {
                anchors.fill: parent
                anchors.leftMargin: 2
                anchors.rightMargin: 2
                radius: 4
                color: delegateItem.isHoveredOrActive ? "#007AFF" : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 60 }
                }
            }

            contentItem: RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 8
                spacing: 4

                // macOS Checkmark indicator on selected item
                Item {
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 14

                    SvgIcon {
                        anchors.centerIn: parent
                        icon: "mac-check"
                        iconSize: 10
                        flat: true
                        visible: delegateItem.isSelected
                        iconColor: delegateItem.isHoveredOrActive ? "#FFFFFF" : (Theme.isDark ? "#FFFFFF" : "#007AFF")
                    }
                }

                ThemedText {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: {
                        if (typeof modelData !== "string")
                            return "";

                        if (root.textMap && root.textMap[modelData] !== undefined)
                            return root.textMap[modelData];

                        return modelData.split('-').map((word) => {
                            return word.charAt(0).toUpperCase() + word.slice(1);
                        }).join('-');
                    }
                    font.weight: delegateItem.isSelected ? Font.Medium : Font.Normal
                    customSize: 12
                    color: delegateItem.isHoveredOrActive ? "#FFFFFF" : Theme.fg
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }
        }
    }
}
