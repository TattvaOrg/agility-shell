//! Network and Bluetooth connectivity engine (NetworkManager & BlueZ).
//! Implements `org.agility.Daemon.Connectivity` D-Bus interface.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::process::Command;
use std::sync::{Arc, RwLock};
use std::time::Duration;
use tokio::sync::broadcast;
use tracing::{debug, info};
use zbus::object_server::SignalEmitter;
use zbus::Connection;

/// Scanned WiFi access point information.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct AccessPointInfo {
    pub ssid: String,
    pub strength: u8,
    pub security: String,
    pub bssid: String,
    pub active: bool,
}

/// Discovered or paired Bluetooth device.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BluetoothDeviceInfo {
    pub name: String,
    pub address: String,
    pub connected: bool,
    pub paired: bool,
    pub battery: Option<u8>,
    pub icon: String,
}

/// Unified connectivity state snapshot.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConnectivitySnapshot {
    pub wifi_enabled: bool,
    pub wifi_connected: bool,
    pub ssid: String,
    pub signal_strength: u32,
    pub ethernet_connected: bool,
    pub primary_connection: String,
    pub access_points: Vec<AccessPointInfo>,
    pub bluetooth_powered: bool,
    pub bluetooth_connected: bool,
    pub connected_device_count: u32,
    pub connected_devices: Vec<BluetoothDeviceInfo>,
    pub paired_devices: Vec<BluetoothDeviceInfo>,
}

