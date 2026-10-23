*Agility Shell is a next-generation Wayland desktop shell powered by an ultra-fast Rust daemon (`agilityd`) and a GPU-accelerated Quickshell frontend. Featuring lightweight memory footprint (< 15MB daemon RSS), instant sub-15ms restarts, secure PAM session lock, iconic Doom Melt suite transitions, dual theme engines (Agility Glass & Dynamic Material Theme), animated desktop layout presets, and 100% Rust & QML architecture.*

---

## Key Features

* **Next-Gen Rust Daemon (`agilityd`):** Multithreaded systems core communicating over high-speed D-Bus (`org.agility.Daemon`), delivering sub-2ms launcher responses, sub-4ms workspace switching, and isolated PAM worker threads.
* **Dual Theme Engine:** Switch between Default Glass UI and dynamic Material Design 3 theme with wallpaper-adaptive color schemes.
* **Desktop Layout Presets:** Instant animated switching between 'Full Material Canvas', 'Compact Island', and 'Bottom Waffle Bar' presets, plus custom user arrangements.
* **GPU-Accelerated Quickshell Frontend:** Declarative QML surfaces featuring liquid glass cards, interactive canvas applets with 20px grid-snapping, floating docks, toast notifications, sound effects, and OSD overlays.
* **Low Resource Footprint:** Combined memory under 40 MB RSS (down from 180MB+ in legacy Python), smooth 60 FPS on vintage hardware via `QT_QUICK_BACKEND=software`.
* **Iconic Transitions:** Staggered vertical column Doom Melt screen transitions across monitors when switching desktop suites.
* **Secure Wayland Session Lock:** Native `ext-session-lock-v1` / `WlSessionLock` integration with PAM rate limiting, exponential backoff, and blurred wallpaper backdrop.
* **High-Speed CLI (`agl`):** Lightning-fast command client written in Rust for full system control, sound effects, and status reporting.

---

## Installation & Quick Start

### 1. Check & Install Dependencies (Step-by-Step Doctor)
To test and install every missing dependency one-by-one with interactive prompts:

```bash
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash -s -- --deps
```

### 2. Install Agility Shell (System-Wide)
Once dependencies are satisfied, install Agility Shell into the distributed system directories (`/usr/bin` and `/usr/share`):

```bash
curl -fsSL https://raw.githubusercontent.com/TattvaOrg/agility-shell/main/install.sh | bash
```

> **Fast Prebuilt Install (Default)**: Selecting **Latest Release** (Option 1) directly downloads and installs the official prebuilt binary tarball from GitHub Releases—no local Rust/cargo compilation required. If you prefer compiling from source, select **Compile by yourself** (Option 2) or pass `--from-source`.

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

