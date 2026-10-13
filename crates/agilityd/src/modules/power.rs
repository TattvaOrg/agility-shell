//! Power, Idle Inhibitor (Caffeine), Performance Profiles & Night Light Engine.
//! Exposes `org.agility.Daemon.Power` D-Bus interface.

use agility_common::{IdleRule, PowerState};
use anyhow::Result;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Child, Command};
use std::sync::{Arc, Mutex, RwLock};
use std::time::Duration;
use tokio::sync::broadcast;
use tracing::{info, warn};
use zbus::object_server::SignalEmitter;

/// Default night light temperature in Kelvin.
pub const DEFAULT_NIGHT_LIGHT_TEMP: u32 = 4000;
/// Minimum allowed night light temperature in Kelvin.
pub const MIN_NIGHT_LIGHT_TEMP: u32 = 1000;
/// Maximum allowed night light temperature in Kelvin.
pub const MAX_NIGHT_LIGHT_TEMP: u32 = 10000;
/// Recognized power profile identifiers.
pub const VALID_POWER_PROFILES: &[&str] = &["power-saver", "balanced", "performance"];

/// Helper to kill and reap a spawned child process safely.
fn kill_child(child_lock: &Mutex<Option<Child>>) {
    let mut lock = child_lock.lock().unwrap();
    if let Some(mut child) = lock.take() {
        let _ = child.kill();
        let _ = child.wait();
    }
}

/// Service managing power profiles, caffeine idle inhibitor, night light, and Wayland idle monitoring.
pub struct PowerService {
    state: Arc<RwLock<PowerState>>,
    idle_rules: Arc<RwLock<Vec<IdleRule>>>,
    config_dir: PathBuf,
    cache_dir: PathBuf,
    inhibit_child: Arc<Mutex<Option<Child>>>,
    night_light_child: Arc<Mutex<Option<Child>>>,
    idle_child: Arc<Mutex<Option<Child>>>,
}

impl PowerService {
    /// Initialize a new PowerService instance, restoring state from disk if present.
    pub fn new(config_dir: PathBuf, cache_dir: PathBuf) -> Arc<Self> {
        let on_bat = Self::detect_on_battery();
        let active_profile = Self::detect_power_profile();

        let mut initial_state = PowerState {
            caffeine_active: false,
            power_profile: active_profile,
            night_light_active: false,
            night_light_temperature: DEFAULT_NIGHT_LIGHT_TEMP,
            on_battery: on_bat,
        };

        // Attempt to load persisted state from cache
        let state_path = cache_dir.join("power_state.json");
        if state_path.is_file() {
            if let Ok(content) = fs::read_to_string(&state_path) {
                if let Ok(saved) = serde_json::from_str::<PowerState>(&content) {
                    initial_state.night_light_temperature = saved
                        .night_light_temperature
                        .clamp(MIN_NIGHT_LIGHT_TEMP, MAX_NIGHT_LIGHT_TEMP);
                    initial_state.night_light_active = saved.night_light_active;
                    initial_state.caffeine_active = saved.caffeine_active;
                    if VALID_POWER_PROFILES.contains(&saved.power_profile.as_str()) {
                        initial_state.power_profile = saved.power_profile;
                    }
                }
            }
        }

        let default_rules = vec![
            IdleRule {
                name: "screen-off".to_string(),
                timeout_ac_mins: 10,
                timeout_bat_mins: 2,
                enabled: true,
            },
            IdleRule {
                name: "lock".to_string(),
                timeout_ac_mins: 15,
                timeout_bat_mins: 5,
                enabled: true,
            },
            IdleRule {
                name: "suspend".to_string(),
                timeout_ac_mins: 15,
                timeout_bat_mins: 10,
                enabled: true,
            },
        ];

        let service = Arc::new(Self {
            state: Arc::new(RwLock::new(initial_state)),
            idle_rules: Arc::new(RwLock::new(default_rules)),
            config_dir,
            cache_dir,
            inhibit_child: Arc::new(Mutex::new(None)),
            night_light_child: Arc::new(Mutex::new(None)),
            idle_child: Arc::new(Mutex::new(None)),
        });

        // If caffeine or night light were persisted as active, spawn their backing processes
        if service.is_caffeine_active() {
            service.spawn_caffeine_inhibit();
        }
        if service.is_night_light_active() {
            service.spawn_night_light();
        }

        service
    }

