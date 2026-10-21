import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Core
import qs.Core.Components
import qs.Core.Services

Item {
    id: root

    readonly property bool isCardOpen: AppState.isWidgetOpen("weather")
    property bool isHovered: mouseArea.containsMouse
    property bool isPressed: mouseArea.pressed
    readonly property bool enabledInSettings: SettingsService.appletWeather

    implicitHeight: SettingsService.barWidgetHeight
    height: parent && parent.height > 0 ? parent.height : implicitHeight
    implicitWidth: enabledInSettings ? (contentPill.implicitWidth) : 0
    width: implicitWidth
    opacity: enabledInSettings ? 1 : 0
    visible: enabledInSettings || opacity > 0.001

    Behavior on width {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Constants.animFast
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        id: contentPill
        anchors.fill: parent
        radius: height / 2
        color: root.isCardOpen ? Theme.barBgSecondary : (root.isHovered ? Theme.barBgSecondary : "transparent")
        border.color: root.isCardOpen ? Theme.accent : (root.isHovered ? Theme.barBorder : "transparent")
        border.width: 1
        scale: root.isPressed ? 0.96 : (root.isHovered ? 1.02 : 1)

        Behavior on color {
            ColorAnimation {
                duration: Constants.animFast
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Constants.animFast
                easing.type: Easing.OutQuad
            }
        }

        Timer {
            id: hoverTimer

            interval: 160
            repeat: false
            onTriggered: {
                if (SettingsService.barOpenOnHover && root.isHovered && !root.isCardOpen) {
                    AppState.openWidget("weather");
                }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                if (SettingsService.barOpenOnHover)
                    hoverTimer.restart();
            }
            onExited: {
                hoverTimer.stop();
            }
            onClicked: {
                hoverTimer.stop();
                AppState.toggleWidget("weather");
            }
        }

        RowLayout {
            anchors.centerIn: parent
            anchors.leftMargin: Constants.sizeSm
            anchors.rightMargin: Constants.sizeSm
            spacing: Constants.size2Xs

            SvgIcon {
                icon: WeatherService.conditionIcon
                iconSize: 14
                flat: true
                iconColor: (root.isCardOpen || root.isHovered) ? Theme.accent : Theme.barFg
                Layout.alignment: Qt.AlignVCenter

                Behavior on iconColor {
                    ColorAnimation {
                        duration: Constants.animFast
                    }
                }
            }

            ThemedText {
                text: WeatherService.displayTemp
                customSize: 11
                font.weight: Font.Medium
                color: (root.isCardOpen || root.isHovered) ? Theme.barFg : Theme.barMuted
                Layout.alignment: Qt.AlignVCenter

                Behavior on color {
                    ColorAnimation {
                        duration: Constants.animFast
                    }
                }
            }
        }
    }

    // Floating 3-Day Weather Card Popout
    WeatherCard {
        id: weatherCard
        anchors.top: root.bottom
        anchors.topMargin: Constants.sizeSm
        anchors.horizontalCenter: root.horizontalCenter
        isOpen: root.isCardOpen
        onCloseRequested: root.isCardOpen = false
    }
}
