//! Hardware & System Telemetry Engine (/proc, /sysfs, battery, thermals, storage).
//! Implements high-speed non-blocking monitoring and `org.agility.Daemon.Hardware` D-Bus interface.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::sync::{Arc, RwLock};
use std::time::Duration;
use sysinfo::Disks;
use tokio::sync::broadcast;
use tracing::debug;
use zbus::object_server::SignalEmitter;

/// Per-core and total CPU measurement state from /proc/stat.
#[derive(Debug, Clone, Copy, Default)]
struct CpuTick {
    user: u64,
    nice: u64,
    system: u64,
    idle: u64,
    iowait: u64,
    irq: u64,
    softirq: u64,
    steal: u64,
}

impl CpuTick {
    fn total(&self) -> u64 {
        self.user + self.nice + self.system + self.idle + self.iowait + self.irq + self.softirq + self.steal
    }

    fn idle_all(&self) -> u64 {
        self.idle + self.iowait
    }

    fn delta_usage(&self, previous: &CpuTick) -> f64 {
        let total_delta = self.total().saturating_sub(previous.total());
        let idle_delta = self.idle_all().saturating_sub(previous.idle_all());
        if total_delta == 0 {
            0.0
        } else {
            let active = total_delta.saturating_sub(idle_delta);
            ((active as f64 / total_delta as f64) * 100.0).clamp(0.0, 100.0)
        }
    }
}

/// Mounted filesystem storage representation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StorageDevice {
    pub mount: String,
    pub used_gb: f64,
    pub total_gb: f64,
    pub percentage: f64,
}

/// Full snapshot of hardware metrics.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HardwareSnapshot {
    pub cpu_usage: f64,
    pub cpu_cores: Vec<f64>,
    pub ram_used_bytes: u64,
    pub ram_total_bytes: u64,
    pub swap_used_bytes: u64,
    pub swap_total_bytes: u64,
    pub battery_percentage: f64,
    pub battery_state: String,
    pub battery_time_remaining: i64,
    pub temperature_cpu: f64,
    pub storage_devices: Vec<StorageDevice>,
}

impl Default for HardwareSnapshot {
    fn default() -> Self {
        Self {
            cpu_usage: 0.0,
            cpu_cores: Vec::new(),
            ram_used_bytes: 0,
            ram_total_bytes: 1,
            swap_used_bytes: 0,
            swap_total_bytes: 0,
            battery_percentage: 100.0,
            battery_state: "Not Present".to_string(),
            battery_time_remaining: -1,
            temperature_cpu: 40.0,
            storage_devices: Vec::new(),
        }
    }
}

/// Core telemetry engine sampling Linux sysfs and procfs.
pub struct TelemetryEngine {
    prev_total_cpu: CpuTick,
    prev_core_cpus: Vec<CpuTick>,
    disks: Disks,
}

impl Default for TelemetryEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl TelemetryEngine {
    pub fn new() -> Self {
        let mut engine = Self {
            prev_total_cpu: CpuTick::default(),
            prev_core_cpus: Vec::new(),
            disks: Disks::new_with_refreshed_list(),
        };

        // Seed initial CPU ticks
        if let Ok((total, cores)) = Self::read_proc_stat() {
            engine.prev_total_cpu = total;
            engine.prev_core_cpus = cores;
        }

        engine
    }

    /// Read raw CPU counters from /proc/stat.
    fn read_proc_stat() -> Result<(CpuTick, Vec<CpuTick>)> {
        let content = fs::read_to_string("/proc/stat")?;
        let mut total_tick = CpuTick::default();
        let mut core_ticks = Vec::new();

        for line in content.lines() {
            if line.starts_with("cpu ") {
                let parts: Vec<u64> = line
                    .split_whitespace()
                    .skip(1)
                    .filter_map(|s| s.parse().ok())
                    .collect();
                if parts.len() >= 8 {
                    total_tick = CpuTick {
                        user: parts[0],
                        nice: parts[1],
                        system: parts[2],
                        idle: parts[3],
                        iowait: parts[4],
                        irq: parts[5],
                        softirq: parts[6],
                        steal: parts[7],
                    };
                }
            } else if line.starts_with("cpu") && line.chars().nth(3).map(|c| c.is_ascii_digit()).unwrap_or(false) {
                let parts: Vec<u64> = line
                    .split_whitespace()
                    .skip(1)
                    .filter_map(|s| s.parse().ok())
                    .collect();
                if parts.len() >= 8 {
                    core_ticks.push(CpuTick {
                        user: parts[0],
                        nice: parts[1],
                        system: parts[2],
                        idle: parts[3],
                        iowait: parts[4],
                        irq: parts[5],
                        softirq: parts[6],
                        steal: parts[7],
                    });
                }
            }
        }

        Ok((total_tick, core_ticks))
    }