impl Default for ConnectivitySnapshot {
    fn default() -> Self {
        Self {
            wifi_enabled: true,
            wifi_connected: false,
            ssid: String::new(),
            signal_strength: 0,
            ethernet_connected: false,
            primary_connection: "none".to_string(),
            access_points: Vec::new(),
            bluetooth_powered: false,
            bluetooth_connected: false,
            connected_device_count: 0,
            connected_devices: Vec::new(),
            paired_devices: Vec::new(),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct NetworkPollResult {
    wifi_enabled: bool,
    wifi_connected: bool,
    ssid: String,
    signal_strength: u32,
    ethernet_connected: bool,
    primary_connection: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct BluetoothPollResult {
    powered: bool,
    connected: bool,
    count: u32,
    connected_devices: Vec<BluetoothDeviceInfo>,
    paired_devices: Vec<BluetoothDeviceInfo>,
}

/// D-Bus service exposing `org.agility.Daemon.Connectivity`.
#[derive(Clone)]
pub struct ConnectivityService {
    snapshot: Arc<RwLock<ConnectivitySnapshot>>,
}

impl ConnectivityService {
    pub fn new() -> Arc<Self> {
        let mut initial = ConnectivitySnapshot::default();
        // Seed initial values from local system commands
        if let Ok(net) = poll_network_cli() {
            initial.wifi_enabled = net.wifi_enabled;
            initial.wifi_connected = net.wifi_connected;
            initial.ssid = net.ssid;
            initial.signal_strength = net.signal_strength;
            initial.ethernet_connected = net.ethernet_connected;
            initial.primary_connection = net.primary_connection;
        }
        if let Ok(bt) = poll_bluetooth_cli() {
            initial.bluetooth_powered = bt.powered;
            initial.bluetooth_connected = bt.connected;
            initial.connected_device_count = bt.count;
            initial.connected_devices = bt.connected_devices;
            initial.paired_devices = bt.paired_devices;
        }

        Arc::new(Self {
            snapshot: Arc::new(RwLock::new(initial)),
        })
    }

    /// Read active snapshot copy.
    pub fn snapshot(&self) -> ConnectivitySnapshot {
        self.snapshot.read().unwrap().clone()
    }

    /// Spawn background poller tasks for NetworkManager and BlueZ.
    pub fn start_polling(&self, interval: Duration, mut shutdown_rx: broadcast::Receiver<()>) {
        let snapshot_arc = Arc::clone(&self.snapshot);

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(interval);
            let mut scan_counter: u32 = 0;

            // Attempt to establish a system bus connection for high-speed D-Bus queries
            let system_conn = match Connection::system().await {
                Ok(c) => {
                    debug!("Connectivity poller connected to system D-Bus");
                    Some(c)
                }
                Err(e) => {
                    debug!("System D-Bus unavailable for connectivity ({e:#}); using cli fallback");
                    None
                }
            };

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Connectivity poller received shutdown signal");
                        break;
                    }
                    _ = ticker.tick() => {
                        scan_counter += 1;
                        let mut updated = false;

                        // 1. Poll Network State
                        let net_res = if let Some(ref sc) = system_conn {
                            match poll_network_dbus(sc).await {
                                Ok(res) => Ok(res),
                                Err(_) => poll_network_cli(),
                            }
                        } else {
                            poll_network_cli()
                        };

                        if let Ok(net) = net_res {
                            let mut snap = snapshot_arc.write().unwrap();
                            if snap.wifi_enabled != net.wifi_enabled
                                || snap.wifi_connected != net.wifi_connected
                                || snap.ssid != net.ssid
                                || snap.signal_strength != net.signal_strength
                                || snap.ethernet_connected != net.ethernet_connected
                                || snap.primary_connection != net.primary_connection
                            {
                                snap.wifi_enabled = net.wifi_enabled;
                                snap.wifi_connected = net.wifi_connected;
                                snap.ssid = net.ssid;
                                snap.signal_strength = net.signal_strength;
                                snap.ethernet_connected = net.ethernet_connected;
                                snap.primary_connection = net.primary_connection;
                                updated = true;
                            }
                        }

                        // 2. Poll Bluetooth State
                        let bt_res = if let Some(ref sc) = system_conn {
                            match poll_bluetooth_dbus(sc).await {
                                Ok(res) => Ok(res),
                                Err(_) => poll_bluetooth_cli(),
                            }
                        } else {
                            poll_bluetooth_cli()
                        };

                        if let Ok(bt) = bt_res {
                            let mut snap = snapshot_arc.write().unwrap();
                            if snap.bluetooth_powered != bt.powered
                                || snap.bluetooth_connected != bt.connected
                                || snap.connected_device_count != bt.count
                                || snap.connected_devices != bt.connected_devices
                                || snap.paired_devices != bt.paired_devices
                            {
                                snap.bluetooth_powered = bt.powered;
                                snap.bluetooth_connected = bt.connected;
                                snap.connected_device_count = bt.count;
                                snap.connected_devices = bt.connected_devices;
                                snap.paired_devices = bt.paired_devices;
                                updated = true;
                            }
                        }

                        // 3. Periodically poll Access Points (every ~15 ticks)
                        if scan_counter % 5 == 1 {
                            if let Ok(aps) = poll_wifi_access_points_cli() {
                                let mut snap = snapshot_arc.write().unwrap();
                                if snap.access_points != aps {
                                    snap.access_points = aps;
                                    updated = true;
                                }
                            }
                        }

                        if updated {
                            debug!("Connectivity state updated");
                        }
                    }
                }
            }
        });
    }
}

#[zbus::interface(name = "org.agility.Daemon.Connectivity")]
impl ConnectivityService {
    // ─── Network & WiFi Properties ───

    #[zbus(property)]
    async fn wifi_enabled(&self) -> bool {
        self.snapshot.read().unwrap().wifi_enabled
    }

    #[zbus(property)]
    async fn wifi_connected(&self) -> bool {
        self.snapshot.read().unwrap().wifi_connected
    }

    #[zbus(property)]
    async fn ssid(&self) -> String {
        self.snapshot.read().unwrap().ssid.clone()
    }

    #[zbus(property)]
    async fn signal_strength(&self) -> u32 {
        self.snapshot.read().unwrap().signal_strength
    }

    #[zbus(property)]
    async fn ethernet_connected(&self) -> bool {
        self.snapshot.read().unwrap().ethernet_connected
    }

    #[zbus(property)]
    async fn primary_connection(&self) -> String {
        self.snapshot.read().unwrap().primary_connection.clone()
    }

