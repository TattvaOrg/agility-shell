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

    let conn_out = Command::new("bluetoothctl")
        .args(["devices", "Connected"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();
    let mut connected_macs = std::collections::HashSet::new();
    for line in conn_out.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 && parts[0] == "Device" {
            connected_macs.insert(parts[1].to_string());
        }
    }

    let paired_out = Command::new("bluetoothctl")
        .args(["devices", "Paired"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();
    let mut paired_macs = std::collections::HashSet::new();
    for line in paired_out.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 2 && parts[0] == "Device" {
            paired_macs.insert(parts[1].to_string());
        }
    }

    let mut devices = Vec::new();
    let mut connected_device = String::new();

    for line in devices_out.lines() {
        let parts: Vec<&str> = line.split_whitespace().collect();
        if parts.len() >= 3 && parts[0] == "Device" {
            let mac = parts[1].to_string();
            let name = parts[2..].join(" ");

            let connected = connected_macs.contains(&mac);
            let paired = paired_macs.contains(&mac);
            let lower = name.to_lowercase();
            let icon = if lower.contains("bud")
                || lower.contains("headset")
                || lower.contains("airpod")
                || lower.contains("headphone")
                || lower.contains("audio")
                || lower.contains("speaker")
            {
                "audio-headset".to_string()
            } else if lower.contains("mouse") {
                "input-mouse".to_string()
            } else if lower.contains("keyboard") || lower.contains("keychron") {
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
        "connect" => {
            if let Some(mac) = args.get(1) {
                let _ = Command::new("bluetoothctl").args(["connect", mac]).status();
                0
            } else {
                eprintln!("Missing MAC address");
                1
            }
        }
        "disconnect" => {
            if let Some(mac) = args.get(1) {
                let _ = Command::new("bluetoothctl")
                    .args(["disconnect", mac])
                    .status();
                0
            } else {
                eprintln!("Missing MAC address");
                1
            }
        }
        "remove" | "forget" => {
            if let Some(mac) = args.get(1) {
                let _ = Command::new("bluetoothctl").args(["remove", mac]).status();
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
            let mut val = serde_json::to_value(&st).unwrap_or_default();
            if let serde_json::Value::Object(ref mut map) = val {
                map.insert(
                    "event".to_string(),
                    serde_json::Value::String("devices".to_string()),
                );
            }
            println!("{}", serde_json::to_string(&val).unwrap_or_default());
            0
        }
        _ => {
            eprintln!("Unknown bluetooth action: {action}");
            1
        }
    }
}

// ─── WiFi ───

fn split_nmcli_escaped(line: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut current = String::new();
    let mut chars = line.chars().peekable();
    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(&next_c) = chars.peek() {
                if next_c == ':' || next_c == '\\' {
                    current.push(next_c);
                    chars.next();
                    continue;
                }
            }
            current.push('\\');
        } else if c == ':' {
            fields.push(current.clone());
            current.clear();
        } else {
            current.push(c);
        }
    }
    fields.push(current);
    fields
}

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

    let mut interface = String::new();
    let mut connected_ssid = "Disconnected".to_string();
    let mut strength = 0;

    // 1. Direct query of active in-use wifi network (highest accuracy)
    let sig_out = Command::new("nmcli")
        .args(["-t", "-f", "IN-USE,SSID,SIGNAL", "device", "wifi"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    for line in sig_out.lines() {
        let parts = split_nmcli_escaped(line);
        if parts.len() >= 2 && parts[0].contains('*') {
            let ssid = parts[1].trim();
            if !ssid.is_empty() && ssid != "--" {
                connected_ssid = ssid.to_string();
            }
            if parts.len() >= 3 {
                strength = parts[2].trim().parse::<u8>().unwrap_or(0);
            }
            break;
        }
    }

    // 2. Discover interface and connection name from nmcli device
    let dev_out = Command::new("nmcli")
        .args(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .unwrap_or_default();

    for line in dev_out.lines() {
        let parts = split_nmcli_escaped(line);
        if parts.len() >= 3 && parts[1] == "wifi" {
            if interface.is_empty() {
                interface = parts[0].to_string();
            }
            if parts[2].starts_with("connected")
                && parts.len() >= 4
                && !parts[3].is_empty()
                && connected_ssid == "Disconnected"
            {
                connected_ssid = parts[3].to_string();
            }
            if parts[2].starts_with("connected") {
                interface = parts[0].to_string();
                break;
            }
        }
    }

    // If strength wasn't resolved yet but we are connected, query signal for this SSID
    if connected_ssid != "Disconnected" && strength == 0 {
        for line in sig_out.lines() {
            let parts = split_nmcli_escaped(line);
            if parts.len() >= 3 && parts[1].trim() == connected_ssid {
                strength = parts[2].trim().parse::<u8>().unwrap_or(0);
                if strength > 0 {
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
        let parts = split_nmcli_escaped(line);
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

    // Map by SSID to correctly aggregate multi-BSSID networks (e.g. 2.4GHz + 5GHz)
    let mut network_map: std::collections::HashMap<String, WifiNetwork> =
        std::collections::HashMap::new();

    for line in out.lines() {
        let parts = split_nmcli_escaped(line);
        if parts.len() >= 4 {
            let in_use = parts[0].contains('*');
            let ssid = parts[1].trim().to_string();
            if ssid.is_empty() || ssid == "--" {
                continue;
            }
            let strength = parts[2].trim().parse::<u8>().unwrap_or(0);
            let security = parts[3].trim().to_string();
            let saved = saved_ssids.contains(&ssid) || in_use;

            if let Some(existing) = network_map.get_mut(&ssid) {
                if in_use {
                    existing.in_use = true;
                    existing.active = true;
                    existing.saved = true;
                }
                if strength > existing.strength {
                    existing.strength = strength;
                    existing.signal = strength;
                }
                if (existing.security.is_empty() || existing.security == "--")
                    && !security.is_empty()
                {
                    existing.security = security;
                }
            } else {
                network_map.insert(
                    ssid.clone(),
                    WifiNetwork {
                        ssid,
                        in_use,
                        active: in_use,
                        strength,
                        signal: strength,
                        security,
                        saved,
                    },
                );
            }
        }
    }

    // Cross-reference with current wifi status so active connection is always flagged
    let current_status = get_wifi_status();
    if current_status.connected_ssid != "Disconnected" && !current_status.connected_ssid.is_empty()
    {
        if let Some(entry) = network_map.get_mut(&current_status.connected_ssid) {
            entry.in_use = true;
            entry.active = true;
            entry.saved = true;
            if current_status.strength > entry.strength {
                entry.strength = current_status.strength;
                entry.signal = current_status.strength;
            }
        } else {
            network_map.insert(
                current_status.connected_ssid.clone(),
                WifiNetwork {
                    ssid: current_status.connected_ssid.clone(),
                    in_use: true,
                    active: true,
                    strength: current_status.strength,
                    signal: current_status.strength,
                    security: "Secured".to_string(),
                    saved: true,
                },
            );
        }
    }

    let mut networks: Vec<WifiNetwork> = network_map.into_values().collect();
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
            let force_rescan = args.get(1).map(|s| s.as_str()).unwrap_or("no") == "yes";
            if force_rescan {
                let _ = Command::new("nmcli")
                    .args(["device", "wifi", "rescan"])
                    .output();
            }
            let networks = get_wifi_networks();
            let val = serde_json::json!({
                "event": "networks",
                "networks": networks
            });
            println!("{}", serde_json::to_string(&val).unwrap_or_default());
            0
        }
        "connect" => {
            if let Some(ssid) = args.get(1) {
                let password = args.get(2).map(|s| s.as_str()).unwrap_or("");

                // 1. If password is not provided, try activating existing connection first
                if password.is_empty() {
                    let up_out = Command::new("nmcli")
                        .args(["connection", "up", "id", ssid])
                        .output();
                    if let Ok(out) = up_out {
                        if out.status.success() {
                            let msg = String::from_utf8_lossy(&out.stdout);
                            println!("{}", msg.trim());
                            return 0;
                        }
                    }
                }

                // 2. Connect directly to device wifi
                let mut cmd = Command::new("nmcli");
                cmd.args(["device", "wifi", "connect", ssid]);
                if !password.is_empty() {
                    cmd.args(["password", password]);
                }
                let res = cmd.output();
                match res {
                    Ok(out) => {
                        if out.status.success() {
                            let msg = String::from_utf8_lossy(&out.stdout);
                            println!("{}", msg.trim());
                            0
                        } else {
                            // If direct connect failed with a password, the connection profile might already exist with old settings.
                            // Update the existing profile or delete and recreate with the new password.
                            if !password.is_empty() {
                                // Try updating the existing connection's password
                                let _ = Command::new("nmcli")
                                    .args([
                                        "connection",
                                        "modify",
                                        "id",
                                        ssid,
                                        "802-11-wireless-security.key-mgmt",
                                        "wpa-psk",
                                        "802-11-wireless-security.psk",
                                        password,
                                    ])
                                    .output();
                                if let Ok(retry) = Command::new("nmcli")
                                    .args(["connection", "up", "id", ssid])
                                    .output()
                                {
                                    if retry.status.success() {
                                        let msg = String::from_utf8_lossy(&retry.stdout);
                                        println!("{}", msg.trim());
                                        return 0;
                                    }
                                }

                                // If modifying didn't work, delete old connection profile and re-run connect with password
                                let _ = Command::new("nmcli")
                                    .args(["connection", "delete", "id", ssid])
                                    .output();
                                if let Ok(fresh) = Command::new("nmcli")
                                    .args(["device", "wifi", "connect", ssid, "password", password])
                                    .output()
                                {
                                    if fresh.status.success() {
                                        let msg = String::from_utf8_lossy(&fresh.stdout);
                                        println!("{}", msg.trim());
                                        return 0;
                                    }
                                }
                            } else {
                                if let Ok(retry) = Command::new("nmcli")
                                    .args(["connection", "up", "id", ssid])
                                    .output()
                                {
                                    if retry.status.success() {
                                        let msg = String::from_utf8_lossy(&retry.stdout);
                                        println!("{}", msg.trim());
                                        return 0;
                                    }
                                }
                            }
                            let err_msg = String::from_utf8_lossy(&out.stderr);
                            let stdout_msg = String::from_utf8_lossy(&out.stdout);
                            let combined = if !err_msg.trim().is_empty() {
                                err_msg.trim()
                            } else {
                                stdout_msg.trim()
                            };
                            eprintln!("Failed to connect to '{}': {}", ssid, combined);
                            1
                        }
                    }
                    Err(e) => {
                        eprintln!("Failed to execute nmcli: {}", e);
                        1
                    }
                }
            } else {
                eprintln!("Missing SSID");
                1
            }
        }
        "disconnect" => {
            let mut success = false;
            if let Some(ssid) = args.get(1) {
                let res = Command::new("nmcli")
                    .args(["connection", "down", "id", ssid])
                    .status();
                if let Ok(s) = res {
                    if s.success() {
                        success = true;
                    }
                }
            }
            if !success {
                let st = get_wifi_status();
                if !st.interface.is_empty() {
                    let res = Command::new("nmcli")
                        .args(["device", "disconnect", &st.interface])
                        .status();
                    if let Ok(s) = res {
                        if s.success() {
                            success = true;
                        }
                    }
                }
            }
            if success {
                0
            } else {
                eprintln!("Failed to disconnect Wi-Fi");
                1
            }
        }
        "forget" => {
            if let Some(ssid) = args.get(1) {
                let status = Command::new("nmcli")
                    .args(["connection", "delete", "id", ssid])
                    .status();
                status.map(|s| if s.success() { 0 } else { 1 }).unwrap_or(1)
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
