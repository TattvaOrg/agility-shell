use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use tracing::{info, warn};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    #[serde(default)]
    pub glow: GlowConfig,
    #[serde(default)]
    pub general: GeneralConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GlowConfig {
    #[serde(default = "default_intensity")]
    pub intensity: f32,
    #[serde(default = "default_thickness")]
    pub thickness_px: u32,
    #[serde(default = "default_corner_radius")]
    pub corner_radius_px: u32,
    #[serde(default = "default_color_mode")]
    pub color_mode: String, // "album" | "solid"
    #[serde(default = "default_solid_color")]
    pub solid_color: String,
    #[serde(default = "default_speed")]
    pub speed: f32,
    #[serde(default = "default_direction")]
    pub direction: String, // "clockwise" | "counter_clockwise"
    #[serde(default = "default_idle_breathing")]
    pub idle_breathing: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct GeneralConfig {
    #[serde(default = "default_fps_cap")]
    pub fps_cap: u32,
}

fn default_intensity() -> f32 {
    0.7
}

fn default_thickness() -> u32 {
    40
}

fn default_corner_radius() -> u32 {
    12
}

fn default_color_mode() -> String {
    "album".to_string()
}

fn default_solid_color() -> String {
    "#FF3B30".to_string()
}

fn default_speed() -> f32 {
    1.0
}

fn default_direction() -> String {
    "clockwise".to_string()
}

fn default_idle_breathing() -> bool {
    true
}

fn default_fps_cap() -> u32 {
    60
}

impl Default for Config {
    fn default() -> Self {
        Self {
            glow: GlowConfig {
                intensity: default_intensity(),
                thickness_px: default_thickness(),
                corner_radius_px: default_corner_radius(),
                color_mode: default_color_mode(),
                solid_color: default_solid_color(),
                speed: default_speed(),
                direction: default_direction(),
                idle_breathing: default_idle_breathing(),
            },
            general: GeneralConfig {
                fps_cap: default_fps_cap(),
            },
        }
    }
}

impl Config {
    pub fn get_config_path() -> PathBuf {
        if let Some(proj_dirs) = directories::ProjectDirs::from("", "", "niri-vibe") {
            proj_dirs.config_dir().join("config.toml")
        } else {
            let home = std::env::var("HOME").unwrap_or_else(|_| ".".to_string());
            PathBuf::from(home)
                .join(".config")
                .join("niri-vibe")
                .join("config.toml")
        }
    }

    pub fn load_or_create(custom_path: Option<&Path>) -> Result<Self> {
        let path = match custom_path {
            Some(p) => p.to_path_buf(),
            None => Self::get_config_path(),
        };

        if path.exists() {
            info!("Loading configuration from {:?}", path);
            let content = fs::read_to_string(&path)?;
            match toml::from_str::<Config>(&content) {
                Ok(cfg) => Ok(cfg),
                Err(err) => {
                    warn!(
                        "Failed to parse config file {:?}: {}. Using default configuration.",
                        path, err
                    );
                    Ok(Config::default())
                }
            }
        } else {
            info!(
                "Configuration file not found. Creating default at {:?}",
                path
            );
            let default_cfg = Config::default();
            if let Some(parent) = path.parent() {
                let _ = fs::create_dir_all(parent);
            }
            let toml_str = toml::to_string_pretty(&default_cfg)?;
            let _ = fs::write(&path, toml_str);
            Ok(default_cfg)
        }
    }
}

pub fn parse_hex_color(hex: &str) -> [f32; 4] {
    let hex = hex.trim().trim_start_matches('#');
    match hex.len() {
        6 => {
            let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(255) as f32 / 255.0;
            let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(59) as f32 / 255.0;
            let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(48) as f32 / 255.0;
            [r, g, b, 1.0]
        }
        8 => {
            let r = u8::from_str_radix(&hex[0..2], 16).unwrap_or(255) as f32 / 255.0;
            let g = u8::from_str_radix(&hex[2..4], 16).unwrap_or(59) as f32 / 255.0;
            let b = u8::from_str_radix(&hex[4..6], 16).unwrap_or(48) as f32 / 255.0;
            let a = u8::from_str_radix(&hex[6..8], 16).unwrap_or(255) as f32 / 255.0;
            [r, g, b, a]
        }
        _ => [1.0, 0.23, 0.188, 1.0], // default "#FF3B30"
    }
}