    #[zbus(property(emits_changed_signal = "false"))]
    async fn access_points(&self) -> String {
        let aps = &self.snapshot.read().unwrap().access_points;
        serde_json::to_string(aps).unwrap_or_else(|_| "[]".to_string())
    }

    // ─── Bluetooth Properties ───

    #[zbus(property)]
    async fn bluetooth_powered(&self) -> bool {
        self.snapshot.read().unwrap().bluetooth_powered
    }

    #[zbus(property)]
    async fn bluetooth_connected(&self) -> bool {
        self.snapshot.read().unwrap().bluetooth_connected
    }

    #[zbus(property)]
    async fn connected_device_count(&self) -> u32 {
        self.snapshot.read().unwrap().connected_device_count
    }

    #[zbus(property)]
    async fn connected_devices(&self) -> String {
        let devs = &self.snapshot.read().unwrap().connected_devices;
        serde_json::to_string(devs).unwrap_or_else(|_| "[]".to_string())
    }

    #[zbus(property)]
    async fn paired_devices(&self) -> String {
        let devs = &self.snapshot.read().unwrap().paired_devices;
        serde_json::to_string(devs).unwrap_or_else(|_| "[]".to_string())
    }

    // ─── Methods ───

    /// Set WiFi radio state (on/off).
    async fn set_wifi_enabled(&self, enabled: bool) -> zbus::fdo::Result<()> {
        let flag = if enabled { "on" } else { "off" };
        let _ = Command::new("nmcli").args(["radio", "wifi", flag]).output();

        let mut snap = self.snapshot.write().unwrap();
        snap.wifi_enabled = enabled;
        if !enabled {
            snap.wifi_connected = false;
            snap.ssid.clear();
            snap.signal_strength = 0;
            if snap.primary_connection == "wifi" {
                snap.primary_connection = if snap.ethernet_connected {
                    "ethernet".into()
                } else {
                    "none".into()
                };
            }
        }
        info!("Set WiFi enabled: {enabled}");
        Ok(())
    }

    /// Toggle WiFi radio state.
    async fn toggle_wifi(&self) -> zbus::fdo::Result<()> {
        let current = self.snapshot.read().unwrap().wifi_enabled;
        self.set_wifi_enabled(!current).await
    }

    /// Trigger asynchronous WiFi access point rescan.
    async fn scan_wifi(&self) -> zbus::fdo::Result<()> {
        tokio::task::spawn_blocking(|| {
            let _ = Command::new("nmcli")
                .args(["device", "wifi", "rescan"])
                .output();
        });
        Ok(())
    }

    /// Connect to a WiFi access point with given SSID and password.
    async fn connect_wifi(&self, ssid: String, password: String) -> zbus::fdo::Result<bool> {
        let res = tokio::task::spawn_blocking(move || {
            let mut cmd = Command::new("nmcli");
            cmd.args(["device", "wifi", "connect", &ssid]);
            if !password.is_empty() {
                cmd.args(["password", &password]);
            }
            match cmd.output() {
                Ok(output) => output.status.success(),
                Err(_) => false,
            }
        })
        .await
        .unwrap_or(false);

        Ok(res)
    }

    /// Disconnect current active WiFi connection.
    async fn disconnect_wifi(&self) -> zbus::fdo::Result<bool> {
        let ssid = self.snapshot.read().unwrap().ssid.clone();
        if ssid.is_empty() {
            return Ok(true);
        }

        let res = tokio::task::spawn_blocking(move || {
            match Command::new("nmcli")
                .args(["connection", "down", &ssid])
                .output()
            {
                Ok(output) => output.status.success(),
                Err(_) => false,
            }
        })
        .await
        .unwrap_or(false);

        Ok(res)
    }

    /// Set Bluetooth adapter power state.
    async fn set_bluetooth_powered(&self, powered: bool) -> zbus::fdo::Result<()> {
        let flag = if powered { "on" } else { "off" };
        let _ = Command::new("bluetoothctl").args(["power", flag]).output();

        let mut snap = self.snapshot.write().unwrap();
        snap.bluetooth_powered = powered;
        if !powered {
            snap.bluetooth_connected = false;
            snap.connected_device_count = 0;
            snap.connected_devices.clear();
        }
        info!("Set Bluetooth power: {powered}");
        Ok(())
    }

