//! System Information Tool (Replaces quickshell/agility/Scripts/system/get_system_info.py and get_processes.py)

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;
use sysinfo::System;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemSpecs {
    pub os: String,
    pub host: String,
    pub kernel: String,
    pub hostname: String,
    pub username: String,
    pub shell: String,
    pub wm: String,
    pub packages: String,
    pub display: String,
    pub cpu_model: String,
    pub cpu_cores: usize,
    pub ram_total: String,
    pub disk_total: String,
    pub gpus: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProcessItem {
    pub pid: usize,
    pub comm: String,
    pub cpu: f32,
    pub memory_mb: f64,
}

pub fn get_system_specs() -> SystemSpecs {
    let mut sys = System::new_all();
    sys.refresh_all();

    // OS Name
    let os_name = System::name().unwrap_or_else(|| "Linux".to_string());
    let os_version = System::os_version().unwrap_or_default();
    let os = if !os_version.is_empty() {
        format!("{os_name} {os_version}")
    } else {
        os_name
    };

    // Host
    let host = get_host_model();

    // Kernel
    let kernel = System::kernel_version().unwrap_or_default();

    // Hostname
    let hostname = System::host_name().unwrap_or_default();

    // Username
    let username = std::env::var("USER")
        .or_else(|_| std::env::var("LOGNAME"))
        .unwrap_or_default();

    // Shell
    let shell_path = std::env::var("SHELL").unwrap_or_else(|_| "zsh".to_string());
    let shell = Path::new(&shell_path)
        .file_name()
        .and_then(|f| f.to_str())
        .unwrap_or("zsh")
        .to_string();

    // Window Manager
    let wm = get_wm();

    // Packages count
    let packages = get_package_counts();

    // Displays
    let display = get_displays();

    // CPU info
    let cpu_model = sys
        .cpus()
        .first()
        .map(|c| c.brand().trim().to_string())
        .unwrap_or_else(|| "Unknown CPU".to_string());
    let cpu_cores = sys.cpus().len();

    // RAM Total
    let total_ram_gb = sys.total_memory() as f64 / (1024.0 * 1024.0 * 1024.0);
    let ram_total = format!("{total_ram_gb:.1} GB");

    // Root disk total
    let disk_total = get_root_disk_total();

    // GPU
    let gpus = get_gpus();

    SystemSpecs {
        os,
        host,
        kernel,
        hostname,
        username,
        shell,
        wm,
        packages,
        display,
        cpu_model,
        cpu_cores,
        ram_total,
        disk_total,
        gpus,
    }
}

fn get_host_model() -> String {
    for dmi in &["/sys/devices/virtual/dmi/id", "/sys/class/dmi/id"] {
        let p_name = Path::new(dmi).join("product_name");
        let s_vendor = Path::new(dmi).join("sys_vendor");
        if let Ok(name) = fs::read_to_string(p_name) {
            let trimmed = name.trim();
            if !trimmed.is_empty() && !trimmed.eq_ignore_ascii_case("system product name") {
                if let Ok(vendor) = fs::read_to_string(s_vendor) {
                    let v_trim = vendor.trim();
                    if !v_trim.is_empty() && !trimmed.starts_with(v_trim) {
                        return format!("{v_trim} {trimmed}");
                    }
                }
                return trimmed.to_string();
            }
        }
    }
    "Generic PC".to_string()
}

fn get_package_counts() -> String {
    let n_pacman = Command::new("sh")
        .arg("-c")
        .arg("pacman -Qn 2>/dev/null | wc -l")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(0);

    let n_aur = Command::new("sh")
        .arg("-c")
        .arg("pacman -Qm 2>/dev/null | wc -l")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .and_then(|s| s.trim().parse::<u32>().ok())
        .unwrap_or(0);

    if n_aur > 0 {
        format!("{n_pacman} (pacman), {n_aur} (aur)")
    } else {
        format!("{n_pacman} (pacman)")
    }
}

fn get_displays() -> String {
    if let Ok(out) = Command::new("hyprctl").args(["monitors", "-j"]).output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            if let Ok(val) = serde_json::from_str::<serde_json::Value>(&s) {
                if let Some(arr) = val.as_array() {
                    let parts: Vec<String> = arr
                        .iter()
                        .filter_map(|m| {
                            let w = m.get("width")?.as_u64()?;
                            let h = m.get("height")?.as_u64()?;
                            let rr = m.get("refreshRate")?.as_f64()?;
                            Some(format!("{w}x{h} @ {rr:.0}Hz"))
                        })
                        .collect();
                    if !parts.is_empty() {
                        return parts.join(", ");
                    }
                }
            }
        }
    }
    "1920x1080 @ 60Hz".to_string()
}

