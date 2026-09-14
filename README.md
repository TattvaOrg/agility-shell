*agility shell is a modern, GTK-based desktop shell built on top of caffyne-shell based on Fabric, Python, and GTK. It features a highly customizable drag-and-drop panel, fluid animations, and deeply integrated system applets designed specifically for modern Wayland compositors.*

---

## Features

* **Modern UI Architecture:** Built with native GTK widgets running smoothly on Wayland.
* **Dynamic Personalization:** Powered by *Matugen* to deliver seamless *Material You* color palettes derived dynamically from your wallpapers.
* **Interactive Control Hub:** 15 pre-built applets covering everything from process management to a quick settings panel.
* **Modular Bar Design:** A highly flexible, drag-and-drop bar structure optimized for flexibility.

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

---

## CLI Management (`agl`)

Agility Shell includes a dedicated command-line interface `agl` installed to `/usr/bin/agl` (or `~/.local/bin/agl`) for easy lifecycle and maintenance management:

```bash
agl <command> [options]
```

| Command | Description | Example |
| :--- | :--- | :--- |
| `agl start` | Launch Agility Shell (or systemd user unit) | `agl start` |
| `agl restart` | Restart running shell gracefully | `agl restart` (or `agl restart -f` for live logs) |
| `agl status` | Check runtime process and service status | `agl status` |
| `agl deps` | Test and install dependencies step-by-step | `agl deps` |
| `agl update` | Update shell in-place while preserving wallpapers & configs | `agl update` |
| `agl uninstall` | Cleanly uninstall Agility Shell | `agl uninstall` (or `agl uninstall --purge`) |
| `agl install` | Run or rerun system installer | `agl install` |
| `agl suits` | Manage desktop suites (switch, list, next, prev) | `agl suits next` |

---

## Maintenance Scripts (`scripts/`)

All lifecycle scripts are organized inside the `scripts/` directory, with root wrappers maintained as backup forwarders for 100% backward compatibility:

| Script | Location | Purpose |
| :--- | :--- | :--- |
| `install.sh` | `scripts/install.sh` | Full system dependency check, venv setup, snippet compilation, and `agl` CLI linking |
| `update.sh` | `scripts/update.sh` | In-place updater preserving user configs and wallpapers |
| `uninstall.sh` | `scripts/uninstall.sh` | Process termination, CLI cleanup, and configurable config removal |
| `start.sh` | `scripts/start.sh` | Activates virtualenv and executes `main.py` |
| `restart.sh` | `scripts/restart.sh` | Cleanly kills existing instances and relaunches in background or foreground |

Root backup scripts (`install.sh`, `update.sh`, `uninstall.sh`, `start.sh`, `restart.sh`) act as transparent forwarders to `scripts/*.sh` so automated curl commands and custom scripts continue working seamlessly.

---

## Configuration & Autostart

To launch agility shell automatically when logging into your compositor session, add the helper script to your compositor configuration:

### Niri (`config.kdl`)
```ini
spawn-at-startup "bash" "-c" "~/.config/agility-shell/start.sh"
```

#### Standard Config (`hyprland.conf`)
```ini
exec-once = ~/.config/agility-shell/start.sh
```

#### Modern Lua Config (`hyprland.lua`)
```lua
-- Add this to your exec or startup table
hyprland.exec_once({ "~/.config/agility-shell/start.sh" })
```

---

## Controlling Applets (IPC Syntax)

agility shell delegates keyboard shortcut assignments to your host window manager. You can toggle applets smoothly via an Inter-Process Communication (IPC) layer using `fabric-cli`:

```ini
# Example: Niri keybindings to toggle widgets
Mod+Space { spawn "fabric-cli" "exec" "agility-shell" "bar_manager.toggle('Launcher')"; }
Mod+N     { spawn "fabric-cli" "exec" "agility-shell" "bar_manager.toggle('Notifications')"; }
```

### Available Applets & Dash Views
You can pass any of these identifier handles into `bar_manager.toggle('<Applet>')`:
* `Dash`, `Launcher`, `Settings`, `Wallpapers`, `Themes`, `Notifications`, `Clock`, `Calendar`, `Weather`, `Media`, `Volume`, `Wifi`, `Bluetooth`, `Energy`, `Session`, `Calculator`, `Keyboard`, `Screenshot`, `Processes`.

---

## Contributing & Credits

Contributions are always welcome! Please check the issues tab, follow our descriptive branching workflow, and submit a pull request.

Special thanks to [caffyne-shell](https://github.com/caffyne-org/caffyne-shell) , `@its-darsh` (Fabric framework), `@Axenide` (backend clients), `@linkfrg` (Ignis runtime inspiration), and `@amansxcalibur` (UI code snippets) for making this project possible.
