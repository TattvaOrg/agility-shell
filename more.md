# Agility Shell — Architecture & Advanced Reference Guide

This document contains detailed architecture notes, filesystem layouts, CLI management commands, maintenance scripts, configuration autostart setups, and uninstallation guides for **Agility Shell**.

---

## Architecture Highlights

* **Next-Gen Rust Daemon (`agilityd`):** Multithreaded systems core communicating over high-speed D-Bus (`org.agility.Daemon`), delivering sub-2ms launcher responses, sub-4ms workspace switching, and isolated PAM worker threads.
* **GPU-Accelerated Quickshell Frontend:** Declarative QML surfaces featuring liquid glass cards, interactive canvas applets with 20px grid-snapping, floating docks, toast notifications, sound effects, and OSD overlays.
* **Dual Theme Engine:** Switch seamlessly between Agility's native Glass UI and dynamic Material Design 3 (wallpaper-adaptive palette) themes with instant animated preset transitions.
* **Low Resource Footprint:** Combined memory under 40 MB RSS (down from 180MB+ in legacy Python), smooth 60 FPS on vintage hardware via `QT_QUICK_BACKEND=software`.
* **Iconic Transitions:** Staggered vertical column Doom Melt screen transitions across monitors when switching desktop suites.
* **Secure Wayland Session Lock:** Native `ext-session-lock-v1` / `WlSessionLock` integration with PAM rate limiting, exponential backoff, and blurred wallpaper backdrop.
* **High-Speed CLI (`agl`):** Lightning-fast command client written in Rust for full system control, sound effects, and status reporting.
* **Pure Rust & QML:** 100% free of Python runtime dependencies. All services, widgets, and applets run on native Rust and high-performance QML.

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

## Uninstallation

To completely remove Agility Shell from your system (including running services, system binaries, desktop entries, sudoers charge limit rules, compositor includes, and matugen templates):

### One-Liner Removal (Remote)
```bash
# Standard interactive uninstallation:
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/uninstall.sh | bash

# Complete purge (removes ~/.config/agility-shell, state, and caches without confirmation):
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/uninstall.sh | bash -s -- --purge
```

### CLI or Local Repository
```bash
# Using CLI
agl uninstall
agl uninstall --purge

# Using in-tree / local script
./uninstall.sh
./uninstall.sh --purge
```

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
