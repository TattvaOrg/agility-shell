# Agility Shell Next-Gen (Rust + QML) — Master Product Requirements Document & Implementation Plan

**Document Version:** 2.1.0  
**Target Architecture:** Rust Core Daemon (`agilityd`) + Quickshell (Qt6 / QML) Wayland Shell  
**Primary Compositor:** Niri (with Extensible Wayland Compositor Trait for Hyprland & MangoWC)  
**Status:** Comprehensive Architecture Approved / Ready for Execution  

---

## 1. What is Agility Shell?

**Agility Shell** is a modern, modular, and blazing-fast Wayland desktop shell designed to provide an integrated, fluid, and beautiful desktop environment without desktop bloat. Originally built using Python, GTK3, and Fabric, Agility Shell is transitioning to a **compiled Rust backend daemon (`agilityd`) paired with a reactive Quickshell (Qt6 / QML) frontend**.

### 1.1 Core Philosophy & Design Pillars
1. **Extreme Efficiency & Low Latency:** Sub-40MB total combined system footprint (< 15MB daemon RSS, < 25MB UI RSS), zero garbage collection pauses, and sub-15ms daemon cold-start.
2. **Vintage & Modern Hardware Parity:** Seamless 60–144Hz performance on modern discrete GPUs (Vulkan/OpenGL), paired with universal CPU software rasterization fallback (`QT_QUICK_BACKEND=software`) for vintage Intel HD Graphics and legacy hardware.
3. **Unified Out-of-the-Box Desktop Experience:** Delivers a complete environment including modular multi-monitor status bars, application dock, interactive control center, fuzzy application launcher, notification daemon & history, on-screen display (OSD), clipboard manager, desktop applet canvas, secure PAM lockscreen, desktop suites ("Suits"), and dynamic Material You wallpaper theming.
4. **Declarative & Hackable UI:** The UI is written in clean, reactive QML with instant hot-reloading during development, while low-level system drivers, hardware monitors, and D-Bus services run safely in compiled Rust.
5. **No Python Runtime Required:** The entire Next-Gen shell operates without Python, GTK3, PyGObject, or Fabric dependencies in production.

---

## 2. Complete System Architecture & Data Flow

```
+---------------------------------------------------------------------------------------------------+
|                                     WAYLAND COMPOSITORS                                           |
|                     [Niri (Primary)]  |  [Hyprland]  |  [MangoWC / generic wlroots]               |
+--------------------------------+-----------------------------------+------------------------------+
                                 | wlr-layer-shell                   | Unix IPC Sockets
                                 | ext-session-lock-v1               | (Niri Event Stream,
                                 | ext-idle-notifier-v1              |  wl-roots protocols)
                                 v                                   v
+--------------------------------+--------+   D-Bus Signals       +---+------------------------------+
|        QUICKSHELL FRONTEND             | <==================== |   RUST CORE DAEMON           |
|            (Qt6 / QML)                 | ====================> |       (agilityd)             |
|                                        |    D-Bus Methods      +---+------------------------------+
|  * Multi-Monitor Status Bar(s) & Dock  |                           |
|  * Interactive Control Center          |                           | Native System Interfaces:
|  * Sub-2ms Fuzzy Application Launcher  |                           +--> Niri IPC Socket
|  * Freedesktop Notification Toasts     |                           +--> PipeWire / PulseAudio Mixer
|  * Notification History Drawer         |                           +--> MPRIS2 Media Controller
|  * On-Screen Display (OSD) Popouts     |                           +--> NetworkManager D-Bus
|  * Freeform Desktop Applet Canvas      |                           +--> BlueZ Bluetooth D-Bus
|  * Interactive Canvas Edit Mode        |                           +--> UPower & Sysfs Monitors
|  * Ext-Session-Lock Secure Lockscreen  |                           +--> Linux PAM Auth Worker Thread
|  * Dynamic Theme.qml Bridge            |                           +--> StatusNotifierWatcher (Tray)
|  * Wallpaper Picker & Transitions      |                           +--> Open-Meteo & IP Geolocation
+----------------------------------------+                           +--> Ring-buffer Clipboard Listener
                                                                     +--> Desktop Entry Indexer (.desktop)
                                                                     +--> Matugen Palette Extractor
                                                                     +--> Sound FX Player (pw-play)
                                                                     +------------------------------+
```

---

## 3. Comprehensive D-Bus IPC Specifications (`org.agility.Daemon.*`)

The Rust daemon communicates with Quickshell and external CLI tools over the D-Bus session bus under the well-known name `org.agility.Daemon` (and standard freedesktop endpoints).

### 3.1 `org.agility.Daemon.Workspaces`
- **Object Path:** `/org/agility/Daemon/Workspaces`
- **Properties:**
  - `active_workspace` (`u32`): ID of active workspace.
  - `workspaces` (`s` / JSON): Array of workspace objects `{id, idx, name, output, is_active, window_count}`.
  - `focused_window_title` (`s`): Title of currently focused window.
  - `focused_app_id` (`s`): Application ID / class of focused window.
  - `keyboard_layouts` (`as`): Array of available keyboard layout names (e.g. `["us", "de"]`).
  - `current_keyboard_layout` (`s`): Name of current active layout.
  - `current_keyboard_layout_idx` (`u32`): Index of active layout.
- **Methods:**
  - `ActivateWorkspace(u32 id) -> ()`
  - `CloseFocusedWindow() -> ()`
  - `SwitchKeyboardLayout(u32 idx) -> ()`
- **Signals:**
  - `WorkspaceChanged(u32 id)`
  - `WindowChanged(s title, s app_id)`
  - `KeyboardLayoutChanged(s name, u32 idx)`