    /// Toggle Bluetooth adapter power state.
    async fn toggle_bluetooth(&self) -> zbus::fdo::Result<()> {
        let current = self.snapshot.read().unwrap().bluetooth_powered;
        self.set_bluetooth_powered(!current).await
    }

    /// Connect to a Bluetooth device by MAC address.
    async fn connect_bluetooth_device(&self, address: String) -> zbus::fdo::Result<bool> {
        let res = tokio::task::spawn_blocking(move || {
            match Command::new("bluetoothctl")
                .args(["connect", &address])
                .output()
            {
                Ok(output) => output.status.success(),
                Err(_) => false,
            }
        })
        .await
        .unwrap_or(false);

        Ok(res)
    }

    /// Disconnect from a Bluetooth device by MAC address.
    async fn disconnect_bluetooth_device(&self, address: String) -> zbus::fdo::Result<bool> {
        let res = tokio::task::spawn_blocking(move || {
            match Command::new("bluetoothctl")
                .args(["disconnect", &address])
                .output()
            {
                Ok(output) => output.status.success(),
                Err(_) => false,
            }
        })
        .await
        .unwrap_or(false);

        Ok(res)
    }

    // ─── Signals ───

    /// Emitted when primary connection or overall connectivity status changes.
    #[zbus(signal)]
    async fn connectivity_changed(
        emitter: &SignalEmitter<'_>,
        primary: &str,
        wifi_connected: bool,
        ssid: &str,
        strength: u32,
        bt_connected: bool,
        bt_count: u32,
    ) -> zbus::Result<()>;

    /// Emitted when the scanned access points list is refreshed.
    #[zbus(signal)]
    async fn access_points_changed(
        emitter: &SignalEmitter<'_>,
        access_points_json: &str,
    ) -> zbus::Result<()>;
}

// ─── Low-level Poller Helpers ───