    /// Retrieve snapshot copy of the current PowerState.
    pub fn get_power_state(&self) -> PowerState {
        self.state.read().unwrap().clone()
    }

    /// Retrieve configuration directory path.
    pub fn config_dir(&self) -> &Path {
        &self.config_dir
    }

    /// Retrieve cache directory path.
    pub fn cache_dir(&self) -> &Path {
        &self.cache_dir
    }

    /// Retrieve JSON representation of the current PowerState.
    pub fn get_power_state_json(&self) -> String {
        serde_json::to_string(&self.get_power_state()).unwrap_or_default()
    }

    /// Check if caffeine idle inhibitor is active.
    pub fn is_caffeine_active(&self) -> bool {
        self.state.read().unwrap().caffeine_active
    }

    /// Toggle Caffeine idle inhibitor mode.
    pub fn toggle_caffeine(&self) -> bool {
        let current = self.is_caffeine_active();
        self.set_caffeine(!current)
    }

    /// Explicitly set Caffeine idle inhibitor state.
    pub fn set_caffeine(&self, active: bool) -> bool {
        {
            let mut state = self.state.write().unwrap();
            state.caffeine_active = active;
        }

        if active {
            self.stop_idle_monitor();
            self.spawn_caffeine_inhibit();
            info!("Caffeine idle inhibitor enabled.");
        } else {
            kill_child(&self.inhibit_child);
            self.start_idle_monitor();
            info!("Caffeine idle inhibitor disabled.");
        }

        let _ = self.save_state();
        active
    }

    /// Retrieve active power profile ("power-saver", "balanced", "performance").
    pub fn get_power_profile(&self) -> String {
        self.state.read().unwrap().power_profile.clone()
    }

    /// Set power profile ("power-saver", "balanced", "performance").
    pub fn set_power_profile(&self, profile: &str) -> bool {
        if !VALID_POWER_PROFILES.contains(&profile) {
            warn!("Invalid power profile requested: {profile}");
            return false;
        }

        // Apply via powerprofilesctl if available
        if Self::has_binary("powerprofilesctl") {
            let res = Command::new("powerprofilesctl")
                .arg("set")
                .arg(profile)
                .output();
            if let Err(e) = res {
                warn!("Failed to execute powerprofilesctl set: {e:#}");
            }
        }

        {
            let mut state = self.state.write().unwrap();
            state.power_profile = profile.to_string();
        }

        info!("Power profile switched to: {profile}");
        let _ = self.save_state();
        true
    }

    /// Check if Night Light color temperature filter is active.
    pub fn is_night_light_active(&self) -> bool {
        self.state.read().unwrap().night_light_active
    }

    /// Retrieve current Night Light color temperature in Kelvin.
    pub fn get_night_light_temperature(&self) -> u32 {
        self.state.read().unwrap().night_light_temperature
    }

    /// Toggle Night Light color temperature filter.
    pub fn toggle_night_light(&self) -> bool {
        let current = self.is_night_light_active();
        self.set_night_light(!current)
    }

    /// Explicitly set Night Light active state.
    pub fn set_night_light(&self, active: bool) -> bool {
        {
            let mut state = self.state.write().unwrap();
            state.night_light_active = active;
        }

        if active {
            self.spawn_night_light();
            info!("Night light filter enabled.");
        } else {
            kill_child(&self.night_light_child);
            if Self::has_binary("gammastep") {
                let _ = Command::new("gammastep").arg("-x").output();
            }
            info!("Night light filter disabled.");
        }

        let _ = self.save_state();
        active
    }