### 3.2 `org.agility.Daemon.Audio`
- **Object Path:** `/org/agility/Daemon/Audio`
- **Properties:**
  - `volume` (`d`): Default audio sink volume (0.0 – 1.5).
  - `muted` (`b`): Default audio sink mute state.
  - `mic_volume` (`d`): Default microphone volume (0.0 – 1.0).
  - `mic_muted` (`b`): Default microphone mute state.
  - `sinks` (`s` / JSON): List of available output audio devices.
  - `sources` (`s` / JSON): List of available input audio devices.
- **Methods:**
  - `SetVolume(d vol) -> ()`
  - `AdjustVolume(d delta) -> ()`
  - `ToggleMute() -> ()`
  - `SetMicVolume(d vol) -> ()`
  - `ToggleMicMute() -> ()`
  - `SetDefaultSink(s name) -> ()`
  - `SetDefaultSource(s name) -> ()`
- **Signals:**
  - `VolumeChanged(d vol, b muted)`
  - `MicChanged(d vol, b muted)`

### 3.3 `org.agility.Daemon.Media`
- **Object Path:** `/org/agility/Daemon/Media`
- **Properties:**
  - `active_player` (`s`): Currently active MPRIS player name (e.g. `spotify`, `firefox`).
  - `playback_status` (`s`): `"Playing"`, `"Paused"`, `"Stopped"`.
  - `title` (`s`): Current track title.
  - `artist` (`s`): Current track artist.
  - `album` (`s`): Current track album name.
  - `art_url` (`s`): Cover art URI / path.
  - `position` (`x`): Current position in microseconds.
  - `length` (`x`): Total duration in microseconds.
- **Methods:**
  - `PlayPause() -> ()`
  - `Next() -> ()`
  - `Previous() -> ()`
  - `Seek(x offset_usec) -> ()`
- **Signals:**
  - `TrackChanged(s title, s artist, s art_url)`
  - `StatusChanged(s status)`

### 3.4 `org.agility.Daemon.Hardware`
- **Object Path:** `/org/agility/Daemon/Hardware`
- **Properties:**
  - `cpu_usage` (`d`): Total CPU usage percentage (0.0 – 100.0).
  - `cpu_cores` (`a(d)`): Per-core CPU usage percentages.
  - `ram_used_bytes` (`t`): Memory currently used.
  - `ram_total_bytes` (`t`): Total system memory.
  - `swap_used_bytes` (`t`): Swap space used.
  - `swap_total_bytes` (`t`): Total swap space.
  - `battery_percentage` (`d`): Primary battery percentage.
  - `battery_state` (`s`): `"Charging"`, `"Discharging"`, `"Full"`, `"Not Present"`.
  - `battery_time_remaining` (`x`): Seconds until empty or full.
  - `temperature_cpu` (`d`): CPU package temperature in °C.
  - `storage_devices` (`s` / JSON): Array of filesystem mounts with used/total GB.
- **Signals:**
  - `TelemetryUpdated()` (Emitted on polling tick)

### 3.5 `org.agility.Daemon.Connectivity`
- **Object Path:** `/org/agility/Daemon/Connectivity`
- **Properties:**
  - `wifi_enabled` (`b`): WiFi radio power state.
  - `wifi_connected` (`b`): Active WiFi connection state.
  - `wifi_ssid` (`s`): Name of active SSID.
  - `wifi_signal` (`u32`): Signal strength percentage (0 – 100).
  - `ethernet_connected` (`b`): Wired ethernet connection state.
  - `bluetooth_enabled` (`b`): Bluetooth adapter power state.
  - `bluetooth_devices` (`s` / JSON): Paired and connected Bluetooth devices.
- **Methods:**
  - `ToggleWifi() -> ()`
  - `ScanWifi() -> (s)` (Returns JSON list of available SSIDs)
  - `ConnectWifi(s ssid, s password) -> (b)`
  - `ToggleBluetooth() -> ()`
  - `ConnectBluetoothDevice(s mac) -> (b)`
  - `DisconnectBluetoothDevice(s mac) -> (b)`
- **Signals:**
  - `WifiStatusChanged(b connected, s ssid, u32 signal)`
  - `BluetoothStatusChanged(b enabled, u32 connected_count)`

### 3.6 `org.agility.Daemon.Launcher`
- **Object Path:** `/org/agility/Daemon/Launcher`
- **Methods:**
  - `Query(s query) -> (s)`: Returns JSON array of ranked matching desktop entries `{id, name, exec, icon, comment, score}` in < 2ms.
  - `ListAll() -> (s)`: Returns all indexed applications categorized.
  - `Launch(s desktop_id) -> (b)`: Spawns application cleanly detached in its own process group.
- **Signals:**
  - `IndexRefreshed(u32 count)`

### 3.7 `org.agility.Daemon.Suits`
- **Object Path:** `/org/agility/Daemon/Suits`
- **Properties:**
  - `active_suite_id` (`s`): ID of active suite (e.g. `"minimal"`, `"focused"`, `"gaming"`).
  - `available_suites` (`s` / JSON): Array of suite definitions loaded from `suits.json`.
- **Methods:**
  - `SwitchSuite(s id) -> (b)`
  - `CycleNextSuite() -> (s)`
  - `CyclePrevSuite() -> (s)`
  - `ExportSuite(s id, s path) -> (b)`
  - `ImportSuite(s path) -> (b)`
- **Signals:**
  - `SuiteChanged(s id, s name)`

### 3.8 `org.agility.Daemon.Theme`
- **Object Path:** `/org/agility/Daemon/Theme`
- **Properties:**
  - `is_dark` (`b`): Dark mode vs Light mode flag.
  - `primary_color` (`s`): Primary Material You hex token (e.g. `"#8AB4F8"`).
  - `secondary_color` (`s`): Secondary hex token.
  - `surface_color` (`s`): Surface container hex token.
  - `background_color` (`s`): Background hex token.
  - `accent_colors` (`a(s)`): Array of active accent colors.
  - `active_wallpaper` (`s`): Absolute path to active wallpaper image.
  - `border_radius` (`u32`): UI corner radius in px.
  - `font_family` (`s`): Primary UI font family.
  - `font_mono` (`s`): Monospace font family.