/// Query NetworkManager via D-Bus system bus.
async fn poll_network_dbus(conn: &Connection) -> anyhow::Result<NetworkPollResult> {
    // 1. Check WirelessEnabled
    let wifi_enabled_msg = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "WirelessEnabled"),
        )
        .await?;

    let wifi_enabled = wifi_enabled_msg
        .body()
        .deserialize::<zbus::zvariant::OwnedValue>()
        .ok()
        .and_then(|v| bool::try_from(v).ok())
        .unwrap_or(true);

    // 2. Check PrimaryConnectionType
    let primary_msg = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "PrimaryConnectionType"),
        )
        .await?;

    let primary_type: String = primary_msg
        .body()
        .deserialize::<zbus::zvariant::OwnedValue>()
        .ok()
        .and_then(|v| String::try_from(v).ok())
        .unwrap_or_default();

    let is_wifi_primary = primary_type == "802-11-wireless";
    let is_eth_primary = primary_type == "802-3-ethernet";

    let primary_conn_str = if is_wifi_primary {
        "wifi".to_string()
    } else if is_eth_primary {
        "ethernet".to_string()
    } else if primary_type.is_empty() {
        "none".to_string()
    } else {
        primary_type
    };

    // 3. Check Active Primary Connection
    let mut ssid = String::new();
    let mut strength: u32 = 0;
    let mut wifi_connected = false;

    let prim_conn_obj_msg = conn
        .call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "PrimaryConnection"),
        )
        .await;

    if let Ok(msg) = prim_conn_obj_msg {
        if let Ok(val) = msg.body().deserialize::<zbus::zvariant::OwnedValue>() {
            if let Ok(obj_path) = zbus::zvariant::OwnedObjectPath::try_from(val) {
                let path_str = obj_path.as_str();
                if path_str != "/" {
                    // Query Connection Id
                    let id_msg = conn
                        .call_method(
                            Some("org.freedesktop.NetworkManager"),
                            path_str,
                            Some("org.freedesktop.DBus.Properties"),
                            "Get",
                            &("org.freedesktop.NetworkManager.Connection.Active", "Id"),
                        )
                        .await;

                    if let Ok(im) = id_msg {
                        if let Ok(v) = im.body().deserialize::<zbus::zvariant::OwnedValue>() {
                            if let Ok(s) = String::try_from(v) {
                                ssid = s;
                                wifi_connected = is_wifi_primary;
                            }
                        }
                    }

                    // Query AccessPoint SpecificObject if wifi
                    if is_wifi_primary {
                        let ap_obj_msg = conn
                            .call_method(
                                Some("org.freedesktop.NetworkManager"),
                                path_str,
                                Some("org.freedesktop.DBus.Properties"),
                                "Get",
                                &(
                                    "org.freedesktop.NetworkManager.Connection.Active",
                                    "SpecificObject",
                                ),
                            )
                            .await;

                        if let Ok(ap_msg) = ap_obj_msg {
                            if let Ok(v) = ap_msg.body().deserialize::<zbus::zvariant::OwnedValue>()
                            {
                                if let Ok(ap_path) = zbus::zvariant::OwnedObjectPath::try_from(v) {
                                    let ap_str = ap_path.as_str();
                                    if ap_str != "/" {
                                        let str_msg = conn
                                            .call_method(
                                                Some("org.freedesktop.NetworkManager"),
                                                ap_str,
                                                Some("org.freedesktop.DBus.Properties"),
                                                "Get",
                                                &(
                                                    "org.freedesktop.NetworkManager.AccessPoint",
                                                    "Strength",
                                                ),
                                            )
                                            .await;

                                        if let Ok(sm) = str_msg {
                                            if let Ok(sv) = sm
                                                .body()
                                                .deserialize::<zbus::zvariant::OwnedValue>()
                                            {
                                                if let Ok(st) = u8::try_from(sv) {
                                                    strength = st as u32;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Ok(NetworkPollResult {
        wifi_enabled,
        wifi_connected,
        ssid,
        signal_strength: strength,
        ethernet_connected: is_eth_primary,
        primary_connection: primary_conn_str,
    })
}

/// Fallback network poller via `nmcli`.
fn poll_network_cli() -> anyhow::Result<NetworkPollResult> {
    let output = Command::new("nmcli")
        .args(["-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev", "status"])
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut wifi_enabled = true;
    let mut wifi_connected = false;
    let mut ssid = String::new();
    let mut ethernet_connected = false;
    let mut primary_connection = "none".to_string();

    for line in stdout.lines() {
        let parts: Vec<&str> = line.split(':').collect();
        if parts.len() >= 4 {
            let dev_type = parts[1];
            let state = parts[2];
            let conn = parts[3];

            if dev_type == "wifi" {
                if state == "connected" {
                    wifi_connected = true;
                    ssid = conn.to_string();
                    if primary_connection == "none" {
                        primary_connection = "wifi".to_string();
                    }
                } else if state == "unavailable" {
                    wifi_enabled = false;
                }
            } else if dev_type == "ethernet" && state == "connected" {
                ethernet_connected = true;
                primary_connection = "ethernet".to_string();
            }
        }
    }

    let mut strength: u32 = 0;
    if wifi_connected && !ssid.is_empty() {
        if let Ok(aps) = poll_wifi_access_points_cli() {
            if let Some(ap) = aps.iter().find(|a| a.active || a.ssid == ssid) {
                strength = ap.strength as u32;
            }
        }
    }

    Ok(NetworkPollResult {
        wifi_enabled,
        wifi_connected,
        ssid,
        signal_strength: strength,
        ethernet_connected,
        primary_connection,
    })
}

/// Scans access points via `nmcli`.
fn poll_wifi_access_points_cli() -> anyhow::Result<Vec<AccessPointInfo>> {
    let output = Command::new("nmcli")
        .args([
            "-t",
            "-f",
            "active,ssid,signal,security,bssid",
            "dev",
            "wifi",
            "list",
        ])
        .output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    Ok(parse_nmcli_wifi_output(&stdout))
}

/// Parse tabular `nmcli dev wifi list` output into strongly typed structs.
pub fn parse_nmcli_wifi_output(output: &str) -> Vec<AccessPointInfo> {
    let mut aps = Vec::new();

    for line in output.lines() {
        // Line format: active:ssid:signal:security:bssid
        // Escaped colons in BSSID may occur as '\:'
        let normalized = line.replace("\\:", "__COLON__");
        let parts: Vec<&str> = normalized.split(':').collect();
        if parts.len() >= 5 {
            let active = parts[0].trim() == "yes" || parts[0].trim() == "*";
            let ssid = parts[1].trim().to_string();
            if ssid.is_empty() {
                continue;
            }
            let strength = parts[2].trim().parse::<u8>().unwrap_or(0);
            let security = parts[3].trim().to_string();
            let bssid = parts[4].trim().replace("__COLON__", ":");

            aps.push(AccessPointInfo {
                ssid,
                strength,
                security,
                bssid,
                active,
            });
        }
    }

    // Deduplicate by SSID, preferring active or higher strength
    let mut dedup: HashMap<String, AccessPointInfo> = HashMap::new();
    for ap in aps {
        match dedup.get(&ap.ssid) {
            Some(existing) if existing.active || existing.strength >= ap.strength => {}
            _ => {
                dedup.insert(ap.ssid.clone(), ap);
            }
        }
    }

    let mut result: Vec<AccessPointInfo> = dedup.into_values().collect();
    result.sort_by(|a, b| {
        b.active
            .cmp(&a.active)
            .then_with(|| b.strength.cmp(&a.strength))
    });
    result
}

/// Query BlueZ via D-Bus system bus.
async fn poll_bluetooth_dbus(conn: &Connection) -> anyhow::Result<BluetoothPollResult> {
    let objects_msg = conn
        .call_method(
            Some("org.bluez"),
            "/",
            Some("org.freedesktop.DBus.ObjectManager"),
            "GetManagedObjects",
            &(),
        )
        .await?;

    // ManagedObjects returns a{oa{sa{sv}}}
    let body = objects_msg.body();
    let objects: HashMap<
        zbus::zvariant::OwnedObjectPath,
        HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>,
    > = body.deserialize()?;

    let mut powered = false;
    let mut connected_devices = Vec::new();
    let mut paired_devices = Vec::new();

    for (_path, ifaces) in objects {
        // Check Adapter1 for power state
        if let Some(adapter_props) = ifaces.get("org.bluez.Adapter1") {
            if let Some(p) = adapter_props.get("Powered") {
                if let Ok(b) = bool::try_from(p) {
                    powered = b;
                }
            }
        }

        // Check Device1 for connected/paired devices
        if let Some(dev_props) = ifaces.get("org.bluez.Device1") {
            let name = dev_props
                .get("Name")
                .or_else(|| dev_props.get("Alias"))
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("Unknown Device")
                .to_string();

            let address = dev_props
                .get("Address")
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("")
                .to_string();

            let connected = dev_props
                .get("Connected")
                .and_then(|v| bool::try_from(v).ok())
                .unwrap_or(false);

            let paired = dev_props
                .get("Paired")
                .and_then(|v| bool::try_from(v).ok())
                .unwrap_or(false);

            let icon = dev_props
                .get("Icon")
                .and_then(|v| <&str>::try_from(v).ok())
                .unwrap_or("bluetooth")
                .to_string();

            // Check Battery1 interface for battery percentage
            let battery = ifaces
                .get("org.bluez.Battery1")
                .and_then(|b_props| b_props.get("Percentage"))
                .and_then(|v| u8::try_from(v).ok());

            let info = BluetoothDeviceInfo {
                name,
                address,
                connected,
                paired,
                battery,
                icon,
            };

            if connected {
                connected_devices.push(info.clone());
            }
            if paired {
                paired_devices.push(info);
            }
        }
    }

    let is_connected = !connected_devices.is_empty();
    let count = connected_devices.len() as u32;

    Ok(BluetoothPollResult {
        powered,
        connected: is_connected,
        count,
        connected_devices,
        paired_devices,
    })
}

/// Fallback bluetooth poller via `bluetoothctl`.
fn poll_bluetooth_cli() -> anyhow::Result<BluetoothPollResult> {
    let output = Command::new("bluetoothctl").arg("show").output()?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    let mut powered = false;

    for line in stdout.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with("Powered:") {
            powered = trimmed.ends_with("yes");
        }
    }

    let mut paired_devices = Vec::new();
    let mut connected_devices = Vec::new();

    if let Ok(dev_out) = Command::new("bluetoothctl").arg("devices").output() {
        let dev_str = String::from_utf8_lossy(&dev_out.stdout);
        for line in dev_str.lines() {
            // Line format: Device XX:XX:XX:XX:XX:XX Name
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 3 && parts[0] == "Device" {
                let addr = parts[1].to_string();
                let name = parts[2..].join(" ");

                let dev_info = BluetoothDeviceInfo {
                    name,
                    address: addr,
                    connected: false,
                    paired: true,
                    battery: None,
                    icon: "bluetooth".to_string(),
                };
                paired_devices.push(dev_info);
            }
        }
    }

    if let Ok(conn_out) = Command::new("bluetoothctl")
        .args(["devices", "Connected"])
        .output()
    {
        let conn_str = String::from_utf8_lossy(&conn_out.stdout);
        for line in conn_str.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 3 && parts[0] == "Device" {
                let addr = parts[1].to_string();
                let name = parts[2..].join(" ");

                let dev_info = BluetoothDeviceInfo {
                    name,
                    address: addr,
                    connected: true,
                    paired: true,
                    battery: None,
                    icon: "bluetooth".to_string(),
                };
                connected_devices.push(dev_info);
            }
        }
    }

    let count = connected_devices.len() as u32;
    let is_connected = !connected_devices.is_empty();

    Ok(BluetoothPollResult {
        powered,
        connected: is_connected,
        count,
        connected_devices,
        paired_devices,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_nmcli_wifi_output() {
        let sample = "yes:Pixel:79:WPA2 WPA3:5E\\:38\\:D7\\:A4\\:33\\:D3\nno:Sonikaka:35:WPA1 WPA2:54\\:A2\\:45\\:23\\:AE\\:52\nno:Shomyl:19:WPA2:AA\\:A9\\:15\\:8E\\:39\\:08\n";
        let aps = parse_nmcli_wifi_output(sample);

        assert_eq!(aps.len(), 3);
        assert_eq!(aps[0].ssid, "Pixel");
        assert!(aps[0].active);
        assert_eq!(aps[0].strength, 79);
        assert_eq!(aps[0].bssid, "5E:38:D7:A4:33:D3");
        assert_eq!(aps[0].security, "WPA2 WPA3");

        assert_eq!(aps[1].ssid, "Sonikaka");
        assert!(!aps[1].active);
    }

    #[test]
    fn test_connectivity_snapshot_defaults() {
        let snapshot = ConnectivitySnapshot::default();
        assert!(snapshot.wifi_enabled);
        assert!(!snapshot.wifi_connected);
        assert_eq!(snapshot.primary_connection, "none");
        assert_eq!(snapshot.connected_device_count, 0);
        assert!(snapshot.access_points.is_empty());
    }

    #[test]
    fn test_bluetooth_device_serialization() {
        let dev = BluetoothDeviceInfo {
            name: "Sony WH-1000XM4".to_string(),
            address: "00:11:22:33:44:55".to_string(),
            connected: true,
            paired: true,
            battery: Some(85),
            icon: "audio-headset".to_string(),
        };

        let json = serde_json::to_string(&dev).unwrap();
        assert!(json.contains("Sony WH-1000XM4"));
        assert!(json.contains("85"));

        let deserialized: BluetoothDeviceInfo = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized, dev);
    }
}
