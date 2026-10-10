//! Desktop Suites ("Suits"), Settings engine, and Doom Melt transitions.
//! Implements `org.agility.Daemon.Suits` D-Bus interface.

use agility_common::{
    AppConfig, DoomMeltParams, SuiteConfig, SuitePreset, SuiteSettingsConfig, SuitsCatalog,
    SuitsPayload,
};
use anyhow::{Context, Result};
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, RwLock};
use std::time::SystemTime;
use tracing::{error, info, warn};
use zbus::object_server::SignalEmitter;

/// Locate the suits configuration file with fallback options.
pub fn get_suits_config_path(config_dir: &Path) -> PathBuf {
    let nested = config_dir.join("config").join("suits.json");
    if nested.exists() {
        nested
    } else {
        let flat = config_dir.join("suits.json");
        if flat.exists() {
            flat
        } else {
            nested
        }
    }
}

/// Locate the master app configuration file with fallback options.
pub fn get_app_config_path(config_dir: &Path) -> PathBuf {
    let nested = config_dir.join("config").join("config.json");
    if nested.exists() {
        nested
    } else {
        let flat = config_dir.join("config.json");
        if flat.exists() {
            flat
        } else {
            nested
        }
    }
}

/// Generate correlated random-walk delays for Doom Vertical Melt columns.
/// Mimics the iconic ragged dripping melt wave where columns drop top-to-bottom.
pub fn generate_doom_melt_delays(num_cols: u32) -> Vec<f64> {
    let count = num_cols.clamp(10, 160) as usize;
    let mut delays = Vec::with_capacity(count);

    let mut seed = SystemTime::now()
        .duration_since(SystemTime::UNIX_EPOCH)
        .unwrap_or_default()
        .as_nanos() as u64;

    let mut curr = 0.035;
    for _ in 0..count {
        seed = seed
            .wrapping_mul(6364136223846793005)
            .wrapping_add(1442695040888963407);
        let delta = (((seed >> 33) as f64) / ((1u64 << 31) as f64) - 0.5) * 0.10;
        curr = (curr + delta).clamp(0.0, 0.36);
        delays.push((curr * 1000.0).round() / 1000.0);
    }

    delays
}

/// Attempt an instantaneous desktop capture for the melt transition, falling back to wallpaper.
pub fn capture_desktop_snapshot(cache_dir: &Path, wallpaper_path: &str) -> Option<String> {
    let snap_dir = cache_dir.join("snapshots");
    let _ = fs::create_dir_all(&snap_dir);
    let tmp_path = snap_dir.join(format!("melt_snapshot_{}.ppm", std::process::id()));

    // Try grim screenshot utility
    let grim_res = Command::new("grim")
        .arg("-t")
        .arg("ppm")
        .arg(&tmp_path)
        .output();

    if let Ok(out) = grim_res {
        if out.status.success() && tmp_path.exists() {
            return Some(tmp_path.to_string_lossy().to_string());
        }
    }

    // Fallback to active wallpaper if available
    if !wallpaper_path.is_empty() && Path::new(wallpaper_path).exists() {
        return Some(wallpaper_path.to_string());
    }

    None
}

/// Service managing Desktop Suites presets, master config, and transitions.
#[derive(Clone)]
pub struct SuitsService {
    config_dir: PathBuf,
    cache_dir: PathBuf,
    catalog: Arc<RwLock<SuitsCatalog>>,
    app_config: Arc<RwLock<AppConfig>>,
    is_switching: Arc<RwLock<bool>>,
}

