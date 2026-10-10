//! Freedesktop Notification Server (`org.freedesktop.Notifications`) and Persistent History Store.
//! Implements Freedesktop Desktop Notifications Specification v1.2.

use agility_common::{NotificationAction, NotificationItem, NotificationUrgency};
use anyhow::Result;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};
use zbus::object_server::SignalEmitter;
use zbus::zvariant::OwnedValue;

/// Maximum notifications kept in the persistent history store.
pub const MAX_HISTORY_ITEMS: usize = 200;

/// Default notification expiration timeout when -1 or 0 is passed.
pub const DEFAULT_EXPIRE_TIMEOUT_MS: i32 = 5000;

/// Freedesktop notification capabilities supported by agilityd.
pub const NOTIFICATION_CAPABILITIES: &[&str] = &[
    "body",
    "body-hyperlinks",
    "body-markup",
    "body-images",
    "actions",
    "action-icons",
    "icon-static",
    "persistence",
    "sound",
];

/// Notification subsystem engine and history store.
pub struct NotificationService {
    pub config_dir: PathBuf,
    pub cache_dir: PathBuf,
    history: Arc<RwLock<Vec<NotificationItem>>>,
    dnd: Arc<RwLock<bool>>,
    next_id: Arc<AtomicU32>,
    db_path: PathBuf,
}

impl NotificationService {
    /// Initialize notification service, loading stored history from `notifications.db`.
    pub fn new(config_dir: PathBuf, cache_dir: PathBuf) -> Arc<Self> {
        let db_path = cache_dir.join("notifications.db");
        let mut loaded_history: Vec<NotificationItem> = Vec::new();
        let mut max_id: u32 = 0;

        if db_path.exists() {
            if let Ok(content) = fs::read_to_string(&db_path) {
                if let Ok(items) = serde_json::from_str::<Vec<NotificationItem>>(&content) {
                    for item in &items {
                        if item.id > max_id {
                            max_id = item.id;
                        }
                    }
                    loaded_history = items;
                }
            }
        }

        // Also check if DND was enabled in config.json
        let config_file = config_dir.join("config").join("config.json");
        let mut initial_dnd = false;
        if config_file.exists() {
            if let Ok(content) = fs::read_to_string(&config_file) {
                if let Ok(val) = serde_json::from_str::<serde_json::Value>(&content) {
                    if let Some(dnd_val) = val
                        .get("settings")
                        .and_then(|s| s.get("dnd"))
                        .and_then(|d| d.as_bool())
                    {
                        initial_dnd = dnd_val;
                    }
                }
            }
        }

        Arc::new(Self {
            config_dir,
            cache_dir,
            history: Arc::new(RwLock::new(loaded_history)),
            dnd: Arc::new(RwLock::new(initial_dnd)),
            next_id: Arc::new(AtomicU32::new(max_id + 1)),
            db_path,
        })
    }

    /// Retrieve copy of in-memory notification history.
    pub fn get_history(&self) -> Vec<NotificationItem> {
        self.history.read().unwrap().clone()
    }

    /// Retrieve JSON serialized notification history list.
    pub fn get_history_json(&self) -> String {
        serde_json::to_string(&self.get_history()).unwrap_or_default()
    }

    /// Check if Do Not Disturb (DND) mode is currently active.
    pub fn is_dnd(&self) -> bool {
        *self.dnd.read().unwrap()
    }

    /// Set Do Not Disturb (DND) state.
    pub fn set_dnd(&self, enabled: bool) -> bool {
        *self.dnd.write().unwrap() = enabled;
        enabled
    }

    /// Toggle Do Not Disturb (DND) state.
    pub fn toggle_dnd(&self) -> bool {
        let mut dnd = self.dnd.write().unwrap();
        *dnd = !*dnd;
        *dnd
    }

    /// Clear all stored notification history.
    pub fn clear_history(&self) -> Result<()> {
        {
            let mut hist = self.history.write().unwrap();
            hist.clear();
        }
        self.save_history()
    }

    /// Dismiss a specific notification by ID.
    pub fn dismiss_notification(&self, id: u32) -> bool {
        let removed = {
            let mut hist = self.history.write().unwrap();
            let initial_len = hist.len();
            hist.retain(|n| n.id != id);
            hist.len() < initial_len
        };
        if removed {
            let _ = self.save_history();
        }
        removed
    }

