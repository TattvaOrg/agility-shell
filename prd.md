# Product Requirements Document (PRD): Agility Shell Next-Gen (Rust + QML)

**Version:** 1.0.0  
**Status:** Approved / Draft Architecture  
**Target Branch:** `rust-rewrite`  
**Architecture:** Rust Core Daemon (`agilityd`) + Quickshell (Qt6 / QML) Wayland Frontend  

---

## 1. Executive Summary

Agility Shell is transitioning its underlying systems architecture from the legacy **Python + Fabric + GTK3** stack to a high-performance **Rust Backend Daemon (`agilityd`) paired with a Quickshell (Qt6 / QML) Wayland Frontend**.

This architectural pivot directly solves the resource limitations on older hardware (eliminating the Python VM, GObject type overhead, GC pauses, and virtual environment packaging woes), while taking advantage of Agility Shell's existing collection of 25+ rich QML desktop widgets already developed in `quickshell/agility/`.

---

## 2. Problem Statement & Motivation

### 2.1 The Bottlenecks of Python + GTK3/Fabric
- **Memory Footprint:** Python VM, PyGObject, and GTK3 GType tables consume **~180 MB – 320 MB RSS** at idle.
- **Startup Latency:** Python bytecode loading, cffi initialization, and dynamic PAM bindings take **1.5s – 2.5s** to initialize.
- **Event Jitter & GC:** Python's Global Interpreter Lock (GIL) and Garbage Collector introduce micro-stutters during rapid hardware events (e.g. volume adjustment, audio visualizers, and workspace switching).
- **Virtualenv & Packaging Fragility:** System upgrades from Python 3.13 to 3.14 break compiled C-extensions and venv symlinks, requiring re-provisioning.

### 2.2 Why Not Pure-Rust UI Engines (e.g., Amane)?
- **Hardware Incompatibility:** Frameworks like Amane rely exclusively on **Vello + wgpu (Vulkan Compute Shaders)**. Older hardware (pre-Skylake Intel HD Graphics, legacy AMD/Nvidia GPUs) lacks Vulkan 1.2 compute shader support, forcing `wgpu` into `llvmpipe` (CPU software Vulkan) which consumes **80%–100% CPU**.
- **Styling Overhead:** Amane (v0.1.1 experimental) lacks a runtime styling engine. Every border, margin, and color must be statically written in Rust structs and recompiled.

### 2.3 The Solution: Rust Core Daemon + Quickshell / QML
- **Rust Core (`agilityd`):** Handles all low-level hardware polling, sysfs, Niri IPC, WirePlumber/PipeWire audio, NetworkManager, and D-Bus services. Consumes **< 15 MB RSS**, starts in **< 10ms**, and has zero garbage collection.
- **Quickshell (Qt6 / QML):** Renders Wayland `wlr-layer-shell` surfaces with fluid declarative animations. It natively supports hardware acceleration (OpenGL / Vulkan) while providing a robust CPU software rasterizer fallback (`QT_QUICK_BACKEND=software`) that runs seamlessly on vintage hardware.

---

## 3. Goals and Non-Goals

### 3.1 Primary Goals
1. **Sub-35MB Total Idle Memory:** Daemon (<15 MB) + Quickshell frontend (<25 MB) combined.
2. **Instantaneous Startup:** Daemon ready in <15ms; Wayland surfaces presented in <150ms.
3. **Vintage Hardware Support:** Smooth 60 FPS performance on vintage dual-core laptops and legacy integrated GPUs.
4. **Seamless IPC:** Native D-Bus Session interface (`org.agility.Daemon`) allowing Quickshell, CLI (`agl`), and third-party scripts to reactively observe and control shell state.
5. **Preserved Widget Riches:** Re-use and polish the existing 25+ widgets in `quickshell/agility/`.

### 3.2 Non-Goals (Phase 1)
- Full immediate deprecation of the Python lockscreen and desktop suites in Phase 1 (they will remain operational via the Python fallback until Phase 2/3).
- Rewriting third-party compositor protocols (we integrate directly with `niri` IPC and `wlr-layer-shell`).

---

## 4. System Architecture

```
+-------------------------------------------------------------------------+
|                        WAYLAND COMPOSITOR (Niri)                        |
+--------------------+------------------------------------+---------------+
                     | wlr-layer-shell                    | Unix Socket
                     v                                    v
+--------------------+--------------+   D-Bus Signals   +-+---------------+
|        QUICKSHELL FRONTEND        | <================ |  RUST DAEMON    |
|             (Qt6 / QML)           | =================>|  (agilityd)     |
|                                   |    D-Bus Calls    +---+-------------+
|  - Top Bar (Workspaces, Clock)    |                       |
|  - Control Center / Sliders       |                       | Native Drivers
|  - 25+ Agile Applet Widgets       |                       v
|  - Matugen Dynamic Theme Engine   |       +---------------+-------------+
+-----------------------------------+       | Sysfs / UPower / NetManager |
                                            | PipeWire / WirePlumber Audio|
                                            | Niri IPC Workspaces Monitor |
                                            +-----------------------------+
```

### 4.1 Communication Protocol (D-Bus)
The Rust daemon registers the well-known bus name `org.agility.Daemon` on the session bus.