impl SuitsService {
    pub fn new(config_dir: PathBuf, cache_dir: PathBuf) -> Arc<Self> {
        let suits_path = get_suits_config_path(&config_dir);
        let config_path = get_app_config_path(&config_dir);

        // 1. Load or seed SuitsCatalog
        let mut loaded_catalog = SuitsCatalog::default();
        if suits_path.exists() {
            match fs::read_to_string(&suits_path) {
                Ok(data) => match serde_json::from_str::<SuitsPayload>(&data) {
                    Ok(payload) => {
                        loaded_catalog = SuitsCatalog::from(payload);
                        info!(
                            "Loaded {} desktop suites from {:?}",
                            loaded_catalog.suites.len(),
                            suits_path
                        );
                    }
                    Err(e) => {
                        warn!("Failed to parse {suits_path:?}: {e:#}. Using fallback default.");
                    }
                },
                Err(e) => {
                    warn!("Failed to read {suits_path:?}: {e:#}. Using fallback default.");
                }
            }
        } else {
            info!("Initializing new suits catalog at {:?}", suits_path);
            let _ = Self::write_json_file(&suits_path, &loaded_catalog);
        }

        // Ensure active suite exists
        if !loaded_catalog.suites.is_empty()
            && !loaded_catalog
                .suites
                .iter()
                .any(|s| s.id == loaded_catalog.active_id)
        {
            loaded_catalog.active_id = loaded_catalog.suites[0].id.clone();
        }

        // 2. Load or seed AppConfig
        let mut loaded_config = AppConfig::default();
        if config_path.exists() {
            if let Ok(data) = fs::read_to_string(&config_path) {
                if let Ok(cfg) = serde_json::from_str::<AppConfig>(&data) {
                    loaded_config = cfg;
                }
            }
        } else {
            let _ = Self::write_json_file(&config_path, &loaded_config);
        }

        Arc::new(Self {
            config_dir,
            cache_dir,
            catalog: Arc::new(RwLock::new(loaded_catalog)),
            app_config: Arc::new(RwLock::new(loaded_config)),
            is_switching: Arc::new(RwLock::new(false)),
        })
    }

    /// Read currently active suite ID.
    pub fn active_id(&self) -> String {
        self.catalog.read().unwrap().active_id.clone()
    }

    /// Retrieve currently active suite preset.
    pub fn get_active_suite(&self) -> Option<SuitePreset> {
        let catalog = self.catalog.read().unwrap();
        catalog
            .suites
            .iter()
            .find(|s| s.id == catalog.active_id)
            .cloned()
    }

    /// Retrieve all configured suites.
    pub fn get_all_suites(&self) -> Vec<SuitePreset> {
        self.catalog.read().unwrap().suites.clone()
    }

    /// Retrieve master app configuration snapshot.
    pub fn get_app_config(&self) -> AppConfig {
        self.app_config.read().unwrap().clone()
    }

    /// Update master app configuration.
    pub fn update_app_config(&self, new_config: AppConfig) -> Result<()> {
        *self.app_config.write().unwrap() = new_config.clone();
        let config_path = get_app_config_path(&self.config_dir);
        Self::write_json_file(&config_path, &new_config)?;
        Ok(())
    }

    /// Persist current suites catalog to disk atomically.
    pub fn save_suits(&self) -> Result<()> {
        let catalog = self.catalog.read().unwrap().clone();
        let suits_path = get_suits_config_path(&self.config_dir);
        Self::write_json_file(&suits_path, &catalog)
    }

    /// Persist master app config to disk atomically.
    pub fn save_config(&self) -> Result<()> {
        let config = self.app_config.read().unwrap().clone();
        let config_path = get_app_config_path(&self.config_dir);
        Self::write_json_file(&config_path, &config)
    }

