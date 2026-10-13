*Agility Shell is a next-generation Wayland desktop shell powered by an ultra-fast Rust daemon (`agilityd`) and a GPU-accelerated Quickshell frontend. Featuring lightweight memory footprint (< 15MB daemon RSS), instant sub-15ms restarts, secure PAM session lock, iconic Doom Melt suite transitions, and 100% Rust & QML architecture.*

---

## Architecture Highlights

* **Next-Gen Rust Daemon (`agilityd`):** Multithreaded systems core communicating over high-speed D-Bus (`org.agility.Daemon`), delivering sub-2ms launcher responses, sub-4ms workspace switching, and isolated PAM worker threads.
* **GPU-Accelerated Quickshell Frontend:** Declarative QML surfaces featuring liquid glass cards, interactive canvas applets with 20px grid-snapping, floating docks, toast notifications, sound effects, and OSD overlays.
* **Low Resource Footprint:** Combined memory under 40 MB RSS (down from 180MB+ in legacy Python), smooth 60 FPS on vintage hardware via `QT_QUICK_BACKEND=software`.
* **Iconic Transitions:** Staggered vertical column Doom Melt screen transitions across monitors when switching desktop suites.
* **Secure Wayland Session Lock:** Native `ext-session-lock-v1` / `WlSessionLock` integration with PAM rate limiting, exponential backoff, and blurred wallpaper backdrop.
* **High-Speed CLI (`agl`):** Lightning-fast command client written in Rust for full system control, sound effects, and status reporting.
* **Pure Rust & QML:** 100% free of Python runtime dependencies. All services, widgets, and applets run on native Rust and high-performance QML.

---

## Supported Window Managers

While agility shell does not manage window configurations itself, it connects natively to the following Wayland compositors:

| Window Manager | Status |
| -------------- | ------ |
| **Niri**       | Stable |
| **Hyprland**   | Beta   |
| **MangoWM**    | Beta   |

---

## Installation & Quick Start