    /// Set Night Light color temperature in Kelvin (clamped between 1000K and 10000K).
    pub fn set_night_light_temperature(&self, kelvin: u32) -> bool {
        let clamped = kelvin.clamp(MIN_NIGHT_LIGHT_TEMP, MAX_NIGHT_LIGHT_TEMP);
        {
            let mut state = self.state.write().unwrap();
            state.night_light_temperature = clamped;
        }

        if self.is_night_light_active() {
            self.spawn_night_light();
        }

        let _ = self.save_state();
        true
    }

    /// Check whether system is currently running on battery.
    pub fn is_on_battery(&self) -> bool {
        self.state.read().unwrap().on_battery
    }

    /// Update on_battery state and adjust idle monitoring thresholds if changed.
    pub fn update_battery_status(&self, on_battery: bool) {
        let changed = {
            let mut state = self.state.write().unwrap();
            if state.on_battery != on_battery {
                state.on_battery = on_battery;
                true
            } else {
                false
            }
        };

        if changed && !self.is_caffeine_active() {
            self.start_idle_monitor();
        }
    }

    /// Spawn background `systemd-inhibit` support process for Caffeine mode.
    fn spawn_caffeine_inhibit(&self) {
        kill_child(&self.inhibit_child);

        if Self::has_binary("systemd-inhibit") {
            match Command::new("systemd-inhibit")
                .arg("--what=idle:sleep:handle-lid-switch")
                .arg("--why=Caffeine keep-awake")
                .arg("--mode=block")
                .arg("sleep")
                .arg("infinity")
                .spawn()
            {
                Ok(child) => {
                    *self.inhibit_child.lock().unwrap() = Some(child);
                }
                Err(e) => {
                    warn!("Failed to spawn systemd-inhibit: {e:#}");
                }
            }
        }
    }

    /// Spawn Night Light runner (`wlsunset` or `gammastep`).
    fn spawn_night_light(&self) {
        kill_child(&self.night_light_child);

        let temp = self.get_night_light_temperature();
        let temp_str = temp.to_string();

        if Self::has_binary("wlsunset") {
            match Command::new("wlsunset")
                .arg("-t")
                .arg(&temp_str)
                .arg("-T")
                .arg("6500")
                .arg("-s")
                .arg("00:00")
                .arg("-S")
                .arg("00:01")
                .spawn()
            {
                Ok(child) => {
                    *self.night_light_child.lock().unwrap() = Some(child);
                }
                Err(e) => {
                    warn!("Failed to spawn wlsunset: {e:#}");
                }
            }
        } else if Self::has_binary("gammastep") {
            match Command::new("gammastep").arg("-O").arg(&temp_str).spawn() {
                Ok(child) => {
                    *self.night_light_child.lock().unwrap() = Some(child);
                }
                Err(e) => {
                    warn!("Failed to spawn gammastep: {e:#}");
                }
            }
        }
    }