- **Methods:**
  - `SetWallpaper(s path) -> (b)`
  - `GenerateFromWallpaper(s path) -> (b)`
  - `SetStaticPreset(s preset_name) -> (b)`
  - `ToggleDarkMode() -> ()`
- **Signals:**
  - `ThemeTokensChanged()`

### 3.9 `org.freedesktop.Notifications` (Notification Server)
- **Object Path:** `/org/freedesktop/Notifications`
- **Implemented Specifications:** Full Desktop Notifications v1.2.
- **Methods:**
  - `Notify(s app_name, u32 replaces_id, s app_icon, s summary, s body, as actions, a{sv} hints, i expire_timeout) -> (u32 id)`
  - `CloseNotification(u32 id) -> ()`
  - `GetCapabilities() -> (as)` (`["body", "body-markup", "actions", "icon-static", "persistence", "sound"]`)
  - `GetServerInformation() -> (s name, s vendor, s version, s spec_version)`
- **Internal Storage:**
  - Persists all received notifications into a local SQLite/JSON history store (`~/.cache/agility-shell/notifications.db`).
  - Dispatches `org.agility.Daemon.Notifications.HistoryChanged` signal for Quickshell Notification Drawer.

### 3.10 `org.agility.Daemon.Clipboard`
- **Object Path:** `/org/agility/Daemon/Clipboard`
- **Properties:**
  - `history` (`s` / JSON): Array of recent copied items `{id, text, preview, timestamp, byte_size}`.
- **Methods:**
  - `CopyText(s text) -> ()`
  - `RemoveItem(u32 id) -> ()`
  - `Clear() -> ()`
- **Signals:**
  - `ClipboardChanged()`

### 3.11 `org.agility.Daemon.Power`
- **Object Path:** `/org/agility/Daemon/Power`
- **Properties:**
  - `caffeine_active` (`b`): State of idle inhibitor.
  - `power_profile` (`s`): Active profile (`"power-saver"`, `"balanced"`, `"performance"`).
  - `night_light_active` (`b`): Night light color filter state.
  - `night_light_temperature` (`u32`): Active Kelvin temperature (e.g. `4000`).
- **Methods:**
  - `ToggleCaffeine() -> (b)`
  - `SetPowerProfile(s profile) -> (b)`
  - `ToggleNightLight() -> (b)`
  - `SetNightLightTemperature(u32 kelvin) -> ()`
- **Signals:**
  - `PowerStateChanged()`

### 3.12 `org.agility.Daemon.Weather`
- **Object Path:** `/org/agility/Daemon/Weather`
- **Properties:**
  - `temperature` (`d`): Current temperature in °C.
  - `feels_like` (`d`): Apparent temperature.
  - `condition_code` (`u32`): WMO weather code.
  - `condition_text` (`s`): Human-readable weather description.
  - `condition_icon` (`s`): Name of corresponding duotone icon.
  - `city` (`s`): Detected or configured city name.
  - `humidity` (`u32`): Humidity percentage.
  - `wind_speed` (`d`): Wind speed in km/h.
  - `hourly_forecast` (`s` / JSON): 24-hour forecast data.
- **Methods:**
  - `Refresh() -> ()`
- **Signals:**
  - `WeatherUpdated()`

### 3.13 `org.agility.Daemon.MediaCapture`
- **Object Path:** `/org/agility/Daemon/MediaCapture`
- **Properties:**
  - `is_recording` (`b`): Screen recording active state.
  - `recording_duration` (`u32`): Elapsed seconds.
- **Methods:**
  - `TakeScreenshot(s mode) -> (s path)`: Modes: `"fullscreen"`, `"window"`, `"region"`.
  - `StartRecording(b with_audio) -> (b)`
  - `StopRecording() -> (s path)`
- **Signals:**
  - `ScreenshotSaved(s path)`
  - `RecordingStateChanged(b active, s path)`

### 3.14 `org.agility.Daemon.Lock`
- **Object Path:** `/org/agility/Daemon/Lock`
- **Methods:**
  - `Authenticate(s password) -> (b)`: Verifies password via isolated Linux PAM worker thread.
  - `LockSession() -> ()`: Emits lock request to Quickshell `WlrSessionLock`.
- **Security:** Zeroes out password strings in memory immediately after verification. Rate limits failed attempts with exponential backoff.

### 3.15 `org.kde.StatusNotifierWatcher` (System Tray Host)
- **Object Path:** `/StatusNotifierWatcher`
- **Description:** Implements SNI watcher allowing third-party tray applications (Discord, Steam, Telegram, OBS, etc.) to register items and stream icons/menus to Quickshell status bars.

### 3.16 `org.agility.Daemon.Sounds`
- **Object Path:** `/org/agility/Daemon/Sounds`
- **Methods:**
  - `Play(s sound_name) -> ()`: Dispatches system sound (`"session-start"`, `"session-quit"`, `"notification"`, `"battery-low"`, `"battery-warning"`, `"battery-charge"`, `"error"`, `"confirm"`, `"alarm"`, `"widget-placed"`, `"widget-removed"`).

### 3.17 `org.agility.Daemon.Timer`
- **Object Path:** `/org/agility/Daemon/Timer`
- **Properties:**
  - `stopwatch_running` (`b`): Stopwatch active state.
  - `stopwatch_elapsed` (`d`): Elapsed seconds with centisecond precision.
  - `stopwatch_laps` (`s` / JSON): Array of recorded lap split objects `{lap_number, time, lap_time}`.
  - `alarm_set` (`b`): Whether a countdown alarm is currently armed.
  - `alarm_triggered` (`b`): Whether the active alarm is currently firing.
  - `alarm_remaining_sec` (`d`): Seconds remaining until alarm triggers.
