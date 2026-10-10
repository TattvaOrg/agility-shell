//! Agility Common Library
//! Shared data structures, D-Bus paths/interfaces, and error types across `agilityd` and `agl`.

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// D-Bus well-known session bus name for Agility Shell.
pub const DBUS_NAME: &str = "org.agility.Daemon";

/// Standard Freedesktop notifications D-Bus name.
pub const DBUS_NOTIFICATIONS_NAME: &str = "org.freedesktop.Notifications";

/// Well-known D-Bus object paths.
pub mod paths {
    pub const WORKSPACES: &str = "/org/agility/Daemon/Workspaces";
    pub const AUDIO: &str = "/org/agility/Daemon/Audio";
    pub const MEDIA: &str = "/org/agility/Daemon/Media";
    pub const HARDWARE: &str = "/org/agility/Daemon/Hardware";
    pub const CONNECTIVITY: &str = "/org/agility/Daemon/Connectivity";
    pub const LAUNCHER: &str = "/org/agility/Daemon/Launcher";
    pub const SUITS: &str = "/org/agility/Daemon/Suits";
    pub const THEME: &str = "/org/agility/Daemon/Theme";
    pub const NOTIFICATIONS: &str = "/org/freedesktop/Notifications";
    pub const CLIPBOARD: &str = "/org/agility/Daemon/Clipboard";
    pub const POWER: &str = "/org/agility/Daemon/Power";
    pub const WEATHER: &str = "/org/agility/Daemon/Weather";
    pub const MEDIA_CAPTURE: &str = "/org/agility/Daemon/MediaCapture";
    pub const LOCK: &str = "/org/agility/Daemon/Lock";
    pub const STATUS_NOTIFIER_WATCHER: &str = "/StatusNotifierWatcher";
    pub const SOUNDS: &str = "/org/agility/Daemon/Sounds";
    pub const TIMER: &str = "/org/agility/Daemon/Timer";
    pub const SYSTEM: &str = "/org/agility/Daemon/System";
    pub const DAEMON: &str = "/org/agility/Daemon";
}

/// Well-known D-Bus interfaces.
pub mod interfaces {
    pub const WORKSPACES: &str = "org.agility.Daemon.Workspaces";
    pub const AUDIO: &str = "org.agility.Daemon.Audio";
    pub const MEDIA: &str = "org.agility.Daemon.Media";
    pub const HARDWARE: &str = "org.agility.Daemon.Hardware";
    pub const CONNECTIVITY: &str = "org.agility.Daemon.Connectivity";
    pub const LAUNCHER: &str = "org.agility.Daemon.Launcher";
    pub const SUITS: &str = "org.agility.Daemon.Suits";
    pub const THEME: &str = "org.agility.Daemon.Theme";
    pub const NOTIFICATIONS: &str = "org.freedesktop.Notifications";
    pub const CLIPBOARD: &str = "org.agility.Daemon.Clipboard";
    pub const POWER: &str = "org.agility.Daemon.Power";
    pub const WEATHER: &str = "org.agility.Daemon.Weather";
    pub const MEDIA_CAPTURE: &str = "org.agility.Daemon.MediaCapture";
    pub const LOCK: &str = "org.agility.Daemon.Lock";
    pub const STATUS_NOTIFIER_WATCHER: &str = "org.kde.StatusNotifierWatcher";
    pub const SOUNDS: &str = "org.agility.Daemon.Sounds";
    pub const TIMER: &str = "org.agility.Daemon.Timer";
    pub const SYSTEM: &str = "org.agility.Daemon.System";
    pub const DAEMON: &str = "org.agility.Daemon";
}

/// Unified error enum for Agility subsystems.
#[derive(Debug, Error)]
pub enum AgilityError {
    #[error("I/O error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Serialization error: {0}")]
    Json(#[from] serde_json::Error),

    #[error("D-Bus error: {0}")]
    Dbus(#[from] zbus::Error),

    #[error("Configuration error: {0}")]
    Config(String),

    #[error("Subsystem failure in {subsystem}: {message}")]
    Subsystem {
        subsystem: &'static str,
        message: String,
    },
}

pub type Result<T> = std::result::Result<T, AgilityError>;

/// Representation of an active workspace.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct WorkspaceInfo {
    pub id: u32,
    pub idx: u32,
    pub name: String,
    pub output: String,
    pub is_active: bool,
    pub window_count: u32,
}

/// Basic power profile options.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "kebab-case")]
pub enum PowerProfile {
    PowerSaver,
    Balanced,
    Performance,
}

/// Material You / Dynamic theme color tokens.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ThemeTokens {
    pub is_dark: bool,
    pub primary_color: String,
    pub secondary_color: String,
    pub surface_color: String,
    pub background_color: String,
    pub accent_colors: Vec<String>,
    pub active_wallpaper: String,
    pub border_radius: u32,
    pub font_family: String,
    pub font_mono: String,
}

/// Daemon runtime status.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DaemonStatus {
    pub pid: u32,
    pub version: String,
    pub uptime_secs: u64,
    pub compositor: String,
    pub config_dir: String,
    pub cache_dir: String,
}

/// Resolve the default configuration directory.
pub fn default_config_dir() -> std::path::PathBuf {
    if let Ok(dir) = std::env::var("AGILITY_CONFIG_DIR") {
        return std::path::PathBuf::from(dir);
    }
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        std::path::PathBuf::from(xdg).join("agility-shell")
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        std::path::PathBuf::from(home).join(".config").join("agility-shell")
    }
}

/// Resolve the default cache directory.
pub fn default_cache_dir() -> std::path::PathBuf {
    if let Ok(dir) = std::env::var("AGILITY_CACHE_DIR") {
        return std::path::PathBuf::from(dir);
    }
    if let Ok(xdg) = std::env::var("XDG_CACHE_HOME") {
        std::path::PathBuf::from(xdg).join("agility-shell")
    } else {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        std::path::PathBuf::from(home).join(".cache").join("agility-shell")
    }
}

/// Default master `config.json` content conforming to Section 4.1 of the PRD.
pub const DEFAULT_CONFIG_JSON: &str = r#"{
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
}"#;

/// Default `suits.json` content conforming to Section 4.2 of the PRD.
pub const DEFAULT_SUITS_JSON: &str = r#"[
  {
    "id": "default",
    "name": "Default",
    "description": "Standard Agility Shell layout with full status bars and dock",
    "theme": "Matugen",
    "wallpaper": ""
  },
  {
    "id": "minimal",
    "name": "Minimal",
    "description": "Compact and clean desktop suite with hidden dock",
    "theme": "catppuccin-latte",
    "wallpaper": ""
  },
  {
    "id": "focused",
    "name": "Focused",
    "description": "Distraction-free productive workflow",
    "theme": "TokyoNight",
    "wallpaper": ""
  }
]"#;

/// Default `widget_settings.json` content.
pub const DEFAULT_WIDGET_SETTINGS_JSON: &str = "{}";