    /// Start Wayland idle monitor using `swayidle` observing AC/Battery idle thresholds.
    pub fn start_idle_monitor(&self) {
        kill_child(&self.idle_child);

        if self.is_caffeine_active() {
            return;
        }

        if !Self::has_binary("swayidle") {
            return;
        }

        let on_bat = self.is_on_battery();
        let rules = self.idle_rules.read().unwrap().clone();

        // Calculate timeouts based on AC vs Battery
        let (screen_off_secs, lock_secs, suspend_secs) = {
            let mut so = if on_bat { 2 * 60 } else { 10 * 60 };
            let mut lk = if on_bat { 5 * 60 } else { 15 * 60 };
            let mut sp = if on_bat { 10 * 60 } else { 15 * 60 };

            for rule in rules {
                if !rule.enabled {
                    continue;
                }
                let timeout = if on_bat {
                    rule.timeout_bat_mins * 60
                } else {
                    rule.timeout_ac_mins * 60
                };
                match rule.name.as_str() {
                    "screen-off" => so = timeout,
                    "lock" => lk = timeout,
                    "suspend" => sp = timeout,
                    _ => {}
                }
            }
            (so, lk, sp)
        };

        // Determine compositor screen power commands
        let (screen_off_cmd, screen_on_cmd) = if std::env::var("NIRI_SOCKET").is_ok() {
            (
                "niri msg action power-off-monitors",
                "niri msg action power-on-monitors",
            )
        } else if std::env::var("HYPRLAND_INSTANCE_SIGNATURE").is_ok() {
            ("hyprctl dispatch dpms off", "hyprctl dispatch dpms on")
        } else {
            ("wlopm --off '*'", "wlopm --on '*'")
        };

        let mut cmd = Command::new("swayidle");
        cmd.arg("-w");

        // Screen off rule
        if screen_off_secs > 0 {
            cmd.arg("timeout")
                .arg(screen_off_secs.to_string())
                .arg(screen_off_cmd)
                .arg("resume")
                .arg(screen_on_cmd);
        }

        // Screen lock rule
        if lock_secs > 0 {
            cmd.arg("timeout")
                .arg(lock_secs.to_string())
                .arg("agl lock");
        }

        // System suspend rule
        if suspend_secs > 0 {
            cmd.arg("timeout")
                .arg(suspend_secs.to_string())
                .arg("systemctl suspend");
        }

        match cmd.spawn() {
            Ok(child) => {
                *self.idle_child.lock().unwrap() = Some(child);
                info!(
                    "Started swayidle monitor [AC/Bat: {}, screen_off: {}s, lock: {}s, suspend: {}s]",
                    if on_bat { "Battery" } else { "AC" },
                    screen_off_secs,
                    lock_secs,
                    suspend_secs
                );
            }
            Err(e) => {
                warn!("Failed to spawn swayidle: {e:#}");
            }
        }
    }

    /// Stop running `swayidle` monitor process.
    pub fn stop_idle_monitor(&self) {
        kill_child(&self.idle_child);
    }

    /// Start background watcher loop checking power status and managing lifecycle.
    pub fn start_watcher(self: &Arc<Self>, mut shutdown_rx: broadcast::Receiver<()>) {
        let service = Arc::clone(self);
        service.start_idle_monitor();

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(Duration::from_secs(5));
            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        info!("Shutting down Power service. Cleaning up child processes...");
                        kill_child(&service.inhibit_child);
                        kill_child(&service.night_light_child);
                        kill_child(&service.idle_child);
                        break;
                    }
                    _ = ticker.tick() => {
                        let on_bat = Self::detect_on_battery();
                        service.update_battery_status(on_bat);
                    }
                }
            }
        });
    }

    /// Check if an executable is present in PATH.
    fn has_binary(bin: &str) -> bool {
        Command::new("which")
            .arg(bin)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    /// Detect if system is currently running on battery power via `/sys/class/power_supply`.
    pub fn detect_on_battery() -> bool {
        let ps_path = Path::new("/sys/class/power_supply");
        if !ps_path.is_dir() {
            return false;
        }

        let mut has_battery = false;
        let mut battery_discharging = false;
        let mut ac_online = false;

        if let Ok(entries) = fs::read_dir(ps_path) {
            for entry in entries.flatten() {
                let path = entry.path();
                let type_path = path.join("type");
                let supply_type = fs::read_to_string(type_path)
                    .unwrap_or_default()
                    .trim()
                    .to_string();

                if supply_type == "Mains" {
                    if let Ok(online_val) = fs::read_to_string(path.join("online")) {
                        if online_val.trim() == "1" {
                            ac_online = true;
                        }
                    }
                } else if supply_type == "Battery" {
                    has_battery = true;
                    if let Ok(status) = fs::read_to_string(path.join("status")) {
                        if status.trim().eq_ignore_ascii_case("discharging") {
                            battery_discharging = true;
                        }
                    }
                }
            }
        }

        if ac_online {
            false
        } else if has_battery {
            battery_discharging
        } else {
            false
        }
    }

    /// Detect active power profile via `powerprofilesctl get` if available.
    pub fn detect_power_profile() -> String {
        if Self::has_binary("powerprofilesctl") {
            if let Ok(output) = Command::new("powerprofilesctl").arg("get").output() {
                if output.status.success() {
                    let profile = String::from_utf8_lossy(&output.stdout).trim().to_string();
                    if VALID_POWER_PROFILES.contains(&profile.as_str()) {
                        return profile;
                    }
                }
            }
        }
        "balanced".to_string()
    }

    /// Persist current PowerState snapshot to `~/.cache/agility-shell/power_state.json`.
    fn save_state(&self) -> Result<()> {
        let state_file = self.cache_dir.join("power_state.json");
        if let Some(parent) = state_file.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let content = serde_json::to_string_pretty(&self.get_power_state())?;
        let tmp_file = state_file.with_file_name(format!("power_tmp_{}.json", std::process::id()));
        fs::write(&tmp_file, content)?;
        fs::rename(&tmp_file, &state_file)?;
        Ok(())
    }
}