### 1. Check & Install Dependencies (Step-by-Step Doctor)
To test and install every missing dependency one-by-one with interactive prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash -s -- --deps
```

### 2. Install Agility Shell (System-Wide)
Once dependencies are satisfied, install Agility Shell into the distributed system directories (`/usr/share` and `/usr/lib`):

```bash
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash
```

>[!NOTE]
>The installer automatically scans `~/.config/agility-shell` for any old monolithic shell installations, removes old source files and venvs, and safely migrates your custom configs, themes, wallpapers, and styles to the new clean config directory.

### 3. Update Agility Shell (One-Liner Delta Update)
To update Agility Shell without re-cloning the entire repository:

```bash
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/update.sh | bash
```

> **Channel Selection**: The updater interactively asks whether to update to the **Latest Release** (stable tag) or the bleeding-edge **`main` branch**. It reuses the persistent local repository cache (`~/.cache/agility-shell/repo`), downloads only new commits/deltas instead of full re-clones, compiles updated snippets, and preserves all user configurations (`config.json`, `suits.json`, `style/`, `wallpapers/`).
>
> **Direct Channel Flags**:
> - Update to Latest Release: `curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/update.sh | bash -s -- --release`
> - Update to Bleeding-Edge Main: `curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/update.sh | bash -s -- --main`
> - Or directly from terminal: `agl update`

---

## Filesystem Layout & Architecture ("Where & Why")

Agility Shell follows standard Linux Filesystem Hierarchy Standards (FHS) and XDG base directory specifications to keep application code, dependencies, user data, and runtime logs cleanly decoupled.

| Location | Component | Purpose & Why It Lives Here |
| :--- | :--- | :--- |
| **`/usr/bin/`** or **`~/.local/bin/`** | `agl`<br>`agilityd`<br>`agility-shell` | **Executables & CLI**: Accessible directly from `$PATH`. `agilityd` is the background daemon, `agl` manages commands and metrics, and `agility-shell` launches the frontend session. |
| **`/usr/share/agility-shell/`** | Core Application QML & Assets | **Immutable Code & Assets**: Contains Quickshell QML files, sounds, SVGs, themes, and baseline configs. System updates upgrade the code without touching user settings. |
| **`~/.config/agility-shell/`** | User Configuration & Customizations | **Personal Settings**: Stores `config.json` (bar layout, widget ordering), `suits.json` (desktop presets), `wallpapers/`, and `config/niri.kdl`. Never overwritten by updates. |
| **`~/.config/systemd/user/`** | `agility-shell.service` | **Process Lifecycle & Autostart**: Systemd user unit tied to `graphical-session.target`. Provides automatic login startup, automatic crash recovery (`Restart=on-failure`), and unified log management. |
| **`~/.cache/agility-shell/`** | `shell.log` & Image Caches | **Ephemeral State & Logs**: Stores live session logs (`shell.log`), blurred wallpaper buffers, and temporary thumbnails. |

### Why This Separation Matters:
1. **Clean Updates**: Upgrading Agility Shell replaces only `/usr/share/` and `/usr/lib/`; your personal themes, suits, and bar layouts in `~/.config/agility-shell` remain untouched.
2. **Crash Resilience**: Systemd service management guarantees that if the compositor reloads or an applet hiccups, Agility Shell restarts automatically in the background.
3. **Multi-Environment Support**: The launcher automatically favors a local development checkout if run from a git clone, or falls back to system files when executed via systemd or CLI.

---

## CLI Management (`agl`)

Agility Shell includes a dedicated command-line interface `agl` installed to `/usr/bin/agl` (or `~/.local/bin/agl`) for easy lifecycle and maintenance management:

```bash
agl <command> [options]
```

| Command | Description | Example |
| :--- | :--- | :--- |
| `agl start` | Launch Agility Shell Next-Gen | `agl start` |
| `agl stop` | Cleanly stop daemon and Quickshell | `agl stop` |
| `agl restart` | Gracefully restart UI surfaces and daemon in < 15ms | `agl restart` |
| `agl status` | Inspect daemon PID, Quickshell PID, RSS memory, and D-Bus status | `agl status` |
| `agl lock` | Trigger exclusive Wayland session lockscreen | `agl lock` |
| `agl toggle <target>` | Toggle overlay surface (`launcher`, `notifications`, `canvas`, `suits`, etc.) | `agl toggle launcher` |
| `agl profile <action>` | Set or get system power profile (`balanced`, `performance`, `power-saver`, `get`) | `agl profile performance` |
| `agl suits <subcommand>` | Manage desktop suites (`list`, `next`, `prev`, `switch <id>`) | `agl suits next` |
| `agl bar <subcommand>` | Dynamically adjust status bar thickness (`height <26-48>`) or width mode | `agl bar height 36` |
| `agl bar-data` | Output instant status bar JSON metric snapshot | `agl bar-data` |
| `agl sound <action>` | Sound effects dispatcher (`list`, `play <name>`) | `agl sound play session-start` |
| `agl volume <action>` | Audio volume control (`up`, `down`, `mute` with optional step) | `agl volume up 5` |
| `agl brightness <action>`| Display backlight control (`up`, `down` with optional step) | `agl brightness up 10` |
| `agl screenshot <mode>` | Trigger screenshot capture (`full`, `window`, `region`) | `agl screenshot region` |
| `agl record <action>` | Screen recording management (`start [--with-audio]`, `stop`) | `agl record start --with-audio` |
| `agl caffeine` | Toggle Caffeine idle inhibitor state | `agl caffeine` |
| `agl deps` | Verify system runtime and compositor dependencies | `agl deps` |
| `agl update` | Check upstream repository and update Agility Shell | `agl update` |

### Vintage Hardware & Software Rendering
On machines without hardware Vulkan/OpenGL acceleration, run Quickshell with software rasterization for smooth 60 FPS performance:
```bash
QT_QUICK_BACKEND=software agl start
```

---

## Maintenance Scripts (`scripts/`)

All lifecycle scripts are organized inside the `scripts/` directory, with root wrappers maintained as backup forwarders for 100% backward compatibility:

| Script | Location | Purpose |
| :--- | :--- | :--- |
| `install.sh` | `scripts/install.sh` | Full system dependency check, Rust build, and system installation |
| `update.sh` | `scripts/update.sh` | In-place updater preserving user configs and wallpapers |
| `uninstall.sh` | `scripts/uninstall.sh` | Process termination, CLI cleanup, and configurable config removal |
| `start.sh` | `scripts/start.sh` | Launches Agility Shell via `agl start` or direct binary |
| `restart.sh` | `scripts/restart.sh` | Cleanly kills existing instances and relaunches in < 15ms |

Root backup scripts (`install.sh`, `update.sh`, `uninstall.sh`, `start.sh`, `restart.sh`) act as transparent forwarders to `scripts/*.sh` so automated curl commands and custom scripts continue working seamlessly.

---

## Configuration & Autostart

Agility Shell can be managed via the systemd user service (recommended) or started directly by your Wayland compositor:

### 1. Systemd User Service (Recommended)
Agility Shell automatically enables its user service upon installation:
```bash
systemctl --user enable --now agility-shell.service
```

### 2. Compositor Integration (Guarded Fallback)
To ensure the shell is running while avoiding duplicate instances if systemd is already active, use the guarded launcher command:

#### Niri (`config.kdl`)
```kdl
include "~/.config/agility-shell/config/niri.kdl"
# Or standalone:
spawn-at-startup "bash" "-c" "systemctl --user is-active --quiet agility-shell.service || exec agility-shell"
```

#### Hyprland (`hyprland.conf`)
```ini
exec-once = systemctl --user is-active --quiet agility-shell.service || agility-shell
```

#### Modern Lua Config (`hyprland.lua`)
```lua
-- Add this to your exec or startup table
hyprland.exec_once({ "systemctl --user is-active --quiet agility-shell.service || agility-shell" })
```

---

## Controlling Applets (IPC Syntax)

agility shell delegates keyboard shortcut assignments to your host window manager. You can toggle applets smoothly via an Inter-Process Communication (IPC) layer using `fabric-cli`:

```ini
# Example: Niri keybindings to toggle widgets
Mod+Space { spawn "fabric-cli" "exec" "agility-shell" "bar_manager.toggle('Launcher')"; }
Mod+N     { spawn "fabric-cli" "exec" "agility-shell" "bar_manager.toggle('Notifications')"; }
```

```mermaid
flowchart TD

subgraph group_lifecycle["Lifecycle & Management"]
  node_agl{{"agl CLI<br/>Rust CLI binary"}}
  node_startup["Launcher script<br/>agility-shell"]
  node_installer["Installer & Updater<br/>scripts/install.sh"]
  node_systemd["Systemd user service<br/>agility-shell.service"]
end

subgraph group_daemon["Rust Daemon Core (agilityd)"]
  node_daemon["agilityd Systems Core<br/>19 D-Bus interfaces<br/>[org.agility.Daemon]"]
  node_compositor["Compositor IPC<br/>Niri / Hyprland / Sway"]
  node_telemetry["Telemetry & Metrics<br/>Procfs / Hardware"]
  node_audio["Audio & Media<br/>PipeWire / MPRIS2"]
  node_lock_pam["PAM Lock Worker<br/>ext-session-lock-v1"]
  node_notif_server["Notification Server<br/>org.freedesktop.Notifications"]
  node_sounds["Sound Engine<br/>org.agility.Daemon.Sounds"]
end

subgraph group_frontend["Quickshell QML Frontend"]
  node_shell_qml["Quickshell runtime<br/>shell.qml"]
  node_bar["Multi-monitor Status Bar<br/>25+ Glass Widgets"]
  node_dock["Floating Dock<br/>Parabolic Zoom"]
  node_popouts["Control Center & Popouts<br/>Audio, WiFi, BT, Session"]
  node_canvas["Desktop Canvas<br/>23 Interactive Applets"]
  node_lockscreen["Lockscreen Window<br/>Doom Melt Transition"]
  node_launcher["Modal Launcher & OSD<br/>Sub-2ms Fuzzy Search"]
end

node_installer -->|"registers"| node_systemd
node_agl -->|"manages"| node_daemon
node_systemd -->|"launches"| node_startup
node_startup -->|"spawns"| node_daemon
node_startup -->|"executes"| node_shell_qml
node_daemon -->|"D-Bus IPC"| node_shell_qml
node_daemon -->|"D-Bus IPC"| node_agl
node_shell_qml -->|"renders"| node_bar
node_shell_qml -->|"renders"| node_dock
node_shell_qml -->|"renders"| node_popouts
node_shell_qml -->|"renders"| node_canvas
node_shell_qml -->|"renders"| node_lockscreen
node_shell_qml -->|"renders"| node_launcher
click node_agl "https://github.com/TattvaOrg/agility-shell/blob/main/crates/agility-cli"
click node_daemon "https://github.com/TattvaOrg/agility-shell/blob/main/crates/agilityd"
click node_startup "https://github.com/TattvaOrg/agility-shell/blob/main/agility-shell"
click node_installer "https://github.com/TattvaOrg/agility-shell/blob/main/scripts/install.sh"
click node_systemd "https://github.com/TattvaOrg/agility-shell/blob/main/systemd/agility-shell.service"
click node_shell_qml "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/shell.qml"
click node_bar "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/bar/BarWindow.qml"
click node_dock "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/dock/DockWindow.qml"
click node_popouts "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/popouts/ControlCenter.qml"
click node_canvas "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/canvas/DesktopCanvas.qml"
click node_lockscreen "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/lockscreen/LockWindow.qml"
click node_launcher "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/launcher/LauncherWindow.qml"

classDef toneNeutral fill:#f8fafc,stroke:#334155,stroke-width:1.5px,color:#0f172a
classDef toneBlue fill:#dbeafe,stroke:#2563eb,stroke-width:1.5px,color:#172554
classDef toneAmber fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
classDef toneMint fill:#dcfce7,stroke:#16a34a,stroke-width:1.5px,color:#14532d
classDef toneRose fill:#ffe4e6,stroke:#e11d48,stroke-width:1.5px,color:#881337
classDef toneIndigo fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
classDef toneTeal fill:#ccfbf1,stroke:#0f766e,stroke-width:1.5px,color:#134e4a
class node_agl,node_startup,node_installer,node_systemd toneBlue
class node_main,node_bar,node_bar_widgets,node_dock_state,node_quick_settings,node_dash,node_notifications toneAmber
class node_shell_services,node_player,node_network,node_notification_store toneMint
class node_wm_base,node_wm_adapters toneRose
class node_wallpaper_theme,node_styles,node_native_effects toneIndigo
class node_quickshell toneNeutral
```

---

## Contributing & Credits

Contributions are always welcome! Please check the issues tab, follow our descriptive branching workflow, and submit a pull request.

Special thanks to [caffyne-shell](https://github.com/caffyne-org/caffyne-shell) , `@its-darsh` (Fabric framework), `@Axenide` (backend clients), `@linkfrg` (Ignis runtime inspiration), and `@amansxcalibur` (UI code snippets) for making this project possible.