    /// Create a new desktop suite.
    pub fn create_suite(&self, name: Option<String>, clone_active: bool) -> SuitePreset {
        let now_millis = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        let base_id = format!("desktop-{now_millis}");
        let new_id = {
            let catalog = self.catalog.read().unwrap();
            if catalog.suites.iter().any(|s| s.id == base_id) {
                let mut c = 1;
                while catalog
                    .suites
                    .iter()
                    .any(|s| s.id == format!("{base_id}-{c}"))
                {
                    c += 1;
                }
                format!("{base_id}-{c}")
            } else {
                base_id
            }
        };

        let suite_name = match name {
            Some(n) if !n.trim().is_empty() => n.trim().to_string(),
            _ => self.next_desktop_name(),
        };

        let config = if clone_active {
            self.get_active_suite()
                .and_then(|s| s.config)
                .unwrap_or_default()
        } else {
            SuiteConfig::default()
        };

        let new_suite = SuitePreset {
            id: new_id,
            name: suite_name,
            description: Some("Custom desktop suite".to_string()),
            created_at: Some(now_millis as f64 / 1000.0),
            config: Some(config),
            theme: Some("Matugen".to_string()),
            wallpaper: Some("".to_string()),
        };

        {
            let mut catalog = self.catalog.write().unwrap();
            catalog.suites.push(new_suite.clone());
        }

        let _ = self.save_suits();
        info!(
            "Created desktop suite '{}' ({})",
            new_suite.name, new_suite.id
        );
        new_suite
    }

    /// Duplicate an existing desktop suite.
    pub fn duplicate_suite(&self, suite_id: &str) -> Option<SuitePreset> {
        let source = {
            let catalog = self.catalog.read().unwrap();
            catalog.suites.iter().find(|s| s.id == suite_id).cloned()?
        };

        let now_millis = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis();
        let base_id = format!("desktop-{now_millis}");
        let new_id = {
            let catalog = self.catalog.read().unwrap();
            if catalog.suites.iter().any(|s| s.id == base_id) {
                let mut c = 1;
                while catalog
                    .suites
                    .iter()
                    .any(|s| s.id == format!("{base_id}-{c}"))
                {
                    c += 1;
                }
                format!("{base_id}-{c}")
            } else {
                base_id
            }
        };
        let new_name = format!("{} (Copy)", source.name);

        let cloned_suite = SuitePreset {
            id: new_id,
            name: new_name,
            description: source.description,
            created_at: Some(now_millis as f64 / 1000.0),
            config: source.config,
            theme: source.theme,
            wallpaper: source.wallpaper,
        };

        {
            let mut catalog = self.catalog.write().unwrap();
            catalog.suites.push(cloned_suite.clone());
        }

        let _ = self.save_suits();
        info!(
            "Duplicated suite '{}' to '{}'",
            source.name, cloned_suite.name
        );
        Some(cloned_suite)
    }

    /// Rename an existing desktop suite.
    pub fn rename_suite(&self, suite_id: &str, new_name: &str) -> bool {
        let trimmed = new_name.trim();
        if trimmed.is_empty() {
            return false;
        }

        let mut catalog = self.catalog.write().unwrap();
        if let Some(suite) = catalog.suites.iter_mut().find(|s| s.id == suite_id) {
            suite.name = trimmed.to_string();
            drop(catalog);
            let _ = self.save_suits();
            info!("Renamed suite {suite_id} to '{trimmed}'");
            true
        } else {
            false
        }
    }

    /// Delete a desktop suite. Protected against deleting the final remaining suite.
    pub fn delete_suite(&self, suite_id: &str) -> bool {
        let mut catalog = self.catalog.write().unwrap();
        if catalog.suites.len() <= 1 {
            warn!("Cannot delete the only remaining desktop suite: {suite_id}");
            return false;
        }

        let index = catalog.suites.iter().position(|s| s.id == suite_id);
        if let Some(idx) = index {
            catalog.suites.remove(idx);

            // If deleted suite was active, pick another suite as active
            if catalog.active_id == suite_id {
                let fallback = catalog.suites[0].id.clone();
                catalog.active_id = fallback;
            }

            drop(catalog);
            let _ = self.save_suits();
            info!("Deleted desktop suite {suite_id}");
            true
        } else {
            false
        }
    }

