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
    #[serde(default)]
    pub active_preset: String,
    #[serde(default)]
    pub on_primary: String,
    #[serde(default)]
    pub on_surface: String,
    #[serde(default)]
    pub surface_container: String,
    #[serde(default)]
    pub outline: String,
}

impl Default for ThemeTokens {
    fn default() -> Self {
        Self::dark()
    }
}

impl ThemeTokens {
    pub fn dark() -> Self {
        Self {
            is_dark: true,
            primary_color: "#2a98df".to_string(),
            secondary_color: "#8392a3".to_string(),
            surface_color: "#181c20".to_string(),
            background_color: "#0f1113".to_string(),
            accent_colors: vec![
                "#2a98df".to_string(),
                "#50b2fc".to_string(),
                "#94ccff".to_string(),
                "#d2bfe7".to_string(),
            ],
            active_wallpaper: "".to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Dark".to_string(),
            on_primary: "#ffffff".to_string(),
            on_surface: "#e2e2e5".to_string(),
            surface_container: "#272a2e".to_string(),
            outline: "#72787e".to_string(),
        }
    }

    pub fn light() -> Self {
        Self {
            is_dark: false,
            primary_color: "#006398".to_string(),
            secondary_color: "#51606f".to_string(),
            surface_color: "#f1f4f9".to_string(),
            background_color: "#fcfcff".to_string(),
            accent_colors: vec![
                "#006398".to_string(),
                "#007dbe".to_string(),
                "#51606f".to_string(),
                "#67587a".to_string(),
            ],
            active_wallpaper: "".to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Light".to_string(),
            on_primary: "#ffffff".to_string(),
            on_surface: "#1a1c1e".to_string(),
            surface_container: "#e6e8ee".to_string(),
            outline: "#72787e".to_string(),
        }
    }

    pub fn tokyo_night() -> Self {
        Self {
            is_dark: true,
            primary_color: "#7aa2f7".to_string(),
            secondary_color: "#bb9af7".to_string(),
            surface_color: "#1f2335".to_string(),
            background_color: "#1a1b26".to_string(),
            accent_colors: vec![
                "#7aa2f7".to_string(),
                "#bb9af7".to_string(),
                "#7dcfff".to_string(),
                "#f7768e".to_string(),
            ],
            active_wallpaper: "".to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "TokyoNight".to_string(),
            on_primary: "#1a1b26".to_string(),
            on_surface: "#c0caf5".to_string(),
            surface_container: "#24283b".to_string(),
            outline: "#565f89".to_string(),
        }
    }

    pub fn catppuccin() -> Self {
        Self {
            is_dark: true,
            primary_color: "#89b4fa".to_string(),
            secondary_color: "#cba6f7".to_string(),
            surface_color: "#1e1e2e".to_string(),
            background_color: "#181825".to_string(),
            accent_colors: vec![
                "#89b4fa".to_string(),
                "#cba6f7".to_string(),
                "#f38ba8".to_string(),
                "#a6e3a1".to_string(),
            ],
            active_wallpaper: "".to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Catppuccin".to_string(),
            on_primary: "#11111b".to_string(),
            on_surface: "#cdd6f4".to_string(),
            surface_container: "#313244".to_string(),
            outline: "#6c7086".to_string(),
        }
    }

    pub fn gruvbox() -> Self {
        Self {
            is_dark: true,
            primary_color: "#fe8019".to_string(),
            secondary_color: "#fabd2f".to_string(),
            surface_color: "#3c3836".to_string(),
            background_color: "#282828".to_string(),
            accent_colors: vec![
                "#fe8019".to_string(),
                "#fabd2f".to_string(),
                "#b8bb26".to_string(),
                "#83a598".to_string(),
            ],
            active_wallpaper: "".to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Gruvbox".to_string(),
            on_primary: "#282828".to_string(),
            on_surface: "#ebdbb2".to_string(),
            surface_container: "#504945".to_string(),
            outline: "#928374".to_string(),
        }
    }

    pub fn from_preset(name: &str) -> Option<Self> {
        match name.to_lowercase().replace(['-', '_', ' '], "").as_str() {
            "dark" | "defaultdark" => Some(Self::dark()),
            "light" | "defaultlight" => Some(Self::light()),
            "tokyonight" | "tokyo" => Some(Self::tokyo_night()),
            "catppuccin" | "catppuccinmocha" | "mocha" => Some(Self::catppuccin()),
            "gruvbox" | "gruvboxdark" => Some(Self::gruvbox()),
            _ => None,
        }
    }
}

