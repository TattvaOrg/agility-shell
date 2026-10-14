import QtQuick
import qs.Core
import qs.Core.Components
import qs.Core.Services
import qs.Core.Windows
import qs.Modules.Clipboard
import qs.Modules.ControlCenter
import qs.Modules.Dashboard
import qs.Modules.KeybindsCheatSheet
import qs.Modules.Launcher
import qs.Modules.LockScreen
import qs.Modules.Music
import qs.Modules.NotificationCenter
import qs.Modules.PackageManager
import qs.Modules.PowerMenu
import qs.Modules.Settings
import qs.Modules.WallpaperSelector

Item {
    id: root

    property var notificationService: null

    // Bar & media popups (loaded as standalone windows when in Pill or external modes)
    WidgetLoader {
        widgetId: "dashboard"

        sourceComponent: Component {
            DashboardWindow {
            }
        }
    }

    WidgetLoader {
        widgetId: "controlCenter"

        sourceComponent: Component {
            ControlCenterWindow {
                notificationService: root.notificationService
            }
        }
    }

    WidgetLoader {
        widgetId: "notificationsCenter"

        sourceComponent: Component {
            NotificationCenterWindow {
                notificationService: root.notificationService
            }
        }
    }

    WidgetLoader {
        widgetId: "music"

        sourceComponent: Component {
            MiniMusicWidget {
            }
        }
    }

    // Application & drawer widgets
    WidgetLoader {
        widgetId: "launcher"

        sourceComponent: Component {
            Launcher {
            }
        }
    }

    WidgetLoader {
        widgetId: "clipboard"

        sourceComponent: Component {
            Clipboard {
            }
        }
    }

    WidgetLoader {
        widgetId: "wallpaper"

        sourceComponent: Component {
            WallpaperSelector {
            }
        }
    }

    WidgetLoader {
        widgetId: "screenshot"
    }

    WidgetLoader {
        widgetId: "powerMenu"

        sourceComponent: Component {
            PowerMenu {
            }
        }
    }

    // Standalone application windows
    WidgetLoader {
        widgetId: "minflair_keybinds"
        exclusive: false

        sourceComponent: Component {
            KeybindsCheatSheet {
            }
        }
    }

    WidgetLoader {
        widgetId: "minflair_settings"
        exclusive: false

        sourceComponent: Component {
            Settings {
            }
        }
    }

    WidgetLoader {
        widgetId: "packagemanager"
        exclusive: false

        sourceComponent: Component {
            PackageManager {
            }
        }
    }

    LockScreen {
        id: lockScreen
    }
}
