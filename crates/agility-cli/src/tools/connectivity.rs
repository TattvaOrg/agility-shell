//! Connectivity Tools (Replaces quickshell/agility/Modules/ControlCenter/scripts/wifi.py and bluetooth.py)

use serde::{Deserialize, Serialize};
use std::process::Command;

// ─── Bluetooth ───

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BtDevice {
    pub mac: String,
    pub name: String,
    pub connected: bool,
    pub paired: bool,
    pub icon: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BtStatus {
    pub powered: bool,
    pub discovering: bool,
    pub connected_device: String,
    pub devices: Vec<BtDevice>,
}

pub fn get_bluetooth_status() -> BtStatus {
    let show_out = Command::new("bluetoothctl")
        .arg("show")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    let powered = show_out.contains("Powered: yes");
    let discovering = show_out.contains("Discovering: yes");

    let devices_out = Command::new("bluetoothctl")
        .arg("devices")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    let mut devices = Vec::new();
    let mut connected_device = String::new();

    for line in devices_out.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 3 && parts[0] == "Device" {
            let mac = parts[1].to_string();
            let name = parts[2..].join(" ");

            let info_out = Command::new("bluetoothctl")
                .args(["info", &mac])
                .output()
                .ok()
                .and_then(|o| String::from_utf8(o.stdout).ok())
                .unwrap_or_default();

            let connected = info_out.contains("Connected: yes");
            let paired = info_out.contains("Paired: yes");
            let icon = if info_out.contains("Icon: audio-card")
                || info_out.contains("Icon: audio-headset")
            {
                "audio-headset".to_string()
            } else if info_out.contains("Icon: input-mouse") {
                "input-mouse".to_string()
            } else if info_out.contains("Icon: input-keyboard") {
                "input-keyboard".to_string()
            } else {
                "bluetooth".to_string()
            };

            if connected && connected_device.is_empty() {
                connected_device = name.clone();
            }

            devices.push(BtDevice {
                mac,
                name,
                connected,
                paired,
                icon,
            });
        }
    }

    BtStatus {
        powered,
        discovering,
        connected_device,
        devices,
    }
}

pub fn run_bluetooth(args: &[String]) -> i32 {
    let action = args.first().map(|s| s.as_str()).unwrap_or("status");
    match action {
        "status" => {
            let st = get_bluetooth_status();
            println!("{}", serde_json::to_string(&st).unwrap_or_default());
            0
        }
        "toggle-power" => {
            let st = get_bluetooth_status();
            let target = if st.powered { "off" } else { "on" };
            let _ = Command::new("bluetoothctl")
                .args(["power", target])
                .status();
            0
        }
        "toggle-connect" => {
            if let Some(mac) = args.get(1) {
                let st = get_bluetooth_status();
                let is_conn = st.devices.iter().any(|d| d.mac == *mac && d.connected);
                if is_conn {
                    let _ = Command::new("bluetoothctl")
                        .args(["disconnect", mac])
                        .status();
                } else {
                    let _ = Command::new("bluetoothctl").args(["connect", mac]).status();
                }
                0
            } else {
                eprintln!("Missing MAC address");
                1
            }
        }
        "scan" => {
            let _ = Command::new("bluetoothctl")
                .args(["--timeout", "5", "scan", "on"])
                .status();
            let st = get_bluetooth_status();
            println!("{}", serde_json::to_string(&st).unwrap_or_default());
            0
        }
        _ => {
            eprintln!("Unknown bluetooth action: {action}");
            1
        }
    }
}

