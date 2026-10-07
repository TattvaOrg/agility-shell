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
