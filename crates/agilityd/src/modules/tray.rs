//! System Tray Host (`StatusNotifierWatcher`).
//! Implements KDE StatusNotifierWatcher specification (`org.kde.StatusNotifierWatcher`) on `/StatusNotifierWatcher`.
//! Manages registration, unregistration, and streaming of third-party system tray icons.

use std::sync::{Arc, RwLock};
use tracing::info;
use zbus::object_server::SignalEmitter;

/// System Tray service tracking registered StatusNotifierItem instances and hosts.
pub struct TrayService {
    items: Arc<RwLock<Vec<String>>>,
    hosts: Arc<RwLock<Vec<String>>>,
}

impl TrayService {
    /// Initialize a new TrayService instance.
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            items: Arc::new(RwLock::new(Vec::new())),
            // Agility Shell status bar functions as default host
            hosts: Arc::new(RwLock::new(vec!["org.agility.Daemon".to_string()])),
        })
    }

    /// Register a new tray item service/path identifier. Returns true if newly added.
    pub fn register_item(&self, service: &str) -> bool {
        let trimmed = service.trim();
        if trimmed.is_empty() {
            return false;
        }

        let mut items = self.items.write().unwrap();
        if !items.contains(&trimmed.to_string()) {
            items.push(trimmed.to_string());
            info!("Registered StatusNotifierItem: {trimmed}");
            true
        } else {
            false
        }
    }

    /// Unregister a tray item by identifier or bus prefix. Returns true if removed.
    pub fn unregister_item(&self, service: &str) -> bool {
        let trimmed = service.trim();
        let mut items = self.items.write().unwrap();
        let initial_len = items.len();
        items.retain(|i| i != trimmed && !i.starts_with(&format!("{trimmed}/")));
        let removed = items.len() < initial_len;
        if removed {
            info!("Unregistered StatusNotifierItem: {trimmed}");
        }
        removed
    }

    /// Retrieve all currently registered StatusNotifierItem identifiers.
    pub fn get_items(&self) -> Vec<String> {
        self.items.read().unwrap().clone()
    }

    /// Register a StatusNotifierHost. Returns true if newly registered.
    pub fn register_host(&self, host: &str) -> bool {
        let trimmed = host.trim();
        if trimmed.is_empty() {
            return false;
        }

        let mut hosts = self.hosts.write().unwrap();
        if !hosts.contains(&trimmed.to_string()) {
            hosts.push(trimmed.to_string());
            info!("Registered StatusNotifierHost: {trimmed}");
            true
        } else {
            false
        }
    }

    /// Check if at least one StatusNotifierHost is currently active.
    pub fn is_host_registered(&self) -> bool {
        !self.hosts.read().unwrap().is_empty()
    }

    /// Retrieve all registered host names.
    pub fn get_hosts(&self) -> Vec<String> {
        self.hosts.read().unwrap().clone()
    }
}

/// D-Bus interface wrapper implementing `org.kde.StatusNotifierWatcher`.
pub struct StatusNotifierWatcherInterface {
    service: Arc<TrayService>,
}

impl StatusNotifierWatcherInterface {
    pub fn new(service: Arc<TrayService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.kde.StatusNotifierWatcher")]
impl StatusNotifierWatcherInterface {
    // ─── Properties ───

    /// List of registered StatusNotifierItems formatted as bus name or path.
    #[zbus(property, name = "RegisteredStatusNotifierItems")]
    async fn registered_status_notifier_items(&self) -> Vec<String> {
        self.service.get_items()
    }

    /// Whether a StatusNotifierHost is registered and listening.
    #[zbus(property, name = "IsStatusNotifierHostRegistered")]
    async fn is_status_notifier_host_registered(&self) -> bool {
        self.service.is_host_registered()
    }

    /// Protocol version implemented (0).
    #[zbus(property, name = "ProtocolVersion")]
    async fn protocol_version(&self) -> i32 {
        0
    }

    // ─── Methods ───

    /// Register a client's StatusNotifierItem with the watcher.
    async fn register_status_notifier_item(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: &str,
    ) -> zbus::fdo::Result<()> {
        let added = self.service.register_item(service);
        if added {
            let _ = Self::status_notifier_item_registered(&emitter, service).await;
        }
        Ok(())
    }

    /// Register a StatusNotifierHost with the watcher.
    async fn register_status_notifier_host(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: &str,
    ) -> zbus::fdo::Result<()> {
        let added = self.service.register_host(service);
        if added {
            let _ = Self::status_notifier_host_registered(&emitter).await;
        }
        Ok(())
    }

    /// Unregister a client's StatusNotifierItem from the watcher.
    async fn unregister_status_notifier_item(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        service: &str,
    ) -> zbus::fdo::Result<bool> {
        let removed = self.service.unregister_item(service);
        if removed {
            let _ = Self::status_notifier_item_unregistered(&emitter, service).await;
        }
        Ok(removed)
    }

    // ─── Signals ───

    /// Emitted when a new StatusNotifierItem registers.
    #[zbus(signal, name = "StatusNotifierItemRegistered")]
    pub async fn status_notifier_item_registered(
        emitter: &SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;

    /// Emitted when an existing StatusNotifierItem unregisters.
    #[zbus(signal, name = "StatusNotifierItemUnregistered")]
    pub async fn status_notifier_item_unregistered(
        emitter: &SignalEmitter<'_>,
        service: &str,
    ) -> zbus::Result<()>;

    /// Emitted when a StatusNotifierHost registers.
    #[zbus(signal, name = "StatusNotifierHostRegistered")]
    pub async fn status_notifier_host_registered(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_register_and_unregister_tray_item() {
        let service = TrayService::new();
        assert_eq!(service.get_items().len(), 0);

        // Register Discord
        assert!(service.register_item("org.kde.StatusNotifierItem-100-1"));
        assert_eq!(service.get_items().len(), 1);
        assert_eq!(service.get_items()[0], "org.kde.StatusNotifierItem-100-1");

        // Duplicate registration should return false
        assert!(!service.register_item("org.kde.StatusNotifierItem-100-1"));
        assert_eq!(service.get_items().len(), 1);

        // Register Steam
        assert!(service.register_item("org.kde.StatusNotifierItem-200-1"));
        assert_eq!(service.get_items().len(), 2);

        // Unregister Discord
        assert!(service.unregister_item("org.kde.StatusNotifierItem-100-1"));
        assert_eq!(service.get_items().len(), 1);
        assert_eq!(service.get_items()[0], "org.kde.StatusNotifierItem-200-1");

        // Unregister non-existent returns false
        assert!(!service.unregister_item("org.kde.StatusNotifierItem-999-1"));
    }

    #[test]
    fn test_register_host_and_properties() {
        let service = TrayService::new();
        assert!(service.is_host_registered());
        assert_eq!(service.get_hosts().len(), 1);

        assert!(service.register_host("org.kde.StatusNotifierHost-Custom"));
        assert_eq!(service.get_hosts().len(), 2);
        assert!(service.is_host_registered());
    }
}