    /// Cycle to the next desktop suite in catalog list.
    pub fn cycle_next_suite(&self) -> Option<String> {
        let (current_idx, len) = {
            let catalog = self.catalog.read().unwrap();
            let idx = catalog
                .suites
                .iter()
                .position(|s| s.id == catalog.active_id)?;
            (idx, catalog.suites.len())
        };

        if len == 0 {
            return None;
        }

        let next_idx = (current_idx + 1) % len;
        let next_id = self.catalog.read().unwrap().suites[next_idx].id.clone();
        if self.switch_suite_internal(&next_id).is_ok() {
            Some(next_id)
        } else {
            None
        }
    }

    /// Cycle to the previous desktop suite in catalog list.
    pub fn cycle_prev_suite(&self) -> Option<String> {
        let (current_idx, len) = {
            let catalog = self.catalog.read().unwrap();
            let idx = catalog
                .suites
                .iter()
                .position(|s| s.id == catalog.active_id)?;
            (idx, catalog.suites.len())
        };

        if len == 0 {
            return None;
        }

        let prev_idx = (current_idx + len - 1) % len;
        let prev_id = self.catalog.read().unwrap().suites[prev_idx].id.clone();
        if self.switch_suite_internal(&prev_id).is_ok() {
            Some(prev_id)
        } else {
            None
        }
    }

    /// Synchronize runtime user modifications into active suite preset.
    pub fn sync_from_current(&self) -> Result<()> {
        let current_cfg = self.app_config.read().unwrap().clone();
        let mut catalog = self.catalog.write().unwrap();
        let active_id = catalog.active_id.clone();

        if let Some(active_suite) = catalog.suites.iter_mut().find(|s| s.id == active_id) {
            let mut cfg = active_suite.config.clone().unwrap_or_default();
            cfg.bars = current_cfg.bars.clone();
            cfg.desktop_canvas = current_cfg.desktop_canvas.clone();
            cfg.wallpaper = current_cfg.wallpaper.clone();
            cfg.theme = current_cfg.theme.clone();
            cfg.settings = current_cfg.settings.clone();
            cfg.dock = current_cfg.dock.clone();
            cfg.launcher = current_cfg.launcher.clone();

            active_suite.config = Some(cfg);
            drop(catalog);
            self.save_suits()?;
            info!("Synchronized active suite state for {active_id}");
        }

        Ok(())
    }

    /// Switch active desktop suite internally, applying snapshot settings.
    pub fn switch_suite_internal(&self, target_id: &str) -> Result<bool, String> {
        {
            let mut switching = self.is_switching.write().unwrap();
            if *switching {
                return Err("Suite switch already in progress".to_string());
            }
            *switching = true;
        }

        let res = (|| -> Result<bool, String> {
            let target_suite = {
                let catalog = self.catalog.read().unwrap();
                if catalog.active_id == target_id {
                    return Ok(true);
                }
                catalog
                    .suites
                    .iter()
                    .find(|s| s.id == target_id)
                    .cloned()
                    .ok_or_else(|| format!("Suite '{target_id}' not found"))?
            };

            // Sync current state before switching
            let _ = self.sync_from_current();

            // Apply target suite config to master app_config
            if let Some(cfg) = target_suite.config {
                let mut app_cfg = self.app_config.write().unwrap();
                if !cfg.bars.is_null() {
                    app_cfg.bars = cfg.bars;
                }
                if !cfg.desktop_canvas.is_null() {
                    app_cfg.desktop_canvas = cfg.desktop_canvas;
                }
                app_cfg.wallpaper = cfg.wallpaper;
                app_cfg.theme = cfg.theme;
                app_cfg.settings = cfg.settings;
                app_cfg.dock = cfg.dock;
                app_cfg.launcher = cfg.launcher;
            }

            // Update active ID
            {
                let mut catalog = self.catalog.write().unwrap();
                catalog.active_id = target_id.to_string();
            }

            // Persist changes
            let _ = self.save_suits();
            let _ = self.save_config();

            info!(
                "Switched active suite to '{target_id}' ({})",
                target_suite.name
            );
            Ok(true)
        })();

        *self.is_switching.write().unwrap() = false;
        res
    }