// ─── WiFi ───

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WifiStatus {
    pub radio: bool,
    pub connected_ssid: String,
    pub strength: u8,
    pub icon: String,
    pub interface: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WifiNetwork {
    pub ssid: String,
    pub in_use: bool,
    pub active: bool,
    pub strength: u8,
    pub signal: u8,
    pub security: String,
    pub saved: bool,
}

pub fn get_wifi_status() -> WifiStatus {
    let radio_out = Command::new("nmcli")
        .args(["radio", "wifi"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_lowercase())
        .unwrap_or_default();
    let radio = radio_out.contains("enabled");

    let dev_out = Command::new("nmcli")
        .args(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    let mut interface = String::new();
    let mut connected_ssid = "Disconnected".to_string();

    for line in dev_out.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 3 && parts[1] == "wifi" {
            interface = parts[0].to_string();
            if parts[2] == "connected" && parts.len() >= 4 && !parts[3].is_empty() {
                connected_ssid = parts[3].to_string();
            }
            break;
        }
    }

    let mut strength = 0;
    if connected_ssid != "Disconnected" {
        let sig_out = Command::new("nmcli")
            .args(["-t", "-f", "IN-USE,SIGNAL", "device", "wifi"])
            .output()
            .ok()
            .and_then(|o| String::from_utf8(o.stdout).ok())
            .unwrap_or_default();
        for line in sig_out.lines() {
            if line.starts_with('*') {
                if let Some(s) = line.split(':').nth(1) {
                    strength = s.trim().parse::<u8>().unwrap_or(0);
                    break;
                }
            }
        }
    }

    let icon = if !radio || connected_ssid == "Disconnected" {
        "wifi-off"
    } else if strength > 75 {
        "wifi"
    } else if strength > 50 {
        "wifi-2"
    } else if strength > 25 {
        "wifi-1"
    } else {
        "wifi-0"
    }
    .to_string();

    WifiStatus {
        radio,
        connected_ssid,
        strength,
        icon,
        interface,
    }
}

pub fn get_wifi_networks() -> Vec<WifiNetwork> {
    // 1. Discover saved WiFi connections from NetworkManager
    let saved_out = Command::new("nmcli")
        .args(["-t", "-f", "NAME,TYPE", "connection", "show"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    let mut saved_ssids = std::collections::HashSet::new();
    for line in saved_out.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 2
            && (parts[1].contains("wireless")
                || parts[1].contains("wifi")
                || parts[1] == "802-11-wireless")
        {
            saved_ssids.insert(parts[0].trim().to_string());
        }
    }

    let out = Command::new("nmcli")
        .args([
            "-t",
            "-f",
            "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
        ])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    let mut networks = Vec::new();
    let mut seen_ssids = std::collections::HashSet::new();
    for line in out.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 4 {
            let in_use = parts[0] == "*";
            let ssid = parts[1].trim().to_string();
            if ssid.is_empty() || ssid == "--" {
                continue;
            }
            if seen_ssids.contains(&ssid) {
                continue;
            }
            seen_ssids.insert(ssid.clone());
            let strength = parts[2].trim().parse::<u8>().unwrap_or(0);
            let security = parts[3].trim().to_string();
            let saved = saved_ssids.contains(&ssid) || in_use;

            networks.push(WifiNetwork {
                ssid,
                in_use,
                active: in_use,
                strength,
                signal: strength,
                security,
                saved,
            });
        }
    }

    networks.sort_by(|a, b| {
        b.in_use
            .cmp(&a.in_use)
            .then_with(|| b.saved.cmp(&a.saved))
            .then_with(|| b.strength.cmp(&a.strength))
    });
    networks
}

pub fn run_wifi(args: &[String]) -> i32 {
    let action = args.first().map(|s| s.as_str()).unwrap_or("status");
    match action {
        "status" => {
            let st = get_wifi_status();
            println!("{}", serde_json::to_string(&st).unwrap_or_default());
            0
        }
        "toggle-radio" => {
            let st = get_wifi_status();
            let target = if st.radio { "off" } else { "on" };
            let _ = Command::new("nmcli")
                .args(["radio", "wifi", target])
                .status();
            0
        }
        "scan" => {
            let networks = get_wifi_networks();
            println!("{}", serde_json::to_string(&networks).unwrap_or_default());
            0
        }
        "connect" => {
            if let Some(ssid) = args.get(1) {
                let mut cmd = Command::new("nmcli");
                cmd.args(["device", "wifi", "connect", ssid]);
                if let Some(pw) = args.get(2) {
                    if !pw.is_empty() {
                        cmd.args(["password", pw]);
                    }
                }
                let status = cmd.status();
                if status.map(|s| s.success()).unwrap_or(false) {
                    0
                } else {
                    1
                }
            } else {
                eprintln!("Missing SSID");
                1
            }
        }
        "disconnect" => {
            if let Some(ssid) = args.get(1) {
                let _ = Command::new("nmcli")
                    .args(["connection", "down", "id", ssid])
                    .status();
                0
            } else {
                eprintln!("Missing SSID");
                1
            }
        }
        "forget" => {
            if let Some(ssid) = args.get(1) {
                let _ = Command::new("nmcli")
                    .args(["connection", "delete", "id", ssid])
                    .status();
                0
            } else {
                eprintln!("Missing SSID");
                1
            }
        }
        _ => {
            eprintln!("Unknown wifi action: {action}");
            1
        }
    }
}
