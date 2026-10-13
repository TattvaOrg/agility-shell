//! Singleton state manager and configuration persistence for `agilityd`.

use agility_common::{
    default_cache_dir, default_config_dir, DaemonStatus, DEFAULT_CONFIG_JSON, DEFAULT_SUITS_JSON,
    DEFAULT_WIDGET_SETTINGS_JSON,
};
use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, RwLock};
use std::time::Instant;
use tokio::sync::broadcast;
use tracing::{info, warn};

/// System events broadcast across daemon subsystems.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SystemEvent {
    ConfigReloaded,
    ShutdownInitiated,
    Custom(String),
}

/// Global singleton state for `agilityd`.
pub struct DaemonState {
    pub config_dir: PathBuf,
    pub cache_dir: PathBuf,
    pub start_time: Instant,
    reload_tx: broadcast::Sender<()>,
    shutdown_tx: broadcast::Sender<()>,
    event_tx: broadcast::Sender<SystemEvent>,
    config_json: RwLock<String>,
    suits_json: RwLock<String>,
    widget_settings_json: RwLock<String>,
}

impl DaemonState {
    /// Initialize a new state container with default or custom directory paths.
    pub fn new(custom_config_dir: Option<PathBuf>, custom_cache_dir: Option<PathBuf>) -> Arc<Self> {
        let config_dir = custom_config_dir.unwrap_or_else(default_config_dir);
        let cache_dir = custom_cache_dir.unwrap_or_else(default_cache_dir);

        let (reload_tx, _) = broadcast::channel(32);
        let (shutdown_tx, _) = broadcast::channel(16);
        let (event_tx, _) = broadcast::channel(128);

        Arc::new(Self {
            config_dir,
            cache_dir,
            start_time: Instant::now(),
            reload_tx,
            shutdown_tx,
            event_tx,
            config_json: RwLock::new(DEFAULT_CONFIG_JSON.to_string()),
            suits_json: RwLock::new(DEFAULT_SUITS_JSON.to_string()),
            widget_settings_json: RwLock::new(DEFAULT_WIDGET_SETTINGS_JSON.to_string()),
        })
    }

    /// Seed and validate configuration and cache directories on disk.
    pub fn seed_and_validate_directories(&self) -> Result<()> {
        info!(
            "Seeding and validating config directory: {:?}",
            self.config_dir
        );
        info!(
            "Seeding and validating cache directory: {:?}",
            self.cache_dir
        );

        // Ensure primary directories exist
        let config_subdirs = [
            self.config_dir.clone(),
            self.config_dir.join("config"),
            self.config_dir.join("custom_style"),
            self.config_dir.join("wallpapers"),
        ];

        for dir in &config_subdirs {
            fs::create_dir_all(dir)
                .with_context(|| format!("Failed to create configuration directory: {dir:?}"))?;
        }

        let cache_subdirs = [
            self.cache_dir.clone(),
            self.cache_dir.join("weather"),
            self.cache_dir.join("notifications"),
        ];

        for dir in &cache_subdirs {
            fs::create_dir_all(dir)
                .with_context(|| format!("Failed to create cache directory: {dir:?}"))?;
        }

        // Seed config.json
        let config_file = self.config_dir.join("config").join("config.json");
        if !config_file.exists() {
            info!("Writing default configuration to {:?}", config_file);
            fs::write(&config_file, DEFAULT_CONFIG_JSON)
                .with_context(|| format!("Failed to write default config to {config_file:?}"))?;
        }

        // Seed suits.json
        let suits_file = self.config_dir.join("config").join("suits.json");
        if !suits_file.exists() {
            info!("Writing default suites preset to {:?}", suits_file);
            fs::write(&suits_file, DEFAULT_SUITS_JSON)
                .with_context(|| format!("Failed to write default suits to {suits_file:?}"))?;
        }

        // Seed widget_settings.json
        let widget_settings_file = self.config_dir.join("widget_settings.json");
        if !widget_settings_file.exists() {
            info!(
                "Writing default widget settings to {:?}",
                widget_settings_file
            );
            fs::write(&widget_settings_file, DEFAULT_WIDGET_SETTINGS_JSON).with_context(|| {
                format!("Failed to write widget settings to {widget_settings_file:?}")
            })?;
        }

        // Load and validate from disk into memory
        self.reload_config()?;

        Ok(())
    }