- **Methods:**
  - `StartStopwatch() -> ()`
  - `PauseStopwatch() -> ()`
  - `ResetStopwatch() -> ()`
  - `AddLap() -> (s)`
  - `SetAlarm(u32 hours, u32 minutes, u32 seconds) -> ()`
  - `CancelAlarm() -> ()`
  - `SnoozeAlarm(u32 minutes) -> ()`
- **Signals:**
  - `AlarmTriggered()`
  - `StopwatchUpdated(d elapsed)`

### 3.18 `org.agility.Daemon.System`
- **Object Path:** `/org/agility/Daemon/System`
- **Properties:**
  - `top_processes` (`s` / JSON): Live array of processes `{pid, name, cpu_percent, memory_mb}` sorted descending by CPU.
  - `updates_available` (`u32`): Number of commits behind remote or pending system updates.
- **Methods:**
  - `KillProcess(u32 pid) -> (b)`: Gracefully terminates (or force kills) a target process by PID.
  - `CheckUpdates() -> (u32)`: Queries git remote / package manager asynchronously.
  - `PowerOff() -> ()`: Triggers system shutdown via logind D-Bus.
  - `Reboot() -> ()`: Triggers system reboot via logind D-Bus.
  - `Suspend() -> ()`: Triggers system suspend via logind D-Bus.
  - `Hibernate() -> ()`: Triggers system hibernation via logind D-Bus.
  - `Logout() -> ()`: Terminates active Wayland user session cleanly.
- **Signals:**
  - `UpdateAvailable(u32 count)`

### 3.19 `org.freedesktop.impl.portal.Settings` (XDG Desktop Portal Settings & Color Scheme Bridge)
- **Object Path:** `/org/freedesktop/portal/desktop`
- **Description:** Implements standard portal Settings interface broadcasting dark/light appearance tokens to sandboxed Flatpaks and native GTK/Qt applications.
- **Methods:**
  - `ReadAll(as namespaces) -> (a{sa{sv}})`
  - `Read(s namespace, s key) -> (v)`
- **Signals:**
  - `SettingChanged(s namespace, s key, v value)` (`org.freedesktop.appearance`, `color-scheme`: `1` for dark, `2` for light)

---

## 4. Configuration & User Options Schema

Agility Shell stores configuration in standard XDG paths (`~/.config/agility-shell/`):
- `config/config.json`: Master shell configuration.
- `config/suits.json`: Desktop suites presets.
- `widget_settings.json`: Configuration and placement for desktop canvas applets.
- `custom_style/`: User CSS/QML token overrides (`color.css`, `border.css`, `font.css`).

### 4.1 Master `config.json` Structure
```json
{
  "user": {
    "avatar": "/var/lib/AccountsService/icons/$USER"
  },
  "settings": {
    "dnd": false,
    "hover_open": true,
    "hover_delay": 150,
    "bar_theme": "liquid-glass",
    "bar_blur": true,
    "bar_opacity": 0.35,
    "widget_opacity": 0.55,
    "desktop_widget_opacity": 0.60,
    "dash_blur": true,
    "dash_dim_opacity": 0.20,
    "dash_card_opacity": 1.0,
    "instant_dash": true,
    "bluetooth_on_startup": false,
    "pinned_apps": ["thunar.desktop", "brave-browser.desktop", "kitty.desktop"],
    "agility_profile": "balanced",
    "bar_height": 30
  },
  "bars": {
    "configs": [
      {
        "monitor": 0,
        "bars": [
          {
            "alignment": "top",
            "horizontal_alignment": "center",
            "floating_bar": true,
            "floating_applets": true,
            "rounded_edges": true,
            "min_width": false,
            "auto_hide": false,
            "left": ["Dash", "Launcher", "Workspaces", "Processes", "Weather", "Media"],
            "center": ["Clock"],
            "right": ["Tray", "Energy", "Volume", "Brightness", "Wifi", "Bluetooth", "Settings", "Notifications"]
          },
          {
            "alignment": "bottom",
            "horizontal_alignment": "center",
            "floating_bar": true,
            "floating_applets": true,
            "rounded_edges": true,
            "min_width": true,
            "auto_hide": true,
            "left": [],
            "center": ["Dock"],
            "right": []
          }
        ]
      }
    ]
  },
  "timeouts": {
    "list": [
      {"name": "screen-off", "timeout_ac": 10, "timeout_bat": 2, "enabled": true},
      {"name": "lock", "timeout_ac": 15, "timeout_bat": 5, "enabled": true},
      {"name": "suspend", "timeout_ac": 30, "timeout_bat": 15, "enabled": true}
    ]
  },
  "theme": {
    "light_theme": "catppuccin-latte",
    "dark_theme": "Matugen",
    "active_accent": "accent4",
    "is_dark": true,
    "scheme_type": "scheme-tonal-spot",
    "opacity": 0.35,
    "border_style": "medium",
    "font_family": "Inter",
    "font_monospace": "JetBrainsMono Nerd Font"
  },
  "launcher": {
    "grid": false,
    "keybind_position": "center"
  },
  "dock": {
    "entries": []
  },
  "world_clocks": {
    "clocks": ["Europe/London", "America/New_York", "Asia/Tokyo"]
  },
  "wallpaper": {
    "path": "~/.config/agility-shell/wallpapers/5.png",
    "transition_type": "random",
    "transition_duration": 0.7,
    "transition_speed": "quick",
    "transition_fps": 60,
    "switcher_style": "mesh"
  },
  "desktop_canvas": {
    "placements": {
      "0": []
    }
  }
}
```

---

## 5. Quickshell Frontend Architecture & UI Hierarchy