### 4. Uninstall Agility Shell
To uninstall Agility Shell, use `agl uninstall` or see the [Uninstallation Guide](more.md#uninstallation).

---

## In-Depth Architecture & Reference Guide

For comprehensive documentation, filesystem specifications, CLI command references, and compositor autostart guides, refer to **[more.md](more.md)**:

* **[Architecture Highlights & Performance Targets](more.md#architecture-highlights)**
* **[Filesystem Layout & Architecture ("Where & Why")](more.md#filesystem-layout--architecture-where--why)**
* **[Complete `agl` CLI Command Reference](more.md#cli-management-agl)**
* **[Maintenance Scripts & Wrappers](more.md#maintenance-scripts-scripts)**
* **[Uninstallation Procedures](more.md#uninstallation)**
* **[Configuration & Compositor Autostart (Niri, Hyprland)](more.md#configuration--autostart)**

---

## Controlling Applets (IPC Syntax)

Agility Shell delegates keyboard shortcut assignments to your host window manager. You can toggle applets smoothly via an Inter-Process Communication (IPC) layer using `agl toggle` or D-Bus:

```ini
# Example: Toggle surfaces via agl CLI
Mod+Space { spawn "agl" "toggle" "launcher"; }
Mod+N     { spawn "agl" "toggle" "notifications"; }
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
  node_bar["Adaptive Status Bar<br/>Default Glass & Material Pill Styles"]
  node_controlcenter["Control Center & Quick Settings<br/>Audio, WiFi, BT, Battery, System"]
  node_launcher["App Launcher<br/>Fast Fuzzy Search & Filtering"]
  node_lockscreen["Lockscreen & Auth<br/>PAM & Wallpaper Integration"]
  node_settings["Personalization & Settings<br/>Themes, Material Mode, Presets, Fonts"]
  node_desktop_canvas["Desktop Canvas & Widgets<br/>Clock, System Resources, Media Player, Notes"]
end

node_installer -->|"registers"| node_systemd
node_agl -->|"manages"| node_daemon
node_systemd -->|"launches"| node_startup
node_startup -->|"spawns"| node_daemon
node_startup -->|"executes"| node_shell_qml
node_daemon -->|"D-Bus IPC"| node_shell_qml
node_daemon -->|"D-Bus IPC"| node_agl
node_shell_qml -->|"renders"| node_bar
node_shell_qml -->|"renders"| node_controlcenter
node_shell_qml -->|"renders"| node_launcher
node_shell_qml -->|"renders"| node_lockscreen
node_shell_qml -->|"renders"| node_settings
node_shell_qml -->|"renders"| node_desktop_canvas
click node_agl "https://github.com/TattvaOrg/agility-shell/blob/main/crates/agility-cli"
click node_daemon "https://github.com/TattvaOrg/agility-shell/blob/main/crates/agilityd"
click node_startup "https://github.com/TattvaOrg/agility-shell/blob/main/agility-shell"
click node_installer "https://github.com/TattvaOrg/agility-shell/blob/main/scripts/install.sh"
click node_systemd "https://github.com/TattvaOrg/agility-shell/blob/main/systemd/agility-shell.service"
click node_shell_qml "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/shell.qml"
click node_bar "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/Modules/Bar"
click node_controlcenter "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/Modules/ControlCenter"
click node_launcher "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/Modules/Launcher"
click node_lockscreen "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/Modules/LockScreen"
click node_settings "https://github.com/TattvaOrg/agility-shell/blob/main/quickshell/agility/Modules/Settings"

classDef toneNeutral fill:#f8fafc,stroke:#334155,stroke-width:1.5px,color:#0f172a
classDef toneBlue fill:#dbeafe,stroke:#2563eb,stroke-width:1.5px,color:#172554
classDef toneAmber fill:#fef3c7,stroke:#d97706,stroke-width:1.5px,color:#78350f
classDef toneMint fill:#dcfce7,stroke:#16a34a,stroke-width:1.5px,color:#14532d
classDef toneRose fill:#ffe4e6,stroke:#e11d48,stroke-width:1.5px,color:#881337
classDef toneIndigo fill:#e0e7ff,stroke:#4f46e5,stroke-width:1.5px,color:#312e81
classDef toneTeal fill:#ccfbf1,stroke:#0f766e,stroke-width:1.5px,color:#134e4a
class node_agl,node_startup,node_installer,node_systemd toneBlue
class node_bar,node_controlcenter,node_launcher,node_lockscreen,node_settings,node_desktop_canvas toneAmber
class node_daemon,node_compositor,node_telemetry,node_audio,node_lock_pam,node_notif_server,node_sounds toneMint
class node_shell_qml toneNeutral
```

---

## Contributing & Credits

Contributions are always welcome! Please check the issues tab, follow our descriptive branching workflow, and submit a pull request.

Special thanks and attributions to:
- **[dots-hyprland](https://github.com/end-4/dots-hyprland)**: For the magnificent Material You / Material Design 3 UI concepts, widget designs, and dynamic color styling.
- **[Minflair](https://github.com/t4lentles5/minflair)**: The modular Quickshell QML frontend architecture to use as Agility's new Rust + QML releases.
- **[caffyne-shell](https://github.com/caffyne-org/caffyne-shell)**: For foundational ideas and inspiration and python based desktop shell (Agility's older versions).