    /// Reload configuration files from disk into memory and notify subscribers.
    pub fn reload_config(&self) -> Result<()> {
        let config_file = self.config_dir.join("config").join("config.json");
        let suits_file = self.config_dir.join("config").join("suits.json");
        let widget_settings_file = self.config_dir.join("widget_settings.json");

        if config_file.exists() {
            let content = fs::read_to_string(&config_file)
                .with_context(|| format!("Failed to read {config_file:?}"))?;
            serde_json::from_str::<serde_json::Value>(&content)
                .with_context(|| format!("Invalid JSON in {config_file:?}"))?;
            if let Ok(mut lock) = self.config_json.write() {
                *lock = content;
            }
        }

        if suits_file.exists() {
            let content = fs::read_to_string(&suits_file)
                .with_context(|| format!("Failed to read {suits_file:?}"))?;
            serde_json::from_str::<serde_json::Value>(&content)
                .with_context(|| format!("Invalid JSON in {suits_file:?}"))?;
            if let Ok(mut lock) = self.suits_json.write() {
                *lock = content;
            }
        }

        if widget_settings_file.exists() {
            let content = fs::read_to_string(&widget_settings_file)
                .with_context(|| format!("Failed to read {widget_settings_file:?}"))?;
            serde_json::from_str::<serde_json::Value>(&content)
                .with_context(|| format!("Invalid JSON in {widget_settings_file:?}"))?;
            if let Ok(mut lock) = self.widget_settings_json.write() {
                *lock = content;
            }
        }

        let _ = self.event_tx.send(SystemEvent::ConfigReloaded);
        let _ = self.reload_tx.send(());
        info!("Configurations reloaded and verified successfully.");
        Ok(())
    }

    /// Retrieve the current master config JSON.
    pub fn get_config_json(&self) -> String {
        self.config_json
            .read()
            .map(|l| l.clone())
            .unwrap_or_else(|_| DEFAULT_CONFIG_JSON.to_string())
    }

    /// Retrieve the current suits presets JSON.
    pub fn get_suits_json(&self) -> String {
        self.suits_json
            .read()
            .map(|l| l.clone())
            .unwrap_or_else(|_| DEFAULT_SUITS_JSON.to_string())
    }

    /// Retrieve the current widget settings JSON.
    pub fn get_widget_settings_json(&self) -> String {
        self.widget_settings_json
            .read()
            .map(|l| l.clone())
            .unwrap_or_else(|_| DEFAULT_WIDGET_SETTINGS_JSON.to_string())
    }

    /// Trigger configuration reload across all subsystems.
    pub fn trigger_reload(&self) {
        if let Err(e) = self.reload_config() {
            warn!("Configuration reload error: {e:#}");
        }
    }

    /// Trigger daemon shutdown signal.
    pub fn trigger_shutdown(&self) {
        let _ = self.event_tx.send(SystemEvent::ShutdownInitiated);
        let _ = self.shutdown_tx.send(());
    }

    /// Subscribe to reload signals.
    pub fn subscribe_reload(&self) -> broadcast::Receiver<()> {
        self.reload_tx.subscribe()
    }

    /// Subscribe to shutdown signals.
    pub fn subscribe_shutdown(&self) -> broadcast::Receiver<()> {
        self.shutdown_tx.subscribe()
    }

    /// Subscribe to system events.
    pub fn subscribe_events(&self) -> broadcast::Receiver<SystemEvent> {
        self.event_tx.subscribe()
    }

    /// Retrieve current runtime status.
    pub fn status(&self) -> DaemonStatus {
        let compositor = std::env::var("NIRI_SOCKET")
            .map(|_| "Niri".to_string())
            .or_else(|_| {
                std::env::var("HYPRLAND_INSTANCE_SIGNATURE").map(|_| "Hyprland".to_string())
            })
            .unwrap_or_else(|_| "Wayland (Generic)".to_string());

        DaemonStatus {
            pid: std::process::id(),
            version: env!("CARGO_PKG_VERSION").to_string(),
            uptime_secs: self.start_time.elapsed().as_secs(),
            compositor,
            config_dir: self.config_dir.to_string_lossy().to_string(),
            cache_dir: self.cache_dir.to_string_lossy().to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_state_initialization_and_seeding() {
        let temp_dir = std::env::temp_dir().join(format!("agility_test_{}", std::process::id()));
        let config_dir = temp_dir.join("config");
        let cache_dir = temp_dir.join("cache");

        let state = DaemonState::new(Some(config_dir.clone()), Some(cache_dir.clone()));
        assert!(state.seed_and_validate_directories().is_ok());

        assert!(config_dir.join("config").join("config.json").exists());
        assert!(config_dir.join("config").join("suits.json").exists());
        assert!(config_dir.join("widget_settings.json").exists());
        assert!(cache_dir.join("weather").exists());

        let status = state.status();
        assert_eq!(status.pid, std::process::id());
        assert_eq!(status.version, env!("CARGO_PKG_VERSION"));

        // Test reload broadcast
        let mut reload_rx = state.subscribe_reload();
        state.trigger_reload();
        assert!(reload_rx.recv().await.is_ok());

        // Test shutdown broadcast
        let mut shutdown_rx = state.subscribe_shutdown();
        state.trigger_shutdown();
        assert!(shutdown_rx.recv().await.is_ok());

        let _ = fs::remove_dir_all(&temp_dir);
    }
}