The Quickshell UI uses `wlr-layer-shell` surfaces divided into 7 distinct rendering layers:

```
[Layer 7] Wayland ext-session-lock-v1 Screen Lock Surface (Exclusive Security Barrier)
    ^
[Layer 6] On-Screen Display (OSD) Overlay (Volume, Backlight, Power Profile, Alarms)
    ^
[Layer 5] Notification Toasts & Dropdown Notification Center (Layer: Overlay)
    ^
[Layer 4] Modal Application Launcher / Dashboard Overlay (Layer: Top)
    ^
[Layer 3] Island Popout Applets (Control Center, Audio Mixer, WiFi, Calendar, Clocks)
    ^
[Layer 2] Status Bar(s) & Floating Application Dock (Layer: Top, Exclusive Zone)
    ^
[Layer 1] Desktop Background Canvas: Draggable Widgets & Visualizers (Layer: Bottom)
```

### Complete Widget Inventory to be Implemented in QML:
1. **Bar Widgets (25+):** `Launcher`, `Processes` (CPU graph), `Energy` (Battery), `Bluetooth`, `Notifications`, `Settings`, `Clock`, `Media`, `Workspaces`, `Weather`, `Volume`, `Tray`, `Calendar`, `Focused` (Window Title), `Wifi`, `Session` (Power Menu), `Calculator`, `Keyboard`, `Screenshot`, `Dock`, `Brightness`, `Dash`, `Clipboard`, `Caffeine`, `SysMon`, `NightLight`, `Suits`.
2. **Desktop Canvas Applets (20+):** `Clock`, `BatteryWidget`, `CalcWidget`, `CalendarWidget`, `ClipboardWidget`, `CryptoWidget`, `GitDashboardWidget`, `HabitsWidget`, `LiquidCard`, `MediaWidget`, `NetworkWidget`, `NotesWidget`, `PingWidget`, `PosterWidget`, `QuoteWidget`, `ResourceWheelWidget`, `StorageMapWidget`, `SystemInfo`, `ThermalWidget`, `TimerWidget`, `TodoWidget`, `VisualizerWidget` (Audio FFT), `VolumeBrightnessWidget`, `WeatherWidget`, `WorldClockWidget`.

---

## 6. Target Specifications & Performance KPIs

| Metric | Legacy (Python + GTK3) | Next-Gen Target (Rust + QML) | Verification Method |
| :--- | :--- | :--- | :--- |
| **Idle RAM (Daemon)** | ~180 MB – 320 MB | **< 15 MB RSS** | `ps -o rss,comm -p $(pgrep agilityd)` |
| **Idle RAM (Quickshell UI)** | Included above | **< 25 MB RSS** | `ps -o rss,comm -p $(pgrep quickshell)` |
| **Combined Idle Footprint** | ~250 MB | **< 40 MB RSS total** | Sum of daemon + frontend RSS |
| **Daemon Cold Boot Time** | ~1800 ms | **< 15 ms** | `hyperfine --warmup 3 'agilityd --test'` |
| **Surface Presentation Time**| ~2200 ms | **< 120 ms** | Wayland frame callback after process launch |
| **Search Keystroke Latency** | ~45 ms (Python GIL) | **< 2 ms** | In-memory Nucleo fuzzy matching |
| **Workspace Switch Latency** | ~35 ms | **< 4 ms** | End-to-end Niri IPC socket to QML repaint |
| **Vintage GPU Compatibility** | Dependent on GTK Cairo | **Universal 60 FPS** | Tested via `QT_QUICK_BACKEND=software` |

---

## 7. Master Step-by-Step Implementation Roadmap

Use this checklist to track progress throughout the implementation. Mark items with `[X]` as each step is completed and verified.

---