    /// Compute Doom Vertical Melt transition parameters.
    pub fn trigger_doom_melt(&self, duration_ms: u32, num_cols: u32) -> DoomMeltParams {
        let cols = num_cols.clamp(20, 160);
        let duration = duration_ms.clamp(200, 3000);
        let delays = generate_doom_melt_delays(cols);

        let wallpaper = self.app_config.read().unwrap().wallpaper.path.clone();
        let snapshot_path = capture_desktop_snapshot(&self.cache_dir, &wallpaper);

        DoomMeltParams {
            duration_ms: duration,
            num_columns: cols,
            column_delays: delays,
            snapshot_path,
        }
    }

    fn next_desktop_name(&self) -> String {
        let catalog = self.catalog.read().unwrap();
        let existing: std::collections::HashSet<String> =
            catalog.suites.iter().map(|s| s.name.clone()).collect();
        let mut idx = 1;
        while existing.contains(&format!("Desktop {idx}")) {
            idx += 1;
        }
        format!("Desktop {idx}")
    }

    fn write_json_file<T: Serialize>(path: &Path, value: &T) -> Result<()> {
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("Failed to create parent dir: {parent:?}"))?;
        }
        let json = serde_json::to_string_pretty(value)?;
        let tmp = path.with_extension("tmp");
        fs::write(&tmp, json)
            .with_context(|| format!("Failed to write temporary file: {tmp:?}"))?;
        fs::rename(&tmp, path).with_context(|| format!("Failed to commit file to: {path:?}"))?;
        Ok(())
    }
}

/// D-Bus interface wrapper for `org.agility.Daemon.Suits`.
#[derive(Clone)]
pub struct SuitsInterface {
    service: Arc<SuitsService>,
}

