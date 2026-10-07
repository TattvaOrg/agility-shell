# Agility Shell Next-Gen (Rust + QML) — Master Product Requirements Document & Implementation Plan

**Document Version:** 2.0.0  
**Target Architecture:** Rust Core Daemon (`agilityd`) + Quickshell (Qt6 / QML) Wayland Shell  
**Primary Compositor:** Niri (with Extensible Wayland Compositor Trait)  
**Status:** Architecture Approved / Ready for Execution  

---

## 1. What is Agility Shell?

**Agility Shell** is a modern, modular Wayland desktop shell designed to provide an integrated, fluid, and beautiful desktop user experience without desktop bloat. Originally built using Python, GTK3, and Fabric, Agility Shell is transitioning to a **compiled Rust backend daemon paired with a Quickshell (Qt6 / QML) frontend**.

### Core Philosophy
1. **Extreme Efficiency & Low Latency:** Sub-35MB total system footprint, zero garbage collection pauses, and sub-10ms daemon startup.
2. **Vintage & Modern Hardware Parity:** Seamless 60–144Hz performance on modern discrete GPUs, paired with universal CPU software rasterization fallback (`QT_QUICK_BACKEND=software`) for vintage Intel HD Graphics and legacy hardware.
3. **Unified Out-of-the-Box Desktop:** Delivers a complete environment including a modular status bar, interactive control center, fuzzy application launcher, secure PAM lockscreen, desktop suites ("Suits"), and dynamic Material You wallpaper theming.
4. **Declarative & Hackable:** The UI is written in clean, reactive QML with instant hot-reloading during development, while low-level system drivers run safely in compiled Rust.

---

## 2. Architecture Overview & Data Flow

```
+-----------------------------------------------------------------------------------+
|                           WAYLAND COMPOSITOR (Niri)                               |
+--------------------------+------------------------------------+-------------------+
                           | wlr-layer-shell / ext-session-lock | Unix Socket
                           v                                    v
+--------------------------+--------+   D-Bus Signals       +---+-------------------+
|      QUICKSHELL FRONTEND          | <==================== |   RUST DAEMON         |
|         (Qt6 / QML)               | ====================> |   (agilityd)          |
|                                   |    D-Bus Methods      +---+-------------------+
|  - Status Bar & Island Applets    |                           |
|  - Control Center & Sliders       |                           | Native Systems
|  - Fuzzy Search App Launcher      |                           v
|  - Ext-Session-Lock Lockscreen    |               +-----------+-------------------+
|  - Theme.qml (Material You)       |               | - Niri IPC Stream             |
+-----------------------------------+               | - PipeWire / WirePlumber Audio|
                                                    | - UPower & Sysfs Monitors     |
                                                    | - NetworkManager & BlueZ      |
                                                    | - PAM Auth Worker Thread      |
                                                    | - Desktop Entry Indexer       |
                                                    | - Suits Manager (suits.json)  |
                                                    +-------------------------------+
```

### IPC Bridge Contract (`org.agility.Daemon`)
The Rust daemon exposes high-speed, type-safe interfaces on the D-Bus session bus via `zbus`:
- `org.agility.Daemon.Workspaces`: Real-time Niri workspaces, active column, and window focus tracking.
- `org.agility.Daemon.Audio`: PipeWire default speaker/microphone volume and mute states.
- `org.agility.Daemon.Hardware`: CPU %, RAM %, battery percentage, charging state, temperatures, and disk metrics.
- `org.agility.Daemon.Network`: WiFi connection state, active SSID, signal strength, and network toggle.
- `org.agility.Daemon.Bluetooth`: Adapter power state, paired devices, and connection toggles.
- `org.agility.Daemon.Launcher`: Background `.desktop` entry index and sub-millisecond fuzzy query search.
- `org.agility.Daemon.Lock`: Secure worker thread communicating with Linux PAM for authentication.
- `org.agility.Daemon.Theme`: Material You extracted color palette broadcast directly into QML.
- `org.agility.Daemon.Suits`: Desktop mode preset switching, persistent layout profiles, and suite exports.

---

## 3. Target Specifications & Performance KPIs

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

## 4. Master Step-by-Step Implementation Roadmap

Use this checklist to track progress throughout the implementation. Mark items with `[X]` as each step is completed and verified.

---