#### Interfaces:
1. **`org.agility.Daemon.Workspaces`**
   - Properties: `active_workspace` (u32), `workspaces` (array of objects), `active_window_title` (string).
   - Signals: `WorkspaceChanged(u32)`, `WindowFocused(string)`.
   - Methods: `SwitchWorkspace(u32)`.

2. **`org.agility.Daemon.Audio`**
   - Properties: `speaker_volume` (f64), `speaker_muted` (bool), `mic_volume` (f64), `mic_muted` (bool).
   - Signals: `VolumeChanged(string, f64, bool)`.
   - Methods: `SetVolume(string, f64)`, `ToggleMute(string)`.

3. **`org.agility.Daemon.Hardware`**
   - Properties: `cpu_percent` (f64), `ram_percent` (f64), `battery_percent` (u32), `battery_charging` (bool), `thermal_temp` (f64).
   - Signals: `HardwareUpdated()`.

4. **`org.agility.Daemon.Network`**
   - Properties: `connected` (bool), `ssid` (string), `signal_strength` (u32).
   - Methods: `Scan()`, `Connect(string, string)`.

---

## 5. Technical Stack

| Layer | Component | Technology | Rationale |
| :--- | :--- | :--- | :--- |
| **Backend Engine** | Daemon Binary | Rust 2024 Edition (`cargo`) | Maximum throughput, zero GC, minimal memory. |
| **D-Bus Server** | IPC Subsystem | `zbus` (v5) | Asynchronous, type-safe Rust D-Bus implementation. |
| **Compositor IPC** | Niri Client | Async Unix Domain Socket / JSON | Native JSON stream parsing for real-time workspace tracking. |
| **System Metrics** | Hardware Monitors | `sysinfo` / direct `/sys` & `/proc` | Zero-overhead kernel sysfs parsing without external tools. |
| **Audio Backend** | Audio Control | `libpulse-binding` / native WirePlumber | Direct connection to default sink/source. |
| **UI Presentation** | Wayland Shell | Quickshell (Qt6 QML) | Native Wayland layer-shell with smooth declarative layout. |
| **Rendering** | Graphic Rasterizer | Qt Quick Scene Graph | GPU-accelerated by default; `QT_QUICK_BACKEND=software` fallback. |

---

## 6. Phase-by-Phase Roadmap

### Phase 1: Core Shell MVP
- [ ] Initialize `crates/agilityd` Rust workspace.
- [ ] Implement `zbus` D-Bus interfaces for Workspaces (Niri IPC), Audio (PipeWire/WirePlumber), and Hardware metrics (Sysfs).
- [ ] Adapt `quickshell/agility/shell.qml` and the Top Bar to bind directly to `org.agility.Daemon`.
- [ ] Test and benchmark idle RAM and CPU usage on both modern and legacy hardware.

### Phase 2: Control Center & Applets Integration
- [ ] Connect Volume and Brightness sliders to D-Bus methods.
- [ ] Implement NetworkManager and BlueZ listeners in `agilityd`.
- [ ] Wire up existing QML widgets (`BatteryWidget.qml`, `VolumeBrightnessWidget.qml`, `NetworkWidget.qml`, `CalendarWidget.qml`).

### Phase 3: Dynamic Theming & Configuration
- [ ] Port Matugen color token generation to trigger dynamic QML palette updates.
- [ ] Expose user preferences in `~/.config/agility-shell/config/config.json` via D-Bus configuration properties.

### Phase 4: Lockscreen, App Launcher & Desktop Suites
- [ ] Implement native PAM authentication worker thread in `agilityd`.
- [ ] Expose desktop suite management (`suits`) via D-Bus.
- [ ] Complete replacement of Python shell processes.

---

## 7. Migration & Compatibility Strategy

1. **Dual-Stack Coexistence:**
   During Phase 1, `agility-shell` CLI (`agl`) will allow running either:
   - `agl start --legacy`: Boots the stable Python GTK3 shell.
   - `agl start --next`: Boots the Rust daemon + Quickshell QML shell.
2. **Configuration Continuity:**
   The user configuration files (`~/.config/agility-shell/config/config.json`) will be read by `agilityd`, preserving user keybindings and settings.
3. **Packaging:**
   The Arch PKGBUILD will compile the single `agilityd` binary with `cargo build --release` and install Quickshell QML assets to `/usr/share/agility-shell/qml/`, removing the Python virtualenv entirely.

---

## 8. Verification & Performance KPIs

| KPI | Target Metric | Verification Method |
| :--- | :--- | :--- |
| **Idle RAM (Daemon)** | **< 15 MB RSS** | `ps -o rss,comm -p $(pgrep agilityd)` |
| **Idle RAM (Quickshell)** | **< 30 MB RSS** | `ps -o rss,comm -p $(pgrep quickshell)` |
| **Daemon Startup Time** | **< 20 ms** | `hyperfine --warmup 3 'agilityd --test'` |
| **Vintage GPU Compatibility** | **Zero crash / 60 FPS** | Tested with `QT_QUICK_BACKEND=software` on legacy hardware |
| **Workspace Switch Latency** | **< 5 ms** | End-to-end Niri IPC event to QML active indicator update |