/// Notification urgency levels per Freedesktop spec.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, Default, PartialEq, Eq)]
pub enum NotificationUrgency {
    Low = 0,
    #[default]
    Normal = 1,
    Critical = 2,
}

impl From<u8> for NotificationUrgency {
    fn from(val: u8) -> Self {
        match val {
            0 => Self::Low,
            2 => Self::Critical,
            _ => Self::Normal,
        }
    }
}

/// Action button associated with a notification.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NotificationAction {
    pub key: String,
    pub label: String,
}

/// Persistent notification record stored in history and emitted to UI.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct NotificationItem {
    pub id: u32,
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub actions: Vec<NotificationAction>,
    pub urgency: NotificationUrgency,
    pub timestamp: u64,
    #[serde(default)]
    pub desktop_entry: Option<String>,
    #[serde(default)]
    pub image_path: Option<String>,
    #[serde(default)]
    pub category: Option<String>,
    #[serde(default)]
    pub expire_timeout_ms: i32,
    #[serde(default)]
    pub resident: bool,
    #[serde(default)]
    pub transient: bool,
}

/// Clipboard item entry with preview string and timestamp.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ClipboardItem {
    pub id: u64,
    pub text: String,
    pub preview: String,
    pub timestamp: String,
    pub timestamp_epoch: u64,
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

// ─── Desktop Suites ("Suits") & Settings Schema ───

fn default_true() -> bool {
    true
}

fn default_one_f64() -> f64 {
    1.0
}

fn default_active_id() -> String {
    "desktop-1".to_string()
}

/// Parameters describing the Doom Vertical Melt staggered column animation.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct DoomMeltParams {
    pub duration_ms: u32,
    pub num_columns: u32,
    pub column_delays: Vec<f64>,
    #[serde(default)]
    pub snapshot_path: Option<String>,
}

/// Wallpaper layout and transition settings within a suite or base config.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuiteWallpaperConfig {
    #[serde(default)]
    pub path: String,
    #[serde(default = "default_wallpaper_transition_type")]
    pub transition_type: String,
    #[serde(default = "default_wallpaper_duration")]
    pub transition_duration: f64,
    #[serde(default = "default_wallpaper_speed")]
    pub transition_speed: String,
    #[serde(default = "default_wallpaper_fps")]
    pub transition_fps: u32,
    #[serde(default = "default_enabled_transitions")]
    pub enabled_transitions: Vec<String>,
    #[serde(default)]
    pub custom_transitions: Vec<String>,
    #[serde(default = "default_switcher_style")]
    pub switcher_style: String,
    #[serde(default = "default_true")]
    pub hotkey_animations: bool,
}

fn default_wallpaper_transition_type() -> String {
    "random".to_string()
}
fn default_wallpaper_duration() -> f64 {
    0.7
}
fn default_wallpaper_speed() -> String {
    "quick".to_string()
}
fn default_wallpaper_fps() -> u32 {
    60
}
fn default_enabled_transitions() -> Vec<String> {
    vec![
        "grow".to_string(),
        "wipe".to_string(),
        "wave".to_string(),
        "right".to_string(),
        "outer".to_string(),
    ]
}
fn default_switcher_style() -> String {
    "mesh".to_string()
}

impl Default for SuiteWallpaperConfig {
    fn default() -> Self {
        Self {
            path: "".to_string(),
            transition_type: default_wallpaper_transition_type(),
            transition_duration: default_wallpaper_duration(),
            transition_speed: default_wallpaper_speed(),
            transition_fps: default_wallpaper_fps(),
            enabled_transitions: default_enabled_transitions(),
            custom_transitions: Vec::new(),
            switcher_style: default_switcher_style(),
            hotkey_animations: true,
        }
    }
}

/// Theme preferences within a suite or base config.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuiteThemeConfig {
    #[serde(default = "default_light_theme")]
    pub light_theme: String,
    #[serde(default = "default_dark_theme")]
    pub dark_theme: String,
    #[serde(default = "default_accent")]
    pub active_accent: String,
    #[serde(default = "default_true")]
    pub is_dark: bool,
    #[serde(default = "default_scheme_type")]
    pub scheme_type: String,
    #[serde(default = "default_opacity")]
    pub opacity: f64,
    #[serde(default = "default_border_style")]
    pub border_style: String,
    #[serde(default = "default_font_style")]
    pub font_monospace_style: String,
    #[serde(default)]
    pub font_family: Option<String>,
    #[serde(default)]
    pub font_monospace: Option<String>,
}