fn get_root_disk_total() -> String {
    unsafe {
        let mut stat: libc::statvfs = std::mem::zeroed();
        let path = std::ffi::CString::new("/").unwrap();
        if libc::statvfs(path.as_ptr(), &mut stat) == 0 {
            let total_bytes = stat.f_blocks as u64 * stat.f_frsize as u64;
            let gb = total_bytes as f64 / (1024.0 * 1024.0 * 1024.0);
            return format!("{gb:.0} GB");
        }
    }
    "0 GB".to_string()
}

fn get_gpus() -> String {
    if let Ok(out) = Command::new("lspci").output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            for line in s.lines() {
                if line.contains("VGA compatible controller") || line.contains("3D controller") {
                    if let Some((_, rest)) = line.split_once(": ") {
                        let cleaned = rest
                            .replace("Corporation", "")
                            .replace("Inc.", "")
                            .trim()
                            .to_string();
                        return cleaned;
                    }
                }
            }
        }
    }
    "Integrated Graphics".to_string()
}

fn get_wm() -> String {
    // 1. Direct environment checks
    if std::env::var("NIRI_SOCKET").is_ok() {
        return "Niri (Wayland)".to_string();
    }
    if std::env::var("HYPRLAND_INSTANCE_SIGNATURE").is_ok() {
        return "Hyprland (Wayland)".to_string();
    }
    if std::env::var("SWAYSOCK").is_ok() {
        return "Sway (Wayland)".to_string();
    }

    // 2. Check XDG_RUNTIME_DIR for niri socket
    if let Ok(runtime_dir) = std::env::var("XDG_RUNTIME_DIR") {
        let p = Path::new(&runtime_dir);
        if let Ok(entries) = fs::read_dir(p) {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().to_string();
                if name.starts_with("niri.") && name.ends_with(".sock") {
                    return "Niri (Wayland)".to_string();
                }
            }
        }
    }

    // 3. Process inspection
    if Command::new("pidof")
        .arg("niri")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        return "Niri (Wayland)".to_string();
    }
    if Command::new("pidof")
        .arg("Hyprland")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        return "Hyprland (Wayland)".to_string();
    }
    if Command::new("pidof")
        .arg("sway")
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
    {
        return "Sway (Wayland)".to_string();
    }

    // 4. Desktop session environment variables
    if let Ok(desktop) = std::env::var("XDG_CURRENT_DESKTOP") {
        let lower = desktop.to_lowercase();
        if lower.contains("niri") {
            return "Niri (Wayland)".to_string();
        } else if lower.contains("hyprland") {
            return "Hyprland (Wayland)".to_string();
        } else if lower.contains("sway") {
            return "Sway (Wayland)".to_string();
        } else if lower.contains("gnome") {
            return "GNOME (Wayland)".to_string();
        } else if lower.contains("kde") {
            return "KDE Plasma (Wayland)".to_string();
        }
        return format!("{desktop} (Wayland)");
    }

    if let Ok(session) = std::env::var("DESKTOP_SESSION") {
        let lower = session.to_lowercase();
        if lower.contains("niri") {
            return "Niri (Wayland)".to_string();
        } else if lower.contains("hyprland") {
            return "Hyprland (Wayland)".to_string();
        }
        return format!("{session} (Wayland)");
    }

    "Wayland".to_string()
}

pub fn get_processes() -> Vec<ProcessItem> {
    let mut sys = System::new_all();
    sys.refresh_all();

    let mut list = Vec::new();
    for (pid, process) in sys.processes() {
        list.push(ProcessItem {
            pid: pid.as_u32() as usize,
            comm: process.name().to_string_lossy().to_string(),
            cpu: process.cpu_usage(),
            memory_mb: process.memory() as f64 / (1024.0 * 1024.0),
        });
    }

    list.sort_by(|a, b| {
        b.cpu
            .partial_cmp(&a.cpu)
            .unwrap_or(std::cmp::Ordering::Equal)
    });
    list
}

pub fn run_specs() -> i32 {
    let specs = get_system_specs();
    match serde_json::to_string(&specs) {
        Ok(json) => {
            println!("{json}");
            0
        }
        Err(e) => {
            eprintln!("Error serializing specs: {e}");
            1
        }
    }
}

pub fn run_processes() -> i32 {
    let procs = get_processes();
    match serde_json::to_string(&procs) {
        Ok(json) => {
            println!("{json}");
            0
        }
        Err(e) => {
            eprintln!("Error serializing processes: {e}");
            1
        }
    }
}