    /// Sample CPU usage percentage via delta between previous tick and now.
    pub fn sample_cpu(&mut self) -> (f64, Vec<f64>) {
        if let Ok((curr_total, curr_cores)) = Self::read_proc_stat() {
            let total_usage = curr_total.delta_usage(&self.prev_total_cpu);
            self.prev_total_cpu = curr_total;

            let mut cores_usage = Vec::with_capacity(curr_cores.len());
            for (idx, core) in curr_cores.iter().enumerate() {
                if let Some(prev) = self.prev_core_cpus.get(idx) {
                    cores_usage.push(core.delta_usage(prev));
                } else {
                    cores_usage.push(0.0);
                }
            }
            self.prev_core_cpus = curr_cores;

            (total_usage, cores_usage)
        } else {
            (0.0, Vec::new())
        }
    }

    /// Sample RAM and Swap bytes from /proc/meminfo.
    pub fn sample_memory() -> (u64, u64, u64, u64) {
        let Ok(content) = fs::read_to_string("/proc/meminfo") else {
            return (0, 0, 0, 0);
        };

        let mut mem_total_kb = 0u64;
        let mut mem_avail_kb = 0u64;
        let mut swap_total_kb = 0u64;
        let mut swap_free_kb = 0u64;

        for line in content.lines() {
            let mut parts = line.split_whitespace();
            if let Some(key) = parts.next() {
                if let Some(val_str) = parts.next() {
                    let val: u64 = val_str.parse().unwrap_or(0);
                    match key {
                        "MemTotal:" => mem_total_kb = val,
                        "MemAvailable:" => mem_avail_kb = val,
                        "SwapTotal:" => swap_total_kb = val,
                        "SwapFree:" => swap_free_kb = val,
                        _ => {}
                    }
                }
            }
        }

        let ram_total_bytes = mem_total_kb * 1024;
        let ram_used_bytes = ram_total_bytes.saturating_sub(mem_avail_kb * 1024);
        let swap_total_bytes = swap_total_kb * 1024;
        let swap_used_bytes = swap_total_bytes.saturating_sub(swap_free_kb * 1024);

        (ram_used_bytes, ram_total_bytes, swap_used_bytes, swap_total_bytes)
    }

    /// Sample battery status, percentage, and time remaining from sysfs.
    pub fn sample_battery() -> (f64, String, i64) {
        let base = Path::new("/sys/class/power_supply");
        if !base.exists() {
            return (100.0, "Not Present".to_string(), -1);
        }

        let Ok(entries) = fs::read_dir(base) else {
            return (100.0, "Not Present".to_string(), -1);
        };

        for entry in entries.flatten() {
            let name = entry.file_name().to_string_lossy().to_string();
            if name.starts_with("BAT") {
                let path = entry.path();
                let capacity = fs::read_to_string(path.join("capacity"))
                    .ok()
                    .and_then(|s| s.trim().parse::<f64>().ok())
                    .unwrap_or(100.0);

                let status = fs::read_to_string(path.join("status"))
                    .map(|s| s.trim().to_string())
                    .unwrap_or_else(|_| "Unknown".to_string());

                // Calculate time remaining if available
                let current_now = fs::read_to_string(path.join("current_now"))
                    .or_else(|_| fs::read_to_string(path.join("power_now")))
                    .ok()
                    .and_then(|s| s.trim().parse::<f64>().ok());

                let charge_now = fs::read_to_string(path.join("charge_now"))
                    .or_else(|_| fs::read_to_string(path.join("energy_now")))
                    .ok()
                    .and_then(|s| s.trim().parse::<f64>().ok());

                let charge_full = fs::read_to_string(path.join("charge_full"))
                    .or_else(|_| fs::read_to_string(path.join("energy_full")))
                    .ok()
                    .and_then(|s| s.trim().parse::<f64>().ok());

                let time_remaining = match (status.as_str(), current_now, charge_now, charge_full) {
                    ("Discharging", Some(rate), Some(now), _) if rate > 0.0 => {
                        ((now / rate) * 3600.0) as i64
                    }
                    ("Charging", Some(rate), Some(now), Some(full)) if rate > 0.0 => {
                        (((full - now).max(0.0) / rate) * 3600.0) as i64
                    }
                    _ => -1,
                };

                return (capacity, status, time_remaining);
            }
        }

        (100.0, "Not Present".to_string(), -1)
    }