fn default_light_theme() -> String {
    "catppuccin-latte".to_string()
}
fn default_dark_theme() -> String {
    "Matugen".to_string()
}
fn default_accent() -> String {
    "accent4".to_string()
}
fn default_scheme_type() -> String {
    "scheme-tonal-spot".to_string()
}
fn default_opacity() -> f64 {
    0.35
}
fn default_border_style() -> String {
    "medium".to_string()
}
fn default_font_style() -> String {
    "none".to_string()
}

impl Default for SuiteThemeConfig {
    fn default() -> Self {
        Self {
            light_theme: default_light_theme(),
            dark_theme: default_dark_theme(),
            active_accent: default_accent(),
            is_dark: true,
            scheme_type: default_scheme_type(),
            opacity: default_opacity(),
            border_style: default_border_style(),
            font_monospace_style: default_font_style(),
            font_family: Some("Inter".to_string()),
            font_monospace: Some("JetBrainsMono Nerd Font".to_string()),
        }
    }
}

/// System and widget behaviors within a suite or base config.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuiteSettingsConfig {
    #[serde(default)]
    pub dnd: bool,
    #[serde(default = "default_true")]
    pub hover_open: bool,
    #[serde(default = "default_hover_delay")]
    pub hover_delay: u64,
    #[serde(default)]
    pub hover_widgets: Vec<String>,
    #[serde(default = "default_bar_theme")]
    pub bar_theme: String,
    #[serde(default = "default_true")]
    pub bar_blur: bool,
    #[serde(default = "default_bar_opacity")]
    pub bar_opacity: f64,
    #[serde(default = "default_widget_opacity")]
    pub widget_opacity: f64,
    #[serde(default = "default_desktop_widget_opacity")]
    pub desktop_widget_opacity: f64,
    #[serde(default = "default_true")]
    pub dash_blur: bool,
    #[serde(default = "default_dash_dim_opacity")]
    pub dash_dim_opacity: f64,
    #[serde(default = "default_one_f64")]
    pub dash_card_opacity: f64,
    #[serde(default = "default_true")]
    pub instant_dash: bool,
    #[serde(default)]
    pub awe_widgets_enabled: bool,
    #[serde(default)]
    pub bluetooth_on_startup: bool,
    #[serde(default = "default_pinned_apps")]
    pub pinned_apps: Vec<String>,
    #[serde(default = "default_transition_mode")]
    pub suits_transition: String,
    #[serde(default = "default_profile")]
    pub agility_profile: String,
    #[serde(default = "default_bar_height")]
    pub bar_height: u32,
}

fn default_hover_delay() -> u64 {
    150
}
fn default_bar_theme() -> String {
    "liquid-glass".to_string()
}
fn default_bar_opacity() -> f64 {
    0.35
}
fn default_widget_opacity() -> f64 {
    0.55
}
fn default_desktop_widget_opacity() -> f64 {
    0.60
}
fn default_dash_dim_opacity() -> f64 {
    0.20
}
fn default_pinned_apps() -> Vec<String> {
    vec![
        "thunar.desktop".to_string(),
        "brave-browser.desktop".to_string(),
        "kitty.desktop".to_string(),
    ]
}
fn default_transition_mode() -> String {
    "fluid".to_string()
}
fn default_profile() -> String {
    "balanced".to_string()
}
fn default_bar_height() -> u32 {
    30
}

impl Default for SuiteSettingsConfig {
    fn default() -> Self {
        Self {
            dnd: false,
            hover_open: true,
            hover_delay: default_hover_delay(),
            hover_widgets: Vec::new(),
            bar_theme: default_bar_theme(),
            bar_blur: true,
            bar_opacity: default_bar_opacity(),
            widget_opacity: default_widget_opacity(),
            desktop_widget_opacity: default_desktop_widget_opacity(),
            dash_blur: true,
            dash_dim_opacity: default_dash_dim_opacity(),
            dash_card_opacity: 1.0,
            instant_dash: true,
            awe_widgets_enabled: false,
            bluetooth_on_startup: false,
            pinned_apps: default_pinned_apps(),
            suits_transition: default_transition_mode(),
            agility_profile: default_profile(),
            bar_height: default_bar_height(),
        }
    }
}

