import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core
import qs.Core.Services
import "."
import "End" as EndSuite

Item {
    id: root

    readonly property bool isAweActive: SettingsService.desktopWidgetProvider !== "end"
    readonly property bool isEndActive: SettingsService.desktopWidgetProvider === "end"

    // Automatically seed ~/.config/quickshell/widget_settings.json from default template if missing
    Process {
        id: initConfigProc
        command: ["bash", "-c", "if [ ! -f ~/.config/quickshell/widget_settings.json ]; then mkdir -p ~/.config/quickshell && cp '" + Quickshell.shellDir + "/Modules/DesktopWidgets/default_widget_settings.json' ~/.config/quickshell/widget_settings.json; fi"]
        Component.onCompleted: running = true
    }

    // ─── Awe Widgets Surface (existing behavior preserved intact) ───
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: desktopWindow
            required property var modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:desktop-widgets"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            focusable: false
            visible: SettingsService.settingsLoaded
                && SettingsService.desktopWidgetsEnabled
                && root.isAweActive
                && !DisplayProfileService.gameModeActive

            mask: Region {
                Region { item: widgetManager.visible ? widgetManager : null }
                Region { item: aweEditBanner.visible ? aweEditBanner : null }
                Region { item: clockWidget.visible ? clockWidget : null }
                Region { item: sysinfoWidget.visible ? sysinfoWidget : null }
                Region { item: calendarWidget.visible ? calendarWidget : null }
                Region { item: mediaWidget.visible ? mediaWidget : null }
                Region { item: weatherWidget.visible ? weatherWidget : null }
                Region { item: posterWidget.visible ? posterWidget : null }
                Region { item: batteryWidget.visible ? batteryWidget : null }
                Region { item: volumeWidget.visible ? volumeWidget : null }
                Region { item: networkWidget.visible ? networkWidget : null }
                Region { item: notesWidget.visible ? notesWidget : null }
                Region { item: todoWidget.visible ? todoWidget : null }
                Region { item: timerWidget.visible ? timerWidget : null }
                Region { item: thermalWidget.visible ? thermalWidget : null }
                Region { item: quoteWidget.visible ? quoteWidget : null }
                Region { item: clipboardWidget.visible ? clipboardWidget : null }
                Region { item: cryptoWidget.visible ? cryptoWidget : null }
                Region { item: worldclockWidget.visible ? worldclockWidget : null }
                Region { item: gitWidget.visible ? gitWidget : null }
                Region { item: resourcewheelWidget.visible ? resourcewheelWidget : null }
                Region { item: visualizerWidget.visible ? visualizerWidget : null }
                Region { item: habitsWidget.visible ? habitsWidget : null }
                Region { item: pingWidget.visible ? pingWidget : null }
                Region { item: storagemapWidget.visible ? storagemapWidget : null }
                Region { item: calcWidget.visible ? calcWidget : null }
            }

            Item {
                id: widgetsLayer
                anchors.fill: parent

                WidgetManager {
                    id: widgetManager
                    visible: SettingsService.widgetManagerNotchEnabled
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                // Floating Edit Mode finish pill when editing Awe layout
                Rectangle {
                    id: aweEditBanner
                    visible: SettingsService.desktopWidgetsEditMode && root.isAweActive
                    z: 1000
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    width: aweEditRow.implicitWidth + 24
                    height: 40
                    radius: 20
                    color: Qt.rgba(Theme.colBg.r, Theme.colBg.g, Theme.colBg.b, 0.92)
                    border.width: 1
                    border.color: Theme.colAccent

                    RowLayout {
                        id: aweEditRow
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            text: "Awe Edit Mode • Drag widgets or scroll to scale"
                            color: Theme.colTextPrimary
                            font.family: SettingsService.fontFamily
                            font.pixelSize: 12
                        }

                        Rectangle {
                            implicitWidth: aweDoneTxt.implicitWidth + 16
                            implicitHeight: 26
                            radius: 13
                            color: Theme.colAccent

                            Text {
                                id: aweDoneTxt
                                anchors.centerIn: parent
                                text: "Done"
                                color: "#000000"
                                font.family: SettingsService.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.Bold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: SettingsService.desktopWidgetsEditMode = false
                            }
                        }
                    }
                }

                Clock {
                    id: clockWidget
                    visible: widgetManager.widgetVisibility["clock"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                SystemInfo {
                    id: sysinfoWidget
                    visible: widgetManager.widgetVisibility["sysinfo"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                CalendarWidget {
                    id: calendarWidget
                    visible: widgetManager.widgetVisibility["calendar"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                MediaWidget {
                    id: mediaWidget
                    visible: widgetManager.widgetVisibility["media"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                WeatherWidget {
                    id: weatherWidget
                    visible: widgetManager.widgetVisibility["weather"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                PosterWidget {
                    id: posterWidget
                    visible: widgetManager.widgetVisibility["poster"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                BatteryWidget {
                    id: batteryWidget
                    visible: widgetManager.widgetVisibility["battery"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                VolumeBrightnessWidget {
                    id: volumeWidget
                    visible: widgetManager.widgetVisibility["quickcontrols"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                NetworkWidget {
                    id: networkWidget
                    visible: widgetManager.widgetVisibility["network"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                NotesWidget {
                    id: notesWidget
                    visible: widgetManager.widgetVisibility["notes"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                TodoWidget {
                    id: todoWidget
                    visible: widgetManager.widgetVisibility["todo"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                TimerWidget {
                    id: timerWidget
                    visible: widgetManager.widgetVisibility["timer"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                ThermalWidget {
                    id: thermalWidget
                    visible: widgetManager.widgetVisibility["thermal"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                QuoteWidget {
                    id: quoteWidget
                    visible: widgetManager.widgetVisibility["quote"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                ClipboardWidget {
                    id: clipboardWidget
                    visible: widgetManager.widgetVisibility["clipboard"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                CryptoWidget {
                    id: cryptoWidget
                    visible: widgetManager.widgetVisibility["crypto"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                WorldClockWidget {
                    id: worldclockWidget
                    visible: widgetManager.widgetVisibility["worldclock"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                GitDashboardWidget {
                    id: gitWidget
                    visible: widgetManager.widgetVisibility["git"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                ResourceWheelWidget {
                    id: resourcewheelWidget
                    visible: widgetManager.widgetVisibility["resourcewheel"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                VisualizerWidget {
                    id: visualizerWidget
                    visible: widgetManager.widgetVisibility["visualizer"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                HabitsWidget {
                    id: habitsWidget
                    visible: widgetManager.widgetVisibility["habits"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                PingWidget {
                    id: pingWidget
                    visible: widgetManager.widgetVisibility["ping"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                StorageMapWidget {
                    id: storagemapWidget
                    visible: widgetManager.widgetVisibility["storagemap"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }

                CalcWidget {
                    id: calcWidget
                    visible: widgetManager.widgetVisibility["calc"] !== false
                    screenWidth: desktopWindow.width
                    screenHeight: desktopWindow.height
                }
            }
        }
    }

    // ─── End Widgets Surface (rendered exclusively when provider === "end") ───
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: endDesktopWindow
            required property var modelData
            screen: modelData

            readonly property bool widgetsWanted: SettingsService.settingsLoaded
                && SettingsService.desktopWidgetsEnabled
                && root.isEndActive
                && !DisplayProfileService.gameModeActive

            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell:end-widgets"
            WlrLayershell.keyboardFocus: (SettingsService.desktopWidgetsEditMode || endLoader.anyTextFocused)
                ? WlrKeyboardFocus.OnDemand
                : WlrKeyboardFocus.None
            WlrLayershell.exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            focusable: SettingsService.desktopWidgetsEditMode || endLoader.anyTextFocused
            visible: SettingsService.settingsLoaded
                && root.isEndActive
                && !DisplayProfileService.gameModeActive
                && endLoader.isShowing

            // Empty desktop passes clicks through when locked; full canvas active in Edit Mode
            mask: Region {
                Region { item: endCanvas.editMode ? endCanvas : null }
                Region { item: !endCanvas.editMode && endLoader.clockItem.visible ? endLoader.clockItem : null }
                Region { item: !endCanvas.editMode && endLoader.userCardItem.visible ? endLoader.userCardItem : null }
                Region { item: !endCanvas.editMode && endLoader.calendarItem.visible ? endLoader.calendarItem : null }
                Region { item: !endCanvas.editMode && endLoader.weatherItem.visible ? endLoader.weatherItem : null }
                Region { item: !endCanvas.editMode && endLoader.resourcesItem.visible ? endLoader.resourcesItem : null }
                Region { item: !endCanvas.editMode && endLoader.todoItem.visible ? endLoader.todoItem : null }
                Region { item: !endCanvas.editMode && endLoader.worldClockItem.visible ? endLoader.worldClockItem : null }
                Region { item: !endCanvas.editMode && endLoader.timersItem.visible ? endLoader.timersItem : null }
                Region { item: !endCanvas.editMode && endLoader.notesItem.visible ? endLoader.notesItem : null }
                Region { item: !endCanvas.editMode && endLoader.mediaItem.visible ? endLoader.mediaItem : null }
                Region { item: !endCanvas.editMode && endLoader.imagesItem.visible ? endLoader.imagesItem : null }
                Region { item: !endCanvas.editMode && endLoader.imageCardItem.visible ? endLoader.imageCardItem : null }
                Region { item: !endCanvas.editMode && endLoader.customImageItem.visible ? endLoader.customImageItem : null }
                Region { item: !endCanvas.editMode && endLoader.stickerItem.visible ? endLoader.stickerItem : null }
                Region { item: !endCanvas.editMode && endLoader.customTextItem.visible ? endLoader.customTextItem : null }
            }

            EndSuite.EndWidgetCanvas {
                id: endCanvas
                anchors.fill: parent
                screen: endDesktopWindow.modelData

                EndSuite.EndWidgetsLoader {
                    id: endLoader
                    screen: endDesktopWindow.modelData
                    canvas: endCanvas
                    widgetsWanted: endDesktopWindow.widgetsWanted
                }
            }
        }
    }
}