### Step 1: Workspace Scaffolding & Build System Setup
- [X] 1.1 Create Cargo workspace configuration at repository root with members `crates/agilityd` and `crates/agility-cli`.
- [X] 1.2 Define dependency manifests (`tokio`, `zbus`, `serde`, `serde_json`, `sysinfo`, `nucleo`, `pam-sys`, `libpulse-binding`, `tracing`, `tracing-subscriber`).
- [X] 1.3 Configure release build profile (`lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `strip = true`) for minimal binary size and maximum performance.
- [X] 1.4 Update root `Makefile` with targets for building and installing `agilityd` and `agl` (`make build`, `make install`).
- [X] 1.5 Update `PKGBUILD` to compile the Rust daemon and CLI tool via `cargo build --release` and install to `/usr/bin/agilityd` and `/usr/bin/agl`.
- [X] 1.6 Verify clean compilation and zero-warning build on Arch Linux.

---

### Step 2: Core Rust Daemon Infrastructure (`agilityd`)
- [X] 2.1 Implement `main.rs` daemon initialization, structured logging via `tracing-subscriber`, and CLI flags (`--daemon`, `--foreground`, `--test`, `--version`).
- [X] 2.2 Implement Unix signal handling (`SIGINT`, `SIGTERM`, `SIGHUP`) for graceful daemon shutdown and configuration reloading.
- [X] 2.3 Establish D-Bus connection on `org.agility.Daemon` using `zbus::connection::Builder::session()`.
- [X] 2.4 Implement singleton state manager holding in-memory state structs and atomic broadcast channels.
- [X] 2.5 Seed and validate user configuration directories (`~/.config/agility-shell/`, `~/.cache/agility-shell/`).
- [X] 2.6 Verify D-Bus service registration with `busctl --user list | grep org.agility.Daemon`.

---

### Step 3: Niri & Multi-Compositor IPC Module
- [X] 3.1 Discover and connect to active Niri socket via `NIRI_SOCKET` environment variable.
- [X] 3.2 Implement asynchronous JSON stream reader for Niri event stream (`WorkspacesChanged`, `WorkspaceActivated`, `WindowOpenedOrChanged`, `WindowClosed`, `WindowFocusChanged`).
- [X] 3.3 Create `Compositor` trait abstraction allowing future extension to Hyprland and generic wlroots protocols.
- [X] 3.4 Implement D-Bus interface `org.agility.Daemon.Workspaces` exposing active workspace, window titles, and workspace switching methods.
- [X] 3.5 Implement keyboard layout synchronization observing compositor IPC events and expose `SwitchKeyboardLayout(idx)` on `org.agility.Daemon.Workspaces`.
- [X] 3.6 Test workspace switching latency and event reliability under rapid switching (< 4ms response).

---

### Step 4: Hardware & System Telemetry Engine
- [ ] 4.1 Implement asynchronous CPU utilization poller using non-blocking `/proc/stat` delta calculations.
- [ ] 4.2 Implement RAM and swap usage reader from `/proc/meminfo`.
- [ ] 4.3 Implement UPower and `/sys/class/power_supply` battery monitor (percentage, charging state, time to empty/full, health).
- [ ] 4.4 Implement thermal temperature monitor inspecting `/sys/class/thermal/` and `/sys/class/hwmon/`.
- [ ] 4.5 Implement filesystem storage monitor calculating mounted root and home directory usage.
- [ ] 4.6 Expose telemetry via `org.agility.Daemon.Hardware` with configurable polling frequencies (fast: 1s for CPU/RAM, slow: 10s for battery/storage).
- [ ] 4.7 Implement top process scanner sorted by CPU/memory and `KillProcess(pid)` method on `org.agility.Daemon.System`.


---

### Step 5: Audio Engine, PipeWire/Pulse Mixer, MPRIS2 & Visualizer Stream
- [ ] 5.1 Connect to PipeWire / WirePlumber audio daemon via PulseAudio protocol (`libpulse-binding`).
- [ ] 5.2 Implement reactive volume listener for default audio sink (speakers/headphones) and default source (microphone).
- [ ] 5.3 Expose D-Bus interface `org.agility.Daemon.Audio` with volume adjustment, mute toggles, and sink enumeration.
- [ ] 5.4 Implement MPRIS2 player controller listening for Spotify, Firefox, MPV metadata and playback controls on `org.agility.Daemon.Media`.
- [ ] 5.5 Implement lightweight PipeWire audio monitor / CAVA stream capturing audio amplitude bars for QML audio visualizers.

---

### Step 6: Network & Bluetooth Connectivity Engine
- [ ] 6.1 Implement NetworkManager D-Bus client (`org.freedesktop.NetworkManager`) to observe active connection status, WiFi state, SSID, and signal strength.
- [ ] 6.2 Implement BlueZ D-Bus client (`org.bluez`) to monitor Bluetooth adapter power and connected devices.
- [ ] 6.3 Expose consolidated interface `org.agility.Daemon.Connectivity` for high-level QML consumption.
- [ ] 6.4 Implement async WiFi scanning and connection methods.

---

### Step 7: Application Indexer & Sub-Millisecond Fuzzy Launcher Engine
- [ ] 7.1 Implement background scanner for standard XDG desktop entry directories (`/usr/share/applications`, `~/.local/share/applications`).
- [ ] 7.2 Parse `.desktop` files (Name, Exec, Icon, Comment, Categories, Keywords, NoDisplay).
- [ ] 7.3 Cache parsed applications in an in-memory index structure.
- [ ] 7.4 Integrate `nucleo` for fuzzy matching with match scoring and character highlighting.
- [ ] 7.5 Expose D-Bus interface `org.agility.Daemon.Launcher` with `Query()`, `Launch()`, and `ListAll()`.
- [ ] 7.6 Benchmark search response: guarantee < 2ms latency for 500+ installed applications.
- [ ] 7.7 Implement high-speed Icon Resolver engine matching reverse-DNS app IDs to Freedesktop icons and local `svgs/` duotones, backed by in-memory and disk cache (`~/.cache/agility-shell/icons.json`).

---

### Step 8: Desktop Suites ("Suits") & Settings Engine
- [ ] 8.1 Port `suits.json` schema to strongly typed Rust structs with Serde serialization.
- [ ] 8.2 Load, validate, and save suites from `~/.config/agility-shell/config/suits.json`.
- [ ] 8.3 Expose D-Bus interface `org.agility.Daemon.Suits` (`GetSuits()`, `SwitchSuite()`, `CycleNextSuite()`, `CyclePrevSuite()`).
- [ ] 8.4 Load base user settings from `~/.config/agility-shell/config/config.json` with fallback defaults.
- [ ] 8.5 Implement Doom Vertical Melt screen transition overlay (`DoomMeltOverlay`) playing staggered column melt animation across monitors when switching suites.

---

### Step 9: Dynamic Theming Engine (Matugen + Material You + Templates)
- [ ] 9.1 Implement wallpaper path listener and setter (compatible with `awww`, `swww`, and static paths).
- [ ] 9.2 Integrate `matugen` invocation or native material-color-utilities palette generator.
- [ ] 9.3 Extract primary, secondary, surface, background, and accent color hex tokens.
- [ ] 9.4 Expose D-Bus interface `org.agility.Daemon.Theme` streaming dynamic theme tokens directly to QML without file writes.
- [ ] 9.5 Provide fallback static color presets (Dark, Light, TokyoNight, Catppuccin, Gruvbox) when wallpaper extraction is disabled.
- [ ] 9.6 Implement template generator applying extracted tokens to terminal configurations (Kitty, Alacritty, Foot) and Niri borders.
- [ ] 9.7 Implement fast Rust-native blurred wallpaper generator using `image` crate, producing `~/.cache/agility-shell/wallpaper_blurred` in < 15ms for lockscreen and UI glass backgrounds.
- [ ] 9.8 Implement XDG Desktop Portal Settings backend (`org.freedesktop.impl.portal.Settings`) synchronizing `color-scheme` (0: default, 1: dark, 2: light) across Flatpaks and native GTK/Qt applications.

---

### Step 10: Freedesktop Notification Server & Persistent History Store
- [ ] 10.1 Implement `org.freedesktop.Notifications` D-Bus service directly in `agilityd`.
- [ ] 10.2 Parse incoming notification specifications (summary, body, app_icon, actions, urgency, hints).
- [ ] 10.3 Persist notifications into SQLite/JSON database at `~/.cache/agility-shell/notifications.db`.
- [ ] 10.4 Expose notification history querying and clearing methods for Quickshell Notification Drawer.
- [ ] 10.5 Emit toast notification signals to Quickshell and dispatch audio trigger (`sounds/notification.wav`).

---

### Step 11: Clipboard Manager Engine
- [ ] 11.1 Implement Wayland data-control / cliphist event listener detecting new text selections.
- [ ] 11.2 Maintain an in-memory 50-item deduplicated ring buffer with preview strings and timestamps.
- [ ] 11.3 Expose D-Bus interface `org.agility.Daemon.Clipboard` with `CopyText()`, `RemoveItem()`, and `Clear()`.
- [ ] 11.4 Ensure zero CPU usage when clipboard remains idle.

---

### Step 12: Power, Idle Inhibitor (Caffeine), Performance Profiles & Night Light
- [ ] 12.1 Implement Wayland idle monitor / `ext-idle-notifier-v1` listener observing AC and Battery idle thresholds.
- [ ] 12.2 Implement Caffeine mode acquiring Wayland idle inhibitor or systemd `Inhibit()` lock.
- [ ] 12.3 Integrate Linux power profiles daemon (`power-profiles-daemon`) for `"power-saver"`, `"balanced"`, `"performance"`.
- [ ] 12.4 Implement Night Light controller adjusting screen color temperature via `wlsunset` or compositor gamma protocol.
- [ ] 12.5 Expose D-Bus interface `org.agility.Daemon.Power`.

---

### Step 13: Weather & Geolocation Background Fetcher
- [ ] 13.1 Implement asynchronous IP geolocation query via `http://ip-api.com/json/`.
- [ ] 13.2 Implement weather fetcher querying Open-Meteo API (`https://api.open-meteo.com/v1/forecast`).
- [ ] 13.3 Map WMO weather condition codes to Agility duotone icon names.
- [ ] 13.4 Cache weather forecast locally in `~/.cache/agility-shell/weather/` with 10-minute refresh interval.
- [ ] 13.5 Expose D-Bus interface `org.agility.Daemon.Weather`.

---

### Step 14: Screenshot & Screen Recording Service
- [ ] 14.1 Implement screenshot trigger wrapping `grim` and `slurp` for fullscreen, active window, and custom selection region.
- [ ] 14.2 Implement screen recording trigger wrapping `wl-screenrec` with PipeWire audio monitor recording.
- [ ] 14.3 Save captures automatically to `~/Pictures/Screenshots` and `~/Videos/Recordings` with copy-to-clipboard option.
- [ ] 14.4 Expose D-Bus interface `org.agility.Daemon.MediaCapture`.

---

### Step 15: System Tray Host (`StatusNotifierWatcher`) & Sound Effects Player
- [ ] 15.1 Implement `org.kde.StatusNotifierWatcher` registration and protocol handler in `agilityd`.
- [ ] 15.2 Stream registered tray items, icons, and context menus to Quickshell status bars.
- [ ] 15.3 Implement native sound effects dispatcher calling `pw-play` or PulseAudio stream for shell sound events (`session-start`, `session-quit`, `notification`, `battery-low`, `confirm`, `error`).
- [ ] 15.4 Expose D-Bus interface `org.agility.Daemon.Sounds`.

---

### Step 16: Secure Linux PAM Lockscreen Worker
- [ ] 16.1 Implement isolated worker thread in `agilityd` wrapping Linux PAM (`libpam`).
- [ ] 16.2 Handle standard PAM conversation functions (`PAM_PROMPT_ECHO_OFF`, `PAM_ERROR_MSG`).
- [ ] 16.3 Expose D-Bus endpoint `org.agility.Daemon.Lock.Authenticate(password: string) -> bool`.
- [ ] 16.4 Implement rate limiting and exponential backoff to prevent brute-force unlock attempts.
- [ ] 16.5 Zero-out password buffers in memory immediately after authentication verification.

---

### Step 17: Quickshell Frontend — Shell Entry, Theme Singleton & Status Bars / Dock
- [ ] 17.1 Reorganize `quickshell/agility/` into clean component architecture (`shell.qml`, `Theme.qml`, `bar/`, `dock/`, `popouts/`, `launcher/`, `lockscreen/`, `canvas/`).
- [ ] 17.2 Implement `Theme.qml` singleton binding reactively to `org.agility.Daemon.Theme` D-Bus properties.
- [ ] 17.3 Implement multi-monitor Status Bar(s) reading `config.json` layout (alignment, heights, floating options).
- [ ] 17.4 Implement Bar Widgets: Workspaces, Window Title, Clock, Volume, Brightness, Battery, Wifi, Bluetooth, Suits switcher, Tray, Media.
- [ ] 17.5 Implement standalone floating Application Dock with pinned apps and active running indicators.
- [ ] 17.6 Test hot-reloading with `quickshell -p quickshell/agility/shell.qml`.

---

### Step 18: Quickshell Frontend — Control Center, Popouts, OSD & Launcher Dash
- [ ] 18.1 Build smooth slide-down Control Center overlay anchored to top-right bar island.
- [ ] 18.2 Implement interactive sliders for Volume, Mic, and Screen Brightness.
- [ ] 18.3 Implement quick toggle tiles for WiFi, Bluetooth, Caffeine, Night Light, and Power Profile.
- [ ] 18.4 Implement standalone popout menus for WiFi network selection, Bluetooth pairing, Audio device mixer, and Power/Session logout.
- [ ] 18.5 Implement On-Screen Display (OSD) overlay for hardware Volume/Backlight adjustments, Keyboard Layout switching, Power Profile changes, and Update Available notification alerts.
- [ ] 18.6 Implement centered modal Application Launcher / Dash with sub-2ms fuzzy search, categories, and calculator mode.

---

### Step 19: Quickshell Frontend — Desktop Applets Canvas, Edit Mode & Ext-Session-Lock Lockscreen
- [ ] 19.1 Implement desktop canvas surface anchored to `Layer::Bottom` rendering freeform widgets from `widget_settings.json`.
- [ ] 19.2 Integrate 20+ desktop widgets (`ResourceWheelWidget`, `ThermalWidget`, `StorageMapWidget`, `VisualizerWidget`, `WeatherWidget`, `CalendarWidget`, `NotesWidget`, `TodoWidget`, `HabitsWidget`, `CryptoWidget`, `GitDashboardWidget`).
- [ ] 19.3 Implement interactive Desktop Edit Mode allowing users to drag, resize, and configure canvas widgets.
- [ ] 19.4 Implement Wayland session lock window using Quickshell `WlrSessionLock` / `ext-session-lock-v1`.
- [ ] 19.5 Render blurred wallpaper surface, clock, date, avatar, and secure password input connected to PAM worker.
- [ ] 19.6 Ensure screen remains fully locked across monitor connect/disconnect events.
- [ ] 19.7 Implement User Plugin & Custom Applets dynamic loader: scan `~/.local/share/agility-shell/plugins/` and load user-defined QML applets into the Desktop Canvas and Status Bar menus.

---

### Step 20: CLI Tool (`agl`), Systemd Integration, Backward Compatibility & Packaging
- [ ] 20.1 Build `crates/agility-cli` (`agl`) binary in Rust dispatching high-speed D-Bus calls to `agilityd`:
  - `agl start [--legacy]`: Start daemon and Quickshell (or legacy Python stack).
  - `agl stop`: Cleanly stop daemon and Quickshell.
  - `agl restart`: Gracefully restart UI surfaces and daemon in < 15ms.
  - `agl status`: Inspect daemon PID and D-Bus status.
  - `agl lock`: Trigger session lockscreen.
  - `agl toggle <launcher|control-center|dashboard|calendar|clipboard|weather|media|notifications|suits|applets-edit|wallpaper>`: Toggle overlays.
  - `agl profile <balanced|performance|power-saver|get>`: Set or get system power profile.
  - `agl bar <height <26-48> | width [toggle|min|full]>`: Dynamically adjust status bar thickness and width mode.
  - `agl suits <list|next|prev|switch <id>>`: Manage and cycle desktop suites.
  - `agl volume <up|down|mute> [step]`: Audio volume control.
  - `agl brightness <up|down> [step]`: Display backlight control.
  - `agl screenshot <full|window|region>`: Trigger screenshot capture.
  - `agl record <start|stop>`: Trigger screen recording with PipeWire audio.
  - `agl caffeine <toggle>`: Toggle idle inhibitor state.
  - `agl deps`: Verify system runtime and compositor dependencies.
  - `agl update`: Perform self-update check and upgrade.
- [ ] 20.2 Create systemd user service `agility-shell.service` managing `agilityd` and `quickshell` lifecycles.
- [ ] 20.3 Implement fallback switch: allow users to launch legacy Python shell via `agl start --legacy`.
- [ ] 20.4 Ensure existing `~/.config/agility-shell/` user configurations migrate seamlessly without loss of custom user keys.
- [ ] 20.5 Update installer scripts (`install.sh`, `scripts/install.sh`) to build and deploy the Rust daemon and Quickshell frontend.
- [ ] 20.6 Update Arch `PKGBUILD` and verify `makepkg -si` produces a clean pacman package.
- [ ] 20.7 Benchmark idle memory on test machines: verify total RAM <= 40 MB RSS.
- [ ] 20.8 Test on vintage hardware: verify smooth 60 FPS performance with `QT_QUICK_BACKEND=software`.
- [ ] 20.9 Update `README.md` documentation, architecture diagrams, and quick-start guides.

---

### Step 21: Headless CI/CD, Automated Mock Testing Harness & Benchmarks
- [ ] 21.1 Implement headless test harness with mock Niri socket and virtual D-Bus session bus in `tests/` or `crates/agility-test-harness`.
- [ ] 21.2 Add integration tests verifying all 19 D-Bus endpoints respond within SLA (< 2ms for Launcher, < 4ms for Workspaces).
- [ ] 21.3 Implement automated GitHub Actions CI pipeline running `cargo test`, `cargo clippy --all-targets`, and formatting checks on push.
- [ ] 21.4 Implement automated memory benchmark test asserting `agilityd` idle RSS < 15MB.

---

## 8. Verification Sign-off Criteria

Before declaring the Next-Gen shell ready for production deployment:
1. **Zero Python Dependencies:** The shell starts, runs, locks, and updates without any Python runtime or GTK3 libraries.
2. **Memory Verification:** `ps -o rss,comm -p $(pgrep agilityd) -p $(pgrep quickshell)` reports combined RSS < 40,000 KB.
3. **No Audio or Display Stutter:** Rapid slider manipulation produces zero frame drops on 60Hz and 144Hz monitors.
4. **Security Audit:** Lockscreen cannot be bypassed via Alt+Tab, workspace cycling, or kill signals to child surfaces.
5. **Vintage Hardware Compatibility:** Flawless operation on legacy Intel HD Graphics (i3/i5 2nd-4th Gen) using `QT_QUICK_BACKEND=software`.