/// Dock configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SuiteDockConfig {
    #[serde(default)]
    pub entries: Vec<serde_json::Value>,
}

/// Launcher configuration.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuiteLauncherConfig {
    #[serde(default)]
    pub grid: bool,
    #[serde(default = "default_keybind_position")]
    pub keybind_position: String,
}

fn default_keybind_position() -> String {
    "center".to_string()
}

impl Default for SuiteLauncherConfig {
    fn default() -> Self {
        Self {
            grid: false,
            keybind_position: default_keybind_position(),
        }
    }
}

/// Template triggers configuration.
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SuiteTemplatesConfig {
    #[serde(default)]
    pub enabled: Vec<String>,
}

/// Complete configuration snapshot for an individual desktop suite.
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct SuiteConfig {
    #[serde(default)]
    pub bars: serde_json::Value,
    #[serde(default)]
    pub desktop_canvas: serde_json::Value,
    #[serde(default)]
    pub desktop_applets: serde_json::Value,
    #[serde(default)]
    pub quickshell_widgets: serde_json::Value,
    #[serde(default)]
    pub wallpaper: SuiteWallpaperConfig,
    #[serde(default)]
    pub theme: SuiteThemeConfig,
    #[serde(default)]
    pub settings: SuiteSettingsConfig,
    #[serde(default)]
    pub dock: SuiteDockConfig,
    #[serde(default)]
    pub launcher: SuiteLauncherConfig,
    #[serde(default)]
    pub templates: SuiteTemplatesConfig,
}

/// Individual desktop suite preset definition.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuitePreset {
    pub id: String,
    #[serde(default)]
    pub name: String,
    #[serde(default)]
    pub description: Option<String>,
    #[serde(default)]
    pub created_at: Option<f64>,
    #[serde(default)]
    pub config: Option<SuiteConfig>,
    #[serde(default)]
    pub theme: Option<String>,
    #[serde(default)]
    pub wallpaper: Option<String>,
}

/// In-memory catalog of all suites and active preset pointer.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SuitsCatalog {
    #[serde(default = "default_active_id")]
    pub active_id: String,
    pub suites: Vec<SuitePreset>,
}

impl Default for SuitsCatalog {
    fn default() -> Self {
        Self {
            active_id: default_active_id(),
            suites: vec![SuitePreset {
                id: "desktop-1".to_string(),
                name: "Desktop 1".to_string(),
                description: Some("Default desktop preset".to_string()),
                created_at: Some(0.0),
                config: Some(SuiteConfig::default()),
                theme: Some("Matugen".to_string()),
                wallpaper: Some("".to_string()),
            }],
        }
    }
}

/// Untagged deserialization helper accepting both `{ "active_id": ..., "suites": [...] }` and `[...]`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum SuitsPayload {
    Catalog(SuitsCatalog),
    List(Vec<SuitePreset>),
}

impl From<SuitsPayload> for SuitsCatalog {
    fn from(payload: SuitsPayload) -> Self {
        match payload {
            SuitsPayload::Catalog(c) => c,
            SuitsPayload::List(list) => {
                let active = list
                    .first()
                    .map(|s| s.id.clone())
                    .unwrap_or_else(default_active_id);
                SuitsCatalog {
                    active_id: active,
                    suites: list,
                }
            }
        }
    }
}

/// User profile section in `config.json`.
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct UserConfig {
    #[serde(default)]
    pub avatar: String,
}

/// Master application configuration (`config.json`).
#[derive(Debug, Clone, Serialize, Deserialize, Default, PartialEq)]
pub struct AppConfig {
    #[serde(default)]
    pub user: UserConfig,
    #[serde(default)]
    pub settings: SuiteSettingsConfig,
    #[serde(default)]
    pub bars: serde_json::Value,
    #[serde(default)]
    pub timeouts: serde_json::Value,
    #[serde(default)]
    pub theme: SuiteThemeConfig,
    #[serde(default)]
    pub launcher: SuiteLauncherConfig,
    #[serde(default)]
    pub dock: SuiteDockConfig,
    #[serde(default)]
    pub world_clocks: serde_json::Value,
    #[serde(default)]
    pub wallpaper: SuiteWallpaperConfig,
    #[serde(default)]
    pub desktop_canvas: serde_json::Value,
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
        std::path::PathBuf::from(home)
            .join(".config")
            .join("agility-shell")
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
        std::path::PathBuf::from(home)
            .join(".cache")
            .join("agility-shell")
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