    /// Process incoming notification specification.
    #[allow(clippy::too_many_arguments)]
    pub fn process_notification(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> (NotificationItem, bool) {
        let id = if replaces_id != 0 {
            replaces_id
        } else {
            self.next_id.fetch_add(1, Ordering::SeqCst)
        };

        // Parse action key-label pairs
        let mut parsed_actions = Vec::new();
        for chunk in actions.chunks(2) {
            if chunk.len() == 2 {
                parsed_actions.push(NotificationAction {
                    key: chunk[0].clone(),
                    label: chunk[1].clone(),
                });
            } else if chunk.len() == 1 {
                parsed_actions.push(NotificationAction {
                    key: chunk[0].clone(),
                    label: chunk[0].clone(),
                });
            }
        }

        // Parse hints
        let urgency = hints
            .get("urgency")
            .map(Self::parse_urgency)
            .unwrap_or(NotificationUrgency::Normal);

        let desktop_entry = hints.get("desktop-entry").and_then(Self::parse_string);
        let image_path = hints
            .get("image-path")
            .or_else(|| hints.get("image_path"))
            .and_then(Self::parse_string);
        let category = hints.get("category").and_then(Self::parse_string);
        let transient = hints
            .get("transient")
            .map(Self::parse_bool)
            .unwrap_or(false);
        let resident = hints.get("resident").map(Self::parse_bool).unwrap_or(false);
        let suppress_sound = hints
            .get("suppress-sound")
            .map(Self::parse_bool)
            .unwrap_or(false);

        let now_secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        let timeout = if expire_timeout <= 0 {
            DEFAULT_EXPIRE_TIMEOUT_MS
        } else {
            expire_timeout
        };

        let item = NotificationItem {
            id,
            app_name,
            app_icon,
            summary,
            body,
            actions: parsed_actions,
            urgency,
            timestamp: now_secs,
            desktop_entry,
            image_path,
            category,
            expire_timeout_ms: timeout,
            resident,
            transient,
        };

        // Add to history store
        {
            let mut hist = self.history.write().unwrap();
            // If replacing, remove previous instance
            if replaces_id != 0 {
                hist.retain(|n| n.id != replaces_id);
            }
            hist.insert(0, item.clone());
            if hist.len() > MAX_HISTORY_ITEMS {
                hist.truncate(MAX_HISTORY_ITEMS);
            }
        }
        let _ = self.save_history();

        let is_dnd = self.is_dnd();
        let toast_allowed = !is_dnd;

        // Play notification sound if sound is allowed and not in DND
        if toast_allowed && !suppress_sound {
            self.play_notification_sound();
        }

        (item, toast_allowed)
    }

    /// Dispatch audio notification sound trigger (`sounds/notification.wav`).
    pub fn play_notification_sound(&self) {
        let sound_paths = [
            self.config_dir.join("sounds").join("notification.wav"),
            PathBuf::from(
                "/home/cachy/github-p/github-based/agility-shell/sounds/notification.wav",
            ),
            PathBuf::from("/usr/share/sounds/freedesktop/stereo/message.oga"),
            PathBuf::from("/usr/share/sounds/freedesktop/stereo/bell.oga"),
        ];

        let target_sound = sound_paths.into_iter().find(|p| p.exists());

        if let Some(sound) = target_sound {
            // Try paplay first, then pw-play, then aplay
            let players = ["paplay", "pw-play", "aplay"];
            for player in players {
                if Command::new("which")
                    .arg(player)
                    .output()
                    .map(|o| o.status.success())
                    .unwrap_or(false)
                {
                    let _ = Command::new(player).arg(&sound).spawn();
                    break;
                }
            }
        }
    }

    /// Persist current history snapshot to `~/.cache/agility-shell/notifications.db`.
    fn save_history(&self) -> Result<()> {
        if let Some(parent) = self.db_path.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let content = serde_json::to_string_pretty(&self.get_history())?;
        let tmp_file = self
            .db_path
            .with_file_name(format!("notif_tmp_{}.json", std::process::id()));
        fs::write(&tmp_file, content)?;
        fs::rename(&tmp_file, &self.db_path)?;
        Ok(())
    }

    fn parse_urgency(hint: &OwnedValue) -> NotificationUrgency {
        if let Ok(v) = u8::try_from(hint) {
            return NotificationUrgency::from(v);
        }
        if let Ok(v) = i16::try_from(hint) {
            return NotificationUrgency::from(v as u8);
        }
        if let Ok(v) = i32::try_from(hint) {
            return NotificationUrgency::from(v as u8);
        }
        if let Ok(v) = u32::try_from(hint) {
            return NotificationUrgency::from(v as u8);
        }
        NotificationUrgency::Normal
    }

    fn parse_string(hint: &OwnedValue) -> Option<String> {
        <&str>::try_from(hint).map(|s| s.to_string()).ok()
    }

    fn parse_bool(hint: &OwnedValue) -> bool {
        bool::try_from(hint).unwrap_or(false)
    }
}

/// D-Bus interface implementing `org.freedesktop.Notifications`.
pub struct NotificationsInterface {
    service: Arc<NotificationService>,
}

impl NotificationsInterface {
    pub fn new(service: Arc<NotificationService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl NotificationsInterface {
    /// Retrieve notification server capabilities.
    async fn get_capabilities(&self) -> Vec<String> {
        NOTIFICATION_CAPABILITIES
            .iter()
            .map(|s| s.to_string())
            .collect()
    }

    /// Dispatch incoming notification per Freedesktop spec.
    #[allow(clippy::too_many_arguments)]
    async fn notify(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> zbus::fdo::Result<u32> {
        let (item, toast_allowed) = self.service.process_notification(
            app_name,
            replaces_id,
            app_icon,
            summary,
            body,
            actions,
            hints,
            expire_timeout,
        );

        let item_json = serde_json::to_string(&item).unwrap_or_default();

        if toast_allowed {
            let _ = Self::notification_toast(&emitter, &item_json).await;
        }
        let _ = Self::history_changed(&emitter).await;

        Ok(item.id)
    }

    /// Close an active or stored notification.
    async fn close_notification(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        id: u32,
    ) -> zbus::fdo::Result<()> {
        self.service.dismiss_notification(id);
        let _ = Self::notification_closed(&emitter, id, 3).await; // 3 = closed by call
        let _ = Self::history_changed(&emitter).await;
        Ok(())
    }

    /// Query server vendor, name, version, and spec version.
    async fn get_server_information(&self) -> (String, String, String, String) {
        (
            "Agility Shell".to_string(),
            "TattvaOrg".to_string(),
            env!("CARGO_PKG_VERSION").to_string(),
            "1.2".to_string(),
        )
    }

    /// Retrieve full notification history JSON for Quickshell Notification Drawer.
    async fn get_history(&self) -> String {
        self.service.get_history_json()
    }

    /// Clear all stored notifications in history.
    async fn clear_history(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let success = self.service.clear_history().is_ok();
        let _ = Self::history_changed(&emitter).await;
        success
    }

    /// Dismiss a specific notification by ID from drawer.
    async fn dismiss_notification(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        id: u32,
    ) -> bool {
        let removed = self.service.dismiss_notification(id);
        if removed {
            let _ = Self::notification_closed(&emitter, id, 2).await; // 2 = dismissed by user
            let _ = Self::history_changed(&emitter).await;
        }
        removed
    }

    /// Invoke an action callback on a notification.
    async fn invoke_action(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        id: u32,
        action_key: String,
    ) -> zbus::fdo::Result<()> {
        let _ = Self::action_invoked(&emitter, id, &action_key).await;
        Ok(())
    }

    /// Query current Do Not Disturb status.
    async fn get_dnd(&self) -> bool {
        self.service.is_dnd()
    }

    /// Set Do Not Disturb status.
    async fn set_dnd(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        enabled: bool,
    ) -> bool {
        let res = self.service.set_dnd(enabled);
        let _ = Self::dnd_changed(&emitter, enabled).await;
        res
    }

    /// Toggle Do Not Disturb status.
    async fn toggle_dnd(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let new_state = self.service.toggle_dnd();
        let _ = Self::dnd_changed(&emitter, new_state).await;
        new_state
    }

    /// Emitted when a notification is closed.
    #[zbus(signal)]
    pub async fn notification_closed(
        emitter: &SignalEmitter<'_>,
        id: u32,
        reason: u32,
    ) -> zbus::Result<()>;

    /// Emitted when a notification action button is activated.
    #[zbus(signal)]
    pub async fn action_invoked(
        emitter: &SignalEmitter<'_>,
        id: u32,
        action_key: &str,
    ) -> zbus::Result<()>;

    /// Emitted when a new notification toast should be rendered by Quickshell.
    #[zbus(signal)]
    pub async fn notification_toast(
        emitter: &SignalEmitter<'_>,
        notification_json: &str,
    ) -> zbus::Result<()>;

    /// Emitted when notification history changes or clears.
    #[zbus(signal)]
    pub async fn history_changed(emitter: &SignalEmitter<'_>) -> zbus::Result<()>;

    /// Emitted when Do Not Disturb status changes.
    #[zbus(signal)]
    pub async fn dnd_changed(emitter: &SignalEmitter<'_>, enabled: bool) -> zbus::Result<()>;
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

    fn create_test_service() -> (Arc<NotificationService>, TestDirGuard) {
        let unique = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_notif_{unique}"));
        let config_dir = temp_dir.join("config");
        let cache_dir = temp_dir.join("cache");
        let _ = fs::create_dir_all(&config_dir);
        let _ = fs::create_dir_all(&cache_dir);

        let service = NotificationService::new(config_dir, cache_dir);
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_process_notification_and_persistence() {
        let (service, _guard) = create_test_service();

        let mut hints = HashMap::new();
        hints.insert("urgency".to_string(), OwnedValue::from(2u8)); // Critical

        let (item, toast_allowed) = service.process_notification(
            "TestApp".to_string(),
            0,
            "test-icon".to_string(),
            "Test Title".to_string(),
            "Test Body Content".to_string(),
            vec!["default".to_string(), "Open".to_string()],
            hints,
            5000,
        );

        assert_eq!(item.id, 1);
        assert_eq!(item.app_name, "TestApp");
        assert_eq!(item.urgency, NotificationUrgency::Critical);
        assert_eq!(item.actions.len(), 1);
        assert_eq!(item.actions[0].key, "default");
        assert_eq!(item.actions[0].label, "Open");
        assert!(toast_allowed);

        // Verify history contains item
        let history = service.get_history();
        assert_eq!(history.len(), 1);
        assert_eq!(history[0].id, 1);

        // Verify file persisted on disk at notifications.db
        assert!(service.db_path.exists());
        let content = fs::read_to_string(&service.db_path).unwrap();
        assert!(content.contains("Test Title"));
    }

    #[test]
    fn test_dnd_suppresses_toast() {
        let (service, _guard) = create_test_service();
        assert!(!service.is_dnd());

        // Enable DND
        service.set_dnd(true);
        assert!(service.is_dnd());

        let (_item, toast_allowed) = service.process_notification(
            "App".to_string(),
            0,
            "".to_string(),
            "Title".to_string(),
            "Body".to_string(),
            vec![],
            HashMap::new(),
            5000,
        );

        // In DND mode, toast must be suppressed
        assert!(!toast_allowed);

        // But still stored in history
        assert_eq!(service.get_history().len(), 1);
    }

    #[test]
    fn test_dismiss_and_clear_history() {
        let (service, _guard) = create_test_service();

        let (item1, _) = service.process_notification(
            "App1".to_string(),
            0,
            "".to_string(),
            "Notif 1".to_string(),
            "Body 1".to_string(),
            vec![],
            HashMap::new(),
            5000,
        );

        let (item2, _) = service.process_notification(
            "App2".to_string(),
            0,
            "".to_string(),
            "Notif 2".to_string(),
            "Body 2".to_string(),
            vec![],
            HashMap::new(),
            5000,
        );

        assert_eq!(service.get_history().len(), 2);

        // Dismiss first item
        assert!(service.dismiss_notification(item1.id));
        assert_eq!(service.get_history().len(), 1);
        assert_eq!(service.get_history()[0].id, item2.id);

        // Clear all history
        service.clear_history().unwrap();
        assert_eq!(service.get_history().len(), 0);
    }

    #[test]
    fn test_server_information_and_capabilities() {
        let (service, _guard) = create_test_service();
        let iface = NotificationsInterface::new(service);

        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let (name, vendor, version, spec) = iface.get_server_information().await;
            assert_eq!(name, "Agility Shell");
            assert_eq!(vendor, "TattvaOrg");
            assert_eq!(spec, "1.2");
            assert!(!version.is_empty());

            let caps = iface.get_capabilities().await;
            assert!(caps.contains(&"body".to_string()));
            assert!(caps.contains(&"actions".to_string()));
            assert!(caps.contains(&"persistence".to_string()));
        });
    }
}
