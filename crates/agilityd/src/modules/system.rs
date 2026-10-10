//! System management engine (top processes scanner, process termination, system power actions).
//! Implements `org.agility.Daemon.System` D-Bus interface.

use serde::{Deserialize, Serialize};
use std::sync::{Arc, RwLock};
use std::time::Duration;
use sysinfo::{Pid, ProcessesToUpdate, System};
use tokio::sync::broadcast;
use tracing::{debug, info};
use zbus::object_server::SignalEmitter;

/// Process entry structure for top process list.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessEntry {
    pub pid: u32,
    pub name: String,
    pub cpu_percent: f32,
    pub memory_mb: u64,
}

/// D-Bus Service implementing `org.agility.Daemon.System`.
#[derive(Clone)]
pub struct SystemService {
    top_processes: Arc<RwLock<Vec<ProcessEntry>>>,
    updates_available: Arc<RwLock<u32>>,
}

impl SystemService {
    pub fn new() -> Arc<Self> {
        let mut sys = System::new();
        sys.refresh_processes(ProcessesToUpdate::All, true);
        let initial_procs = Self::sample_top_processes(&mut sys);

        Arc::new(Self {
            top_processes: Arc::new(RwLock::new(initial_procs)),
            updates_available: Arc::new(RwLock::new(0)),
        })
    }

    /// Sample top 15 processes sorted by CPU descending.
    fn sample_top_processes(sys: &mut System) -> Vec<ProcessEntry> {
        sys.refresh_processes(ProcessesToUpdate::All, true);
        let mut procs: Vec<ProcessEntry> = sys
            .processes()
            .iter()
            .map(|(pid, proc_info)| ProcessEntry {
                pid: pid.as_u32(),
                name: proc_info.name().to_string_lossy().to_string(),
                cpu_percent: (proc_info.cpu_usage() * 10.0).round() / 10.0,
                memory_mb: proc_info.memory() / 1_048_576,
            })
            .collect();

        // Sort descending by CPU usage, secondary sort by memory
        procs.sort_by(|a, b| {
            b.cpu_percent
                .partial_cmp(&a.cpu_percent)
                .unwrap_or(std::cmp::Ordering::Equal)
                .then_with(|| b.memory_mb.cmp(&a.memory_mb))
        });

        procs.truncate(15);
        procs
    }

    /// Starts background process polling every 3 seconds.
    pub fn start_polling(
        self: &Arc<Self>,
        interval: Duration,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let procs_ref = Arc::clone(&self.top_processes);

        tokio::spawn(async move {
            let mut sys = System::new();
            let mut ticker = tokio::time::interval(interval);

            debug!("System processes background poller started");

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Shutting down system processes poller");
                        break;
                    }
                    _ = ticker.tick() => {
                        let top = Self::sample_top_processes(&mut sys);
                        if let Ok(mut lock) = procs_ref.write() {
                            *lock = top;
                        }
                    }
                }
            }
        });
    }

    /// Trigger power action via systemctl / logind.
    fn trigger_system_command(action: &str) -> zbus::fdo::Result<()> {
        info!("Executing system action: systemctl {action}");
        let status = std::process::Command::new("systemctl")
            .arg(action)
            .status()
            .map_err(|e| zbus::fdo::Error::Failed(format!("Failed to execute systemctl {action}: {e}")))?;

        if status.success() {
            Ok(())
        } else {
            Err(zbus::fdo::Error::Failed(format!("systemctl {action} exited with non-zero status")))
        }
    }
}

#[zbus::interface(name = "org.agility.Daemon.System")]
impl SystemService {
    /// Live array of processes {pid, name, cpu_percent, memory_mb} sorted descending by CPU.
    #[zbus(property)]
    async fn top_processes(&self) -> String {
        let procs = self.top_processes.read().unwrap();
        serde_json::to_string(&*procs).unwrap_or_else(|_| "[]".to_string())
    }

    /// Number of pending system updates.
    #[zbus(property)]
    async fn updates_available(&self) -> u32 {
        *self.updates_available.read().unwrap()
    }

    /// Gracefully terminate (SIGTERM) or kill target process by PID.
    async fn kill_process(&self, pid: u32) -> zbus::fdo::Result<bool> {
        info!("Requesting termination for process PID {pid}");
        let mut sys = System::new();
        sys.refresh_processes(ProcessesToUpdate::Some(&[Pid::from_u32(pid)]), true);

        if let Some(proc_info) = sys.process(Pid::from_u32(pid)) {
            let ok = proc_info.kill();
            Ok(ok)
        } else {
            // Process not found or already exited
            Ok(false)
        }
    }

    /// Queries pending system updates asynchronously.
    async fn check_updates(&self) -> zbus::fdo::Result<u32> {
        info!("Checking for system updates...");
        let count = match std::process::Command::new("checkupdates").output() {
            Ok(output) if output.status.success() => {
                let lines = String::from_utf8_lossy(&output.stdout);
                lines.lines().count() as u32
            }
            _ => 0,
        };

        if let Ok(mut lock) = self.updates_available.write() {
            *lock = count;
        }

        Ok(count)
    }

    /// Trigger system power off.
    async fn power_off(&self) -> zbus::fdo::Result<()> {
        Self::trigger_system_command("poweroff")
    }

    /// Trigger system reboot.
    async fn reboot(&self) -> zbus::fdo::Result<()> {
        Self::trigger_system_command("reboot")
    }

    /// Trigger system suspend.
    async fn suspend(&self) -> zbus::fdo::Result<()> {
        Self::trigger_system_command("suspend")
    }

    /// Trigger system hibernation.
    async fn hibernate(&self) -> zbus::fdo::Result<()> {
        Self::trigger_system_command("hibernate")
    }

    /// Terminate user session.
    async fn logout(&self) -> zbus::fdo::Result<()> {
        info!("Terminating active user session");
        let _ = std::process::Command::new("loginctl")
            .arg("terminate-session")
            .arg("")
            .status();
        Ok(())
    }

    /// Signal emitted when pending update count changes.
    #[zbus(signal)]
    pub async fn update_available(emitter: &SignalEmitter<'_>, count: u32) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_top_processes_sampling() {
        let service = SystemService::new();
        let top = service.top_processes.read().unwrap().clone();
        assert!(!top.is_empty(), "Should capture at least 1 running process");
        assert!(top.len() <= 15, "Should truncate to at most 15 processes");
        for proc in top {
            assert!(proc.pid > 0);
            assert!(!proc.name.is_empty());
        }
    }

    #[tokio::test]
    async fn test_kill_nonexistent_process_returns_false() {
        let service = SystemService::new();
        // A high PID that doesn't exist
        let result = service.kill_process(999999).await;
        assert!(result.is_ok());
        assert!(!result.unwrap());
    }
}
