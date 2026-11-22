import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Core.Services
import "."

Item {
    id: root

    // Automatically seed ~/.config/quickshell/widget_settings.json from default template if missing
    Process {
        id: initConfigProc
        command: ["bash", "-c", "if [ ! -f ~/.config/quickshell/widget_settings.json ]; then mkdir -p ~/.config/quickshell && cp '" + Quickshell.shellDir + "/Modules/DesktopWidgets/default_widget_settings.json' ~/.config/quickshell/widget_settings.json; fi"]
        Component.onCompleted: running = true
    }

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
            visible: SettingsService.settingsLoaded && SettingsService.desktopWidgetsEnabled
            readonly property real safeScreenWidth: (desktopWindow.width > 100) ? desktopWindow.width : (desktopWindow.screen ? desktopWindow.screen.width : 1366)
            readonly property real safeScreenHeight: (desktopWindow.height > 100) ? desktopWindow.height : (desktopWindow.screen ? desktopWindow.screen.height : 768)

            mask: Region {
                Region { item: widgetManager.visible ? widgetManager : null }
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
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                Clock {
                    id: clockWidget
                    visible: widgetManager.widgetVisibility["clock"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                SystemInfo {
                    id: sysinfoWidget
                    visible: widgetManager.widgetVisibility["sysinfo"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                CalendarWidget {
                    id: calendarWidget
                    visible: widgetManager.widgetVisibility["calendar"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                MediaWidget {
                    id: mediaWidget
                    visible: widgetManager.widgetVisibility["media"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                WeatherWidget {
                    id: weatherWidget
                    visible: widgetManager.widgetVisibility["weather"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                PosterWidget {
                    id: posterWidget
                    visible: widgetManager.widgetVisibility["poster"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                BatteryWidget {
                    id: batteryWidget
                    visible: widgetManager.widgetVisibility["battery"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                VolumeBrightnessWidget {
                    id: volumeWidget
                    visible: widgetManager.widgetVisibility["quickcontrols"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                NetworkWidget {
                    id: networkWidget
                    visible: widgetManager.widgetVisibility["network"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                NotesWidget {
                    id: notesWidget
                    visible: widgetManager.widgetVisibility["notes"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                TodoWidget {
                    id: todoWidget
                    visible: widgetManager.widgetVisibility["todo"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                TimerWidget {
                    id: timerWidget
                    visible: widgetManager.widgetVisibility["timer"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                ThermalWidget {
                    id: thermalWidget
                    visible: widgetManager.widgetVisibility["thermal"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                QuoteWidget {
                    id: quoteWidget
                    visible: widgetManager.widgetVisibility["quote"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                ClipboardWidget {
                    id: clipboardWidget
                    visible: widgetManager.widgetVisibility["clipboard"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                CryptoWidget {
                    id: cryptoWidget
                    visible: widgetManager.widgetVisibility["crypto"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                WorldClockWidget {
                    id: worldclockWidget
                    visible: widgetManager.widgetVisibility["worldclock"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                GitDashboardWidget {
                    id: gitWidget
                    visible: widgetManager.widgetVisibility["git"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                ResourceWheelWidget {
                    id: resourcewheelWidget
                    visible: widgetManager.widgetVisibility["resourcewheel"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                VisualizerWidget {
                    id: visualizerWidget
                    visible: widgetManager.widgetVisibility["visualizer"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                HabitsWidget {
                    id: habitsWidget
                    visible: widgetManager.widgetVisibility["habits"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                PingWidget {
                    id: pingWidget
                    visible: widgetManager.widgetVisibility["ping"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                StorageMapWidget {
                    id: storagemapWidget
                    visible: widgetManager.widgetVisibility["storagemap"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }

                CalcWidget {
                    id: calcWidget
                    visible: widgetManager.widgetVisibility["calc"] !== false
                    screenWidth: desktopWindow.safeScreenWidth
                    screenHeight: desktopWindow.safeScreenHeight
                }
            }
        }
    }
}