impl SuitsInterface {
    pub fn new(service: Arc<SuitsService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Suits")]
impl SuitsInterface {
    // ─── Properties ───

    #[zbus(property)]
    async fn active_id(&self) -> String {
        self.service.active_id()
    }

    #[zbus(property)]
    async fn suits(&self) -> String {
        let suites = self.service.get_all_suites();
        serde_json::to_string(&suites).unwrap_or_else(|_| "[]".to_string())
    }

    #[zbus(property)]
    async fn active_suite(&self) -> String {
        let active = self.service.get_active_suite();
        serde_json::to_string(&active).unwrap_or_else(|_| "null".to_string())
    }

    #[zbus(property)]
    async fn is_switching(&self) -> bool {
        *self.service.is_switching.read().unwrap()
    }

    // ─── Methods ───

    /// Retrieve full JSON catalog of configured desktop suites.
    async fn get_suits(&self) -> String {
        self.suits().await
    }

    /// Retrieve JSON representation of currently active desktop suite.
    async fn get_active_suite(&self) -> String {
        self.active_suite().await
    }

    /// Switch to a targeted desktop suite and trigger transition overlay.
    async fn switch_suite(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        suite_id: String,
    ) -> bool {
        let prev_id = self.service.active_id();
        let transition = {
            let catalog = self.service.catalog.read().unwrap();
            catalog
                .suites
                .iter()
                .find(|s| s.id == suite_id)
                .and_then(|s| s.config.as_ref())
                .map(|c| c.settings.suits_transition.clone())
                .unwrap_or_else(|| "fluid".to_string())
        };

        let _ = Self::switching_started(&emitter, &prev_id, &suite_id, &transition).await;

        if transition == "doom" {
            let melt = self.service.trigger_doom_melt(720, 60);
            let snap = melt.snapshot_path.unwrap_or_default();
            let _ = Self::doom_melt_triggered(
                &emitter,
                &snap,
                melt.duration_ms,
                melt.num_columns,
                melt.column_delays,
            )
            .await;
        }

        match self.service.switch_suite_internal(&suite_id) {
            Ok(_) => {
                let _ = Self::active_changed(&emitter, &suite_id).await;
                let _ = Self::suites_changed(&emitter).await;
                let _ = Self::switching_finished(&emitter, &suite_id).await;
                true
            }
            Err(e) => {
                error!("Failed to switch suite to {suite_id}: {e}");
                let _ = Self::switching_finished(&emitter, &prev_id).await;
                false
            }
        }
    }

    /// Cycle to the next desktop suite in catalog list.
    async fn cycle_next_suite(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> String {
        let (current_idx, len) = {
            let catalog = self.service.catalog.read().unwrap();
            let idx = catalog
                .suites
                .iter()
                .position(|s| s.id == catalog.active_id);
            match idx {
                Some(i) => (i, catalog.suites.len()),
                None => return String::new(),
            }
        };

        if len == 0 {
            return String::new();
        }

        let next_idx = (current_idx + 1) % len;
        let next_id = self.service.catalog.read().unwrap().suites[next_idx]
            .id
            .clone();

        if self.switch_suite(emitter, next_id.clone()).await {
            next_id
        } else {
            String::new()
        }
    }

    /// Cycle to the previous desktop suite in catalog list.
    async fn cycle_prev_suite(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> String {
        let (current_idx, len) = {
            let catalog = self.service.catalog.read().unwrap();
            let idx = catalog
                .suites
                .iter()
                .position(|s| s.id == catalog.active_id);
            match idx {
                Some(i) => (i, catalog.suites.len()),
                None => return String::new(),
            }
        };

        if len == 0 {
            return String::new();
        }

        let prev_idx = (current_idx + len - 1) % len;
        let prev_id = self.service.catalog.read().unwrap().suites[prev_idx]
            .id
            .clone();

        if self.switch_suite(emitter, prev_id.clone()).await {
            prev_id
        } else {
            String::new()
        }
    }

    /// Create a new desktop suite preset.
    async fn create_suite(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        name: String,
        clone_active: bool,
    ) -> String {
        let name_opt = if name.trim().is_empty() {
            None
        } else {
            Some(name)
        };
        let created = self.service.create_suite(name_opt, clone_active);
        let _ = Self::suites_changed(&emitter).await;
        created.id
    }

    /// Duplicate an existing desktop suite preset.
    async fn duplicate_suite(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        suite_id: String,
    ) -> String {
        if let Some(dup) = self.service.duplicate_suite(&suite_id) {
            let _ = Self::suites_changed(&emitter).await;
            dup.id
        } else {
            String::new()
        }
    }

    /// Rename an existing desktop suite.
    async fn rename_suite(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        suite_id: String,
        new_name: String,
    ) -> bool {
        let ok = self.service.rename_suite(&suite_id, &new_name);
        if ok {
            let _ = Self::suites_changed(&emitter).await;
        }
        ok
    }

    /// Delete a desktop suite.
    async fn delete_suite(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        suite_id: String,
    ) -> bool {
        let ok = self.service.delete_suite(&suite_id);
        if ok {
            let _ = Self::suites_changed(&emitter).await;
        }
        ok
    }

    /// Synchronize runtime UI modifications into active suite preset.
    async fn sync_from_current(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let ok = self.service.sync_from_current().is_ok();
        if ok {
            let _ = Self::suites_changed(&emitter).await;
        }
        ok
    }

    /// Generate Doom Vertical Melt parameters and broadcast transition trigger.
    async fn trigger_doom_melt(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        duration_ms: u32,
        num_cols: u32,
    ) -> String {
        let melt = self.service.trigger_doom_melt(duration_ms, num_cols);
        let snap = melt.snapshot_path.clone().unwrap_or_default();
        let _ = Self::doom_melt_triggered(
            &emitter,
            &snap,
            melt.duration_ms,
            melt.num_columns,
            melt.column_delays.clone(),
        )
        .await;

        serde_json::to_string(&melt).unwrap_or_else(|_| "{}".to_string())
    }

    /// Retrieve active system settings.
    async fn get_settings(&self) -> String {
        let cfg = self.service.get_app_config();
        serde_json::to_string(&cfg.settings).unwrap_or_else(|_| "{}".to_string())
    }

    /// Retrieve master app configuration.
    async fn get_config(&self) -> String {
        let cfg = self.service.get_app_config();
        serde_json::to_string(&cfg).unwrap_or_else(|_| "{}".to_string())
    }

    /// Update system settings directly.
    async fn update_settings(&self, settings_json: String) -> bool {
        if let Ok(settings) = serde_json::from_str::<SuiteSettingsConfig>(&settings_json) {
            let mut cfg = self.service.get_app_config();
            cfg.settings = settings;
            self.service.update_app_config(cfg).is_ok()
        } else {
            false
        }
    }

    // ─── Signals ───

    /// Emitted when the active suite ID changes.
    #[zbus(signal)]
    async fn active_changed(emitter: &SignalEmitter<'_>, suite_id: &str) -> zbus::Result<()>;

    /// Emitted when suites are added, modified, renamed, or deleted.
    #[zbus(signal)]
    async fn suites_changed(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    /// Emitted when a suite transition starts.
    #[zbus(signal)]
    async fn switching_started(
        emitter: &SignalEmitter<'_>,
        from_id: &str,
        to_id: &str,
        transition: &str,
    ) -> zbus::Result<()>;

    /// Emitted when a suite transition completes.
    #[zbus(signal)]
    async fn switching_finished(emitter: &SignalEmitter<'_>, suite_id: &str) -> zbus::Result<()>;

    /// Emitted when a Doom Vertical Melt screen transition is triggered.
    #[zbus(signal)]
    async fn doom_melt_triggered(
        emitter: &SignalEmitter<'_>,
        snapshot_path: &str,
        duration_ms: u32,
        num_cols: u32,
        delays: Vec<f64>,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TestDirGuard(PathBuf);
    impl Drop for TestDirGuard {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn create_test_service() -> (Arc<SuitsService>, TestDirGuard) {
        let unique = SystemTime::now()
            .duration_since(SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_suits_{unique}"));
        let config_dir = temp_dir.join("config_dir");
        let cache_dir = temp_dir.join("cache_dir");
        fs::create_dir_all(&config_dir).unwrap();
        fs::create_dir_all(&cache_dir).unwrap();

        let service = SuitsService::new(config_dir, cache_dir);
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_suits_catalog_deserialization_both_formats() {
        // 1. Container format
        let container_json = r#"{
            "active_id": "desktop-work",
            "suites": [
                {
                    "id": "desktop-work",
                    "name": "Work Space",
                    "theme": "TokyoNight"
                }
            ]
        }"#;

        let payload1: SuitsPayload = serde_json::from_str(container_json).unwrap();
        let catalog1 = SuitsCatalog::from(payload1);
        assert_eq!(catalog1.active_id, "desktop-work");
        assert_eq!(catalog1.suites.len(), 1);
        assert_eq!(catalog1.suites[0].name, "Work Space");

        // 2. Direct list format
        let list_json = r#"[
            {
                "id": "desktop-retro",
                "name": "Retro 80s",
                "theme": "Gruvbox"
            }
        ]"#;

        let payload2: SuitsPayload = serde_json::from_str(list_json).unwrap();
        let catalog2 = SuitsCatalog::from(payload2);
        assert_eq!(catalog2.active_id, "desktop-retro");
        assert_eq!(catalog2.suites.len(), 1);
        assert_eq!(catalog2.suites[0].name, "Retro 80s");
    }

    #[test]
    fn test_crud_operations() {
        let (service, _temp) = create_test_service();

        // Initial default suite
        let initial_suites = service.get_all_suites();
        assert_eq!(initial_suites.len(), 1);
        assert_eq!(service.active_id(), "desktop-1");

        // Create new suite
        let created = service.create_suite(Some("Gaming Rig".into()), false);
        assert_eq!(created.name, "Gaming Rig");
        assert_eq!(service.get_all_suites().len(), 2);

        // Duplicate suite
        let dup = service.duplicate_suite(&created.id).unwrap();
        assert_eq!(dup.name, "Gaming Rig (Copy)");
        assert_eq!(service.get_all_suites().len(), 3);

        // Rename suite
        assert!(service.rename_suite(&dup.id, "Arcade Station"));
        let renamed = service
            .get_all_suites()
            .into_iter()
            .find(|s| s.id == dup.id)
            .unwrap();
        assert_eq!(renamed.name, "Arcade Station");

        // Delete duplicated suite
        assert!(service.delete_suite(&dup.id));
        assert_eq!(service.get_all_suites().len(), 2);

        // Cannot delete down to 0 suites
        assert!(service.delete_suite(&created.id));
        assert_eq!(service.get_all_suites().len(), 1);
        assert!(!service.delete_suite(&service.active_id()));
        assert_eq!(service.get_all_suites().len(), 1);
    }

    #[test]
    fn test_switch_and_cycle_suites() {
        let (service, _temp) = create_test_service();

        let s2 = service.create_suite(Some("Suite 2".into()), false);
        let s3 = service.create_suite(Some("Suite 3".into()), false);

        assert_eq!(service.active_id(), "desktop-1");

        // Direct switch
        assert!(service.switch_suite_internal(&s2.id).unwrap());
        assert_eq!(service.active_id(), s2.id);

        // Cycle next: s2 -> s3
        let next1 = service.cycle_next_suite().unwrap();
        assert_eq!(next1, s3.id);
        assert_eq!(service.active_id(), s3.id);

        // Cycle next wrap around: s3 -> desktop-1
        let next2 = service.cycle_next_suite().unwrap();
        assert_eq!(next2, "desktop-1");
        assert_eq!(service.active_id(), "desktop-1");

        // Cycle prev wrap around: desktop-1 -> s3
        let prev1 = service.cycle_prev_suite().unwrap();
        assert_eq!(prev1, s3.id);
        assert_eq!(service.active_id(), s3.id);

        // Cycle prev: s3 -> s2
        let prev2 = service.cycle_prev_suite().unwrap();
        assert_eq!(prev2, s2.id);
        assert_eq!(service.active_id(), s2.id);
    }

    #[test]
    fn test_sync_from_current_and_persistence() {
        let (service, temp) = create_test_service();

        // Mutate app config
        let mut app_cfg = service.get_app_config();
        app_cfg.wallpaper.path = "/tmp/awesome_wall.jpg".into();
        app_cfg.theme.active_accent = "accent2".into();
        service.update_app_config(app_cfg).unwrap();

        // Sync to active suite
        service.sync_from_current().unwrap();

        // Verify active suite captured changes
        let active = service.get_active_suite().unwrap();
        let cfg = active.config.unwrap();
        assert_eq!(cfg.wallpaper.path, "/tmp/awesome_wall.jpg");
        assert_eq!(cfg.theme.active_accent, "accent2");

        // Verify file persisted on disk
        let suits_file = get_suits_config_path(temp.0.join("config_dir").as_path());
        assert!(suits_file.exists());
        let on_disk_data = fs::read_to_string(&suits_file).unwrap();
        assert!(on_disk_data.contains("/tmp/awesome_wall.jpg"));
    }

    #[test]
    fn test_doom_melt_delays_distribution() {
        let num_cols = 60;
        let delays = generate_doom_melt_delays(num_cols);

        assert_eq!(delays.len(), 60);
        for &d in &delays {
            assert!(
                (0.0..=0.36).contains(&d),
                "Delay out of bounds [0.0, 0.36]: {d}"
            );
        }

        // Verify that delays are not all identical (proper random walk)
        let min = delays.iter().cloned().fold(f64::INFINITY, f64::min);
        let max = delays.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
        assert!(
            max > min,
            "Delays should have variance: min={min}, max={max}"
        );
    }
}