### Step 1: Workspace Scaffolding & Build System Setup
- [ ] 1.1 Create Cargo workspace configuration in `crates/` with initial package `agilityd`.
- [ ] 1.2 Define dependency manifest in `crates/agilityd/Cargo.toml` (`tokio`, `zbus`, `serde`, `serde_json`, `sysinfo`, `nucleo`, `pam-sys`, `libpulse-binding`, `tracing`).
- [ ] 1.3 Configure release build profile (`lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `strip = true`) for minimal binary size and maximum performance.
- [ ] 1.4 Update root `Makefile` with targets for building and installing `agilityd` (`make build-rust`, `make install-rust`).
- [ ] 1.5 Update `PKGBUILD` to compile the Rust daemon via `cargo build --release` and install to `/usr/bin/agilityd`.
- [ ] 1.6 Verify clean compilation and zero-warning build on Arch Linux.

---

### Step 2: Core Rust Daemon Infrastructure (`agilityd`)
- [ ] 2.1 Implement `main.rs` daemon initialization, structured logging via `tracing-subscriber`, and CLI flags (`--daemon`, `--foreground`, `--test`, `--version`).
- [ ] 2.2 Implement Unix signal handling (`SIGINT`, `SIGTERM`, `SIGHUP`) for graceful daemon shutdown and configuration reloading.
- [ ] 2.3 Establish D-Bus connection on `org.agility.Daemon` using `zbus::connection::Builder::session()`.
- [ ] 2.4 Implement singleton state manager holding in-memory state structs and atomic broadcast channels.
- [ ] 2.5 Verify D-Bus service registration with `busctl --user list | grep org.agility.Daemon`.

---

### Step 3: Niri Compositor IPC Module
- [ ] 3.1 Discover and connect to the active Niri socket via `NIRI_SOCKET` environment variable.
- [ ] 3.2 Implement asynchronous JSON stream reader for Niri event stream (`WorkspacesChanged`, `WorkspaceActivated`, `WindowOpenedOrChanged`, `WindowClosed`, `WindowFocusChanged`).
- [ ] 3.3 Create `NiriClient` trait abstraction allowing future extension to Hyprland and generic wlroots protocols.
- [ ] 3.4 Implement D-Bus interface `org.agility.Daemon.Workspaces` exposing:
  - Properties: `active_workspace` (u32), `workspaces` (JSON array), `focused_window_title` (string), `focused_app_id` (string).
  - Methods: `ActivateWorkspace(u32)`, `CloseFocusedWindow()`.
  - Signals: `WorkspaceChanged(u32)`, `WindowChanged(string)`.
- [ ] 3.5 Test workspace switching latency and event reliability under rapid switching.

---

### Step 4: Hardware & System Telemetry Engine
- [ ] 4.1 Implement asynchronous CPU utilization poller using non-blocking `/proc/stat` delta calculations.
- [ ] 4.2 Implement RAM and swap usage reader from `/proc/meminfo`.
- [ ] 4.3 Implement UPower and `/sys/class/power_supply` battery monitor (percentage, charging state, time to empty/full, health).
- [ ] 4.4 Implement thermal temperature monitor inspecting `/sys/class/thermal/` and `/sys/class/hwmon/`.
- [ ] 4.5 Implement filesystem storage monitor calculating mounted root and home directory usage.
- [ ] 4.6 Expose telemetry via `org.agility.Daemon.Hardware` with configurable polling frequencies (fast: 1s for CPU/RAM, slow: 10s for battery/storage).

---

### Step 5: Audio & Media Service Integration
- [ ] 5.1 Connect to PipeWire / WirePlumber audio daemon via PulseAudio emulation protocol or native PipeWire library.
- [ ] 5.2 Implement reactive volume listener for default audio sink (speakers/headphones) and default source (microphone).
- [ ] 5.3 Expose D-Bus interface `org.agility.Daemon.Audio`:
  - Methods: `SetVolume(f64)`, `AdjustVolume(f64)`, `ToggleMute()`, `SetMicVolume(f64)`, `ToggleMicMute()`.
  - Properties: `volume` (f64), `muted` (bool), `mic_volume` (f64), `mic_muted` (bool).
  - Signals: `VolumeChanged(f64, bool)`.
- [ ] 5.4 Implement MPRIS2 playerctl media controller listening for Spotify, Firefox, MPV metadata and playback controls.

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
- [ ] 7.4 Integrate `nucleo` / `fuzzy-matcher` for fuzzy matching with match scoring and character highlighting.
- [ ] 7.5 Expose D-Bus interface `org.agility.Daemon.Launcher`:
  - Methods: `Query(query_string: string) -> json_results`, `Launch(desktop_id: string)`, `ListAll() -> json_results`.
- [ ] 7.6 Benchmark search response: guarantee < 2ms latency for 500+ installed applications.

---

### Step 8: Desktop Suites ("Suits") & Settings Engine
- [ ] 8.1 Port `suits.json` schema to strongly typed Rust structs with Serde serialization.
- [ ] 8.2 Load, validate, and save suites from `~/.config/agility-shell/config/suits.json`.
- [ ] 8.3 Expose D-Bus interface `org.agility.Daemon.Suits`:
  - Methods: `GetSuits()`, `GetActiveSuite()`, `SwitchSuite(id: string)`, `CycleNextSuite()`, `CyclePrevSuite()`, `ExportSuite(id, path)`, `ImportSuite(path)`.
  - Signals: `SuiteChanged(id: string)`.
- [ ] 8.4 Load base user settings from `~/.config/agility-shell/config/config.json` with fallback defaults.

---

### Step 9: Dynamic Theming Engine (Matugen + Material You)
- [ ] 9.1 Implement wallpaper path listener and setter (compatible with `awww`, `swww`, and static paths).
- [ ] 9.2 Integrate `matugen` invocation or native material-color-utilities palette generator.
- [ ] 9.3 Extract primary, secondary, surface, background, and accent color hex tokens.
- [ ] 9.4 Expose D-Bus interface `org.agility.Daemon.Theme` streaming dynamic theme tokens directly to QML without file writes.
- [ ] 9.5 Provide fallback static color presets (Dark, Light, TokyoNight, Catppuccin, Gruvbox) when wallpaper extraction is disabled.

---

### Step 10: Secure PAM Lockscreen Authentication Worker
- [ ] 10.1 Implement isolated worker thread in `agilityd` wrapping Linux PAM (`libpam`).
- [ ] 10.2 Handle standard conversation functions (`PAM_PROMPT_ECHO_OFF`, `PAM_ERROR_MSG`).
- [ ] 10.3 Expose private D-Bus/Unix socket endpoint for authentication requests:
  - Method: `Authenticate(password: string) -> bool`.
- [ ] 10.4 Implement rate limiting and exponential backoff to prevent brute-force unlock attempts.
- [ ] 10.5 Zero-out password buffers in memory immediately after authentication verification.

---

### Step 11: Quickshell Frontend — Shell Entry & Theme Bridge
- [ ] 11.1 Reorganize `quickshell/agility/` into clean component architecture (`shell.qml`, `Theme.qml`, `bar/`, `controlcenter/`, `launcher/`, `lockscreen/`).
- [ ] 11.2 Implement `Theme.qml` singleton binding reactively to `org.agility.Daemon.Theme` D-Bus properties.
- [ ] 11.3 Support custom font, border radius, and spacing variables inherited from `config.json`.
- [ ] 11.4 Test hot-reloading with `quickshell -p quickshell/agility/shell.qml`.

---

### Step 12: Quickshell Frontend — Modular Status Bar
- [ ] 12.1 Refactor Top Bar in `shell.qml` with Wayland layer-shell anchors (Top, Left, Right) and exclusive zone matching user config height (26px–48px).
- [ ] 12.2 Wire Workspaces widget to `org.agility.Daemon.Workspaces` with active indicator animations.
- [ ] 12.3 Wire Clock widget with customizable format, world clock tooltips, and calendar popup toggle.
- [ ] 12.4 Wire Volume and Brightness widgets with hover wheel adjustments and click-to-mute.
- [ ] 12.5 Wire Battery widget with charging animations and dynamic color thresholds (<20% warning).
- [ ] 12.6 Wire Network & Bluetooth island icons displaying live state indicators.
- [ ] 12.7 Wire Suits switcher widget displaying active desktop mode.

---

### Step 13: Quickshell Frontend — Control Center & Applet Popouts
- [ ] 13.1 Build smooth slide-down Control Center overlay anchored to top-right island.
- [ ] 13.2 Implement interactive sliders for Volume, Mic, and Screen Brightness.
- [ ] 13.3 Implement quick toggle tiles for WiFi, Bluetooth, Do Not Disturb, Night Light, and Performance Profile.
- [ ] 13.4 Integrate existing rich applet widgets (`MediaWidget.qml`, `WeatherWidget.qml`, `ResourceWheelWidget.qml`, `ThermalWidget.qml`).
- [ ] 13.5 Implement outside-click and Escape key auto-dismiss behavior.

---

### Step 14: Quickshell Frontend — Fuzzy Application Launcher & Dash
- [ ] 14.1 Implement centered modal Launcher overlay triggered by `Super` / `Mod` key or CLI.
- [ ] 14.2 Bind search input text field to `org.agility.Daemon.Launcher.Query()`.
- [ ] 14.3 Render list/grid of search results with icons, app titles, and descriptions.
- [ ] 14.4 Implement keyboard navigation (Arrow Up/Down, Enter to launch, Escape to dismiss).
- [ ] 14.5 Implement Quick Actions / Calc mode for arithmetic equations in search box.

---

### Step 15: Quickshell Frontend — Ext-Session-Lock Lockscreen
- [ ] 15.1 Implement Wayland session lock window using Quickshell `WlrSessionLock` / `ext-session-lock-v1`.
- [ ] 15.2 Render blurred background surface, live clock, date, and user avatar.
- [ ] 15.3 Render password input field with secure masked characters.
- [ ] 15.4 Connect password submission to `org.agility.Daemon.Lock.Authenticate()`.
- [ ] 15.5 Implement unlock animation on success and shake error animation on invalid password.
- [ ] 15.6 Ensure screen remains fully locked across monitor connect/disconnect events.

---

### Step 16: CLI Interface (`agl`) & Systemd User Integration
- [ ] 16.1 Rewrite `bin/agl` CLI tool in Rust or streamline bash wrapper to dispatch calls directly to `agilityd` D-Bus interfaces.
- [ ] 16.2 Implement subcommands:
  - `agl start`: Start daemon and Quickshell.
  - `agl stop`: Cleanly stop daemon and Quickshell.
  - `agl restart`: Restart shell surfaces gracefully.
  - `agl status`: Inspect daemon D-Bus health and PID.
  - `agl lock`: Trigger session lockscreen.
  - `agl suits <list|next|prev|switch <id>>`: Manage desktop suites.
  - `agl volume <up|down|mute>`: Audio control.
  - `agl brightness <up|down>`: Backlight control.
- [ ] 16.3 Create systemd user service `agility-shell.service` managing `agilityd` and `quickshell` lifecycles.
- [ ] 16.4 Verify automatic login launch under Niri compositor.

---

### Step 17: Dual-Stack Coexistence & Backward Compatibility
- [ ] 17.1 Implement fallback switch: allow users to launch the legacy Python shell via `agl start --legacy`.
- [ ] 17.2 Ensure existing `~/.config/agility-shell/` user configurations migrate seamlessly without loss of custom user keys.
- [ ] 17.3 Ensure custom stylesheets and wallpaper folders are preserved.

---

### Step 18: Quality Assurance, Benchmarking & Packaging
- [ ] 18.1 Benchmark idle memory on test machines: verify total RAM <= 40 MB RSS.
- [ ] 18.2 Test on vintage hardware: verify smooth 60 FPS performance with `QT_QUICK_BACKEND=software`.
- [ ] 18.3 Test under stress: rapid audio adjustments, multi-monitor hotplugging, lock/unlock cycles.
- [ ] 18.4 Update installer scripts (`install.sh`, `scripts/install.sh`) to build and deploy the Rust daemon and Quickshell frontend.
- [ ] 18.5 Update Arch `PKGBUILD` and verify `makepkg -si` produces a clean, functional pacman package.
- [ ] 18.6 Update `README.md` documentation, architecture diagrams, and quick-start guides.

---

## 5. Verification Sign-off Criteria
Before declaring the Next-Gen shell ready for production deployment:
1. **Zero Python Dependencies:** The shell starts, runs, locks, and updates without any Python runtime installed.
2. **Memory Verification:** `ps -o rss,comm -p $(pgrep agilityd) -p $(pgrep quickshell)` reports combined RSS < 40,000 KB.
3. **No Audio or Display Stutter:** Rapid slider manipulation produces zero frame drops on 60Hz and 144Hz monitors.
4. **Security Audit:** Lockscreen cannot be bypassed via Alt+Tab, workspace cycling, or kill signals to child surfaces.