    /// Sample CPU package temperature in °C from /sys/class/thermal or /sys/class/hwmon.
    pub fn sample_temperature() -> f64 {
        let thermal_dir = Path::new("/sys/class/thermal");
        if let Ok(entries) = fs::read_dir(thermal_dir) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("thermal_zone") {
                    let temp_path = entry.path().join("temp");
                    if let Ok(val_str) = fs::read_to_string(&temp_path) {
                        if let Ok(milli) = val_str.trim().parse::<f64>() {
                            if milli > 0.0 && milli < 150000.0 {
                                return milli / 1000.0;
                            }
                        }
                    }
                }
            }
        }

        45.0
    }

    /// Sample storage mounts with used/total space in GB.
    pub fn sample_storage(&mut self) -> Vec<StorageDevice> {
        self.disks.refresh(true);
        let mut devices = Vec::new();

        for disk in &self.disks {
            let mount = disk.mount_point().to_string_lossy().to_string();
            // Focus on root, home, and standard mounts
            if mount == "/" || mount.starts_with("/home") || mount.starts_with("/run/media") {
                let total_bytes = disk.total_space();
                let avail_bytes = disk.available_space();
                let used_bytes = total_bytes.saturating_sub(avail_bytes);

                let total_gb = (total_bytes as f64 / 1_073_741_824.0 * 100.0).round() / 100.0;
                let used_gb = (used_bytes as f64 / 1_073_741_824.0 * 100.0).round() / 100.0;
                let percentage = if total_bytes > 0 {
                    ((used_bytes as f64 / total_bytes as f64) * 100.0).clamp(0.0, 100.0)
                } else {
                    0.0
                };

                devices.push(StorageDevice {
                    mount,
                    used_gb,
                    total_gb,
                    percentage,
                });
            }
        }

        devices
    }
}

/// D-Bus Service implementing `org.agility.Daemon.Hardware`.
#[derive(Clone)]
pub struct HardwareService {
    snapshot: Arc<RwLock<HardwareSnapshot>>,
}

impl HardwareService {
    pub fn new() -> Arc<Self> {
        let mut engine = TelemetryEngine::new();
        let (cpu, cores) = engine.sample_cpu();
        let (r_used, r_total, s_used, s_total) = TelemetryEngine::sample_memory();
        let (bat_pct, bat_state, bat_time) = TelemetryEngine::sample_battery();
        let temp = TelemetryEngine::sample_temperature();
        let storage = engine.sample_storage();

        let initial_snapshot = HardwareSnapshot {
            cpu_usage: cpu,
            cpu_cores: cores,
            ram_used_bytes: r_used,
            ram_total_bytes: r_total,
            swap_used_bytes: s_used,
            swap_total_bytes: s_total,
            battery_percentage: bat_pct,
            battery_state: bat_state,
            battery_time_remaining: bat_time,
            temperature_cpu: temp,
            storage_devices: storage,
        };

        Arc::new(Self {
            snapshot: Arc::new(RwLock::new(initial_snapshot)),
        })
    }