/// D-Bus interface wrapper implementing `org.agility.Daemon.Power`.
pub struct PowerInterface {
    service: Arc<PowerService>,
}

impl PowerInterface {
    pub fn new(service: Arc<PowerService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Power")]
impl PowerInterface {
    #[zbus(property)]
    async fn caffeine_active(&self) -> bool {
        self.service.is_caffeine_active()
    }

    #[zbus(property)]
    async fn power_profile(&self) -> String {
        self.service.get_power_profile()
    }

    #[zbus(property)]
    async fn night_light_active(&self) -> bool {
        self.service.is_night_light_active()
    }

    #[zbus(property)]
    async fn night_light_temperature(&self) -> u32 {
        self.service.get_night_light_temperature()
    }

    #[zbus(property)]
    async fn on_battery(&self) -> bool {
        self.service.is_on_battery()
    }

    /// Retrieve full power state JSON snapshot.
    async fn get_power_state(&self) -> String {
        self.service.get_power_state_json()
    }

    /// Toggle Caffeine idle inhibitor mode.
    async fn toggle_caffeine(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let active = self.service.toggle_caffeine();
        let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        active
    }

    /// Explicitly set Caffeine idle inhibitor state.
    async fn set_caffeine(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        active: bool,
    ) -> bool {
        let res = self.service.set_caffeine(active);
        let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        res
    }

    /// Set power profile ("power-saver", "balanced", "performance").
    async fn set_power_profile(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        profile: &str,
    ) -> bool {
        let success = self.service.set_power_profile(profile);
        if success {
            let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        }
        success
    }

    /// Toggle Night Light color temperature filter.
    async fn toggle_night_light(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let active = self.service.toggle_night_light();
        let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        active
    }

    /// Explicitly set Night Light active state.
    async fn set_night_light(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        active: bool,
    ) -> bool {
        let res = self.service.set_night_light(active);
        let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        res
    }

    /// Set Night Light color temperature in Kelvin.
    async fn set_night_light_temperature(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        kelvin: u32,
    ) {
        if self.service.set_night_light_temperature(kelvin) {
            let _ = Self::power_state_changed(&emitter, &self.service.get_power_state_json()).await;
        }
    }

    /// Emitted when power state changes.
    #[zbus(signal)]
    pub async fn power_state_changed(
        emitter: &SignalEmitter<'_>,
        state_json: &str,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};

    struct TestDirGuard(PathBuf);
    impl Drop for TestDirGuard {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    static TEST_COUNTER: AtomicU64 = AtomicU64::new(1);

    fn create_test_service() -> (Arc<PowerService>, TestDirGuard) {
        let seq = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_power_{nanos}_{seq}"));
        let config_dir = temp_dir.join("config");
        let cache_dir = temp_dir.join("cache");
        let _ = fs::create_dir_all(&config_dir);
        let _ = fs::create_dir_all(&cache_dir);

        let service = PowerService::new(config_dir, cache_dir);
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_default_power_state_and_serialization() {
        let (service, _guard) = create_test_service();
        let state = service.get_power_state();

        assert!(!state.caffeine_active);
        assert!(!state.night_light_active);
        assert_eq!(state.night_light_temperature, DEFAULT_NIGHT_LIGHT_TEMP);

        let json = service.get_power_state_json();
        assert!(json.contains("caffeine_active"));
        assert!(json.contains("night_light_temperature"));
    }

    #[test]
    fn test_caffeine_toggle_and_state() {
        let (service, _guard) = create_test_service();

        assert!(!service.is_caffeine_active());

        // Toggle on
        let active = service.toggle_caffeine();
        assert!(active);
        assert!(service.is_caffeine_active());

        // Toggle off
        let active_off = service.toggle_caffeine();
        assert!(!active_off);
        assert!(!service.is_caffeine_active());

        // Explicit set
        assert!(service.set_caffeine(true));
        assert!(service.is_caffeine_active());
        assert!(!service.set_caffeine(false));
        assert!(!service.is_caffeine_active());
    }

    #[test]
    fn test_power_profile_validation_and_switching() {
        let (service, _guard) = create_test_service();

        // Valid profiles
        assert!(service.set_power_profile("power-saver"));
        assert_eq!(service.get_power_profile(), "power-saver");

        assert!(service.set_power_profile("performance"));
        assert_eq!(service.get_power_profile(), "performance");

        assert!(service.set_power_profile("balanced"));
        assert_eq!(service.get_power_profile(), "balanced");

        // Invalid profile rejected
        assert!(!service.set_power_profile("ultra-turbo-invalid"));
        assert_eq!(service.get_power_profile(), "balanced");
    }

    #[test]
    fn test_night_light_toggle_and_temperature_clamping() {
        let (service, _guard) = create_test_service();

        assert!(!service.is_night_light_active());

        // Toggle on
        assert!(service.toggle_night_light());
        assert!(service.is_night_light_active());

        // Set temperature within bounds
        assert!(service.set_night_light_temperature(3500));
        assert_eq!(service.get_night_light_temperature(), 3500);

        // Clamp below minimum (1000)
        assert!(service.set_night_light_temperature(500));
        assert_eq!(service.get_night_light_temperature(), MIN_NIGHT_LIGHT_TEMP);

        // Clamp above maximum (10000)
        assert!(service.set_night_light_temperature(15000));
        assert_eq!(service.get_night_light_temperature(), MAX_NIGHT_LIGHT_TEMP);

        // Toggle off
        assert!(!service.toggle_night_light());
        assert!(!service.is_night_light_active());
    }

    #[test]
    fn test_persistence_across_service_restarts() {
        let (service1, guard) = create_test_service();

        service1.set_caffeine(true);
        service1.set_night_light(true);
        service1.set_night_light_temperature(3200);
        service1.set_power_profile("performance");

        // Recreate service from same directory
        let service2 = PowerService::new(service1.config_dir.clone(), service1.cache_dir.clone());
        let state2 = service2.get_power_state();

        assert!(state2.caffeine_active);
        assert!(state2.night_light_active);
        assert_eq!(state2.night_light_temperature, 3200);
        assert_eq!(state2.power_profile, "performance");

        // Cleanup
        service1.set_caffeine(false);
        service1.set_night_light(false);
        service2.set_caffeine(false);
        service2.set_night_light(false);
        drop(guard);
    }
}