    /// Spawns background telemetry poller (1s fast tick, 10s slow tick).
    pub fn start_polling(
        self: &Arc<Self>,
        fast_interval: Duration,
        slow_interval: Duration,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let snapshot_ref = Arc::clone(&self.snapshot);

        tokio::spawn(async move {
            let mut engine = TelemetryEngine::new();
            let mut fast_ticker = tokio::time::interval(fast_interval);
            let mut slow_ticker = tokio::time::interval(slow_interval);

            // Initial slow metrics
            let (mut bat_pct, mut bat_state, mut bat_time) = TelemetryEngine::sample_battery();
            let mut temp = TelemetryEngine::sample_temperature();
            let mut storage = engine.sample_storage();

            debug!("Telemetry background poller started");

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Shutting down telemetry poller");
                        break;
                    }
                    _ = slow_ticker.tick() => {
                        let (b_p, b_s, b_t) = TelemetryEngine::sample_battery();
                        bat_pct = b_p;
                        bat_state = b_s;
                        bat_time = b_t;
                        temp = TelemetryEngine::sample_temperature();
                        storage = engine.sample_storage();
                    }
                    _ = fast_ticker.tick() => {
                        let (cpu, cores) = engine.sample_cpu();
                        let (r_used, r_total, s_used, s_total) = TelemetryEngine::sample_memory();

                        if let Ok(mut lock) = snapshot_ref.write() {
                            lock.cpu_usage = cpu;
                            lock.cpu_cores = cores;
                            lock.ram_used_bytes = r_used;
                            lock.ram_total_bytes = r_total;
                            lock.swap_used_bytes = s_used;
                            lock.swap_total_bytes = s_total;
                            lock.battery_percentage = bat_pct;
                            lock.battery_state = bat_state.clone();
                            lock.battery_time_remaining = bat_time;
                            lock.temperature_cpu = temp;
                            lock.storage_devices = storage.clone();
                        }
                    }
                }
            }
        });
    }

    /// Retrieve current snapshot copy.
    pub fn get_snapshot(&self) -> HardwareSnapshot {
        self.snapshot.read().unwrap().clone()
    }
}

#[zbus::interface(name = "org.agility.Daemon.Hardware")]
impl HardwareService {
    /// Total CPU usage percentage (0.0 - 100.0).
    #[zbus(property)]
    async fn cpu_usage(&self) -> f64 {
        self.snapshot.read().unwrap().cpu_usage
    }

    /// Per-core CPU usage percentages.
    #[zbus(property)]
    async fn cpu_cores(&self) -> Vec<f64> {
        self.snapshot.read().unwrap().cpu_cores.clone()
    }

    /// Memory currently used in bytes.
    #[zbus(property)]
    async fn ram_used_bytes(&self) -> u64 {
        self.snapshot.read().unwrap().ram_used_bytes
    }

    /// Total system memory in bytes.
    #[zbus(property)]
    async fn ram_total_bytes(&self) -> u64 {
        self.snapshot.read().unwrap().ram_total_bytes
    }

    /// Swap space used in bytes.
    #[zbus(property)]
    async fn swap_used_bytes(&self) -> u64 {
        self.snapshot.read().unwrap().swap_used_bytes
    }

    /// Total swap space in bytes.
    #[zbus(property)]
    async fn swap_total_bytes(&self) -> u64 {
        self.snapshot.read().unwrap().swap_total_bytes
    }

    /// Primary battery percentage.
    #[zbus(property)]
    async fn battery_percentage(&self) -> f64 {
        self.snapshot.read().unwrap().battery_percentage
    }

    /// Primary battery state ("Charging", "Discharging", "Full", "Not Present").
    #[zbus(property)]
    async fn battery_state(&self) -> String {
        self.snapshot.read().unwrap().battery_state.clone()
    }

    /// Seconds until empty or full (-1 if unavailable).
    #[zbus(property)]
    async fn battery_time_remaining(&self) -> i64 {
        self.snapshot.read().unwrap().battery_time_remaining
    }

    /// CPU package temperature in °C.
    #[zbus(property)]
    async fn temperature_cpu(&self) -> f64 {
        self.snapshot.read().unwrap().temperature_cpu
    }

    /// Filesystem storage devices serialized as JSON array.
    #[zbus(property)]
    async fn storage_devices(&self) -> String {
        serde_json::to_string(&self.snapshot.read().unwrap().storage_devices).unwrap_or_else(|_| "[]".to_string())
    }

    /// Signal emitted when telemetry is updated.
    #[zbus(signal)]
    pub async fn telemetry_updated(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_proc_stat_reading_and_cpu_calculation() {
        let mut engine = TelemetryEngine::new();
        let (cpu, cores) = engine.sample_cpu();
        assert!((0.0..=100.0).contains(&cpu));
        for core in cores {
            assert!((0.0..=100.0).contains(&core));
        }
    }

    #[test]
    fn test_memory_reading() {
        let (r_used, r_total, _s_used, _s_total) = TelemetryEngine::sample_memory();
        assert!(r_total > 0, "ram_total_bytes must be greater than 0");
        assert!(r_used <= r_total, "ram_used_bytes must not exceed ram_total_bytes");
    }

    #[test]
    fn test_hardware_service_properties() {
        let service = HardwareService::new();
        let snapshot = service.get_snapshot();
        assert!(snapshot.ram_total_bytes > 0);
        assert!(!snapshot.battery_state.is_empty());
    }
}
