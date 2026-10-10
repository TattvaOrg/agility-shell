//! Clipboard Manager Engine.
//! Implements Wayland data-control / cliphist event listener with an in-memory 50-item deduplicated ring buffer.
//! Exposes `org.agility.Daemon.Clipboard` D-Bus interface.

use agility_common::ClipboardItem;
use anyhow::Result;
use std::fs;
use std::io::Write;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, RwLock};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::broadcast;
use tracing::{info, warn};
use zbus::object_server::SignalEmitter;

/// Maximum number of clipboard items retained in the ring buffer.
pub const MAX_CLIPBOARD_ITEMS: usize = 50;

/// Maximum length of a preview string before truncating with ellipsis.
pub const PREVIEW_MAX_LEN: usize = 120;

/// Clipboard manager service managing in-memory history and Wayland clipboard interactions.
pub struct ClipboardService {
    pub cache_dir: PathBuf,
    pub max_items: usize,
    history: Arc<RwLock<Vec<ClipboardItem>>>,
    next_id: Arc<AtomicU64>,
    last_copied: Arc<RwLock<String>>,
}

impl ClipboardService {
    /// Initialize clipboard service, restoring cached items if present.
    pub fn new(cache_dir: PathBuf, max_items: usize) -> Arc<Self> {
        let history_file = cache_dir.join("clipboard_history.json");
        let mut loaded_history = Vec::new();
        let mut max_id = 0;

        if history_file.exists() {
            if let Ok(content) = fs::read_to_string(&history_file) {
                if let Ok(items) = serde_json::from_str::<Vec<ClipboardItem>>(&content) {
                    for item in &items {
                        if item.id > max_id {
                            max_id = item.id;
                        }
                    }
                    loaded_history = items;
                }
            }
        }

        Arc::new(Self {
            cache_dir,
            max_items,
            history: Arc::new(RwLock::new(loaded_history)),
            next_id: Arc::new(AtomicU64::new(max_id + 1)),
            last_copied: Arc::new(RwLock::new(String::new())),
        })
    }

    /// Retrieve full in-memory clipboard history.
    pub fn get_history(&self) -> Vec<ClipboardItem> {
        self.history.read().unwrap().clone()
    }

    /// Retrieve JSON serialized clipboard history.
    pub fn get_history_json(&self) -> String {
        serde_json::to_string(&self.get_history()).unwrap_or_default()
    }

    /// Retrieve count of stored clipboard items.
    pub fn get_item_count(&self) -> u32 {
        self.history.read().unwrap().len() as u32
    }

    /// Add a new text selection to the ring buffer with automatic deduplication.
    pub fn add_item(&self, text: &str) -> Option<ClipboardItem> {
        let trimmed = text.trim();
        if trimmed.is_empty() {
            return None;
        }

        let id = self.next_id.fetch_add(1, Ordering::SeqCst);
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();

        // Format preview
        let preview = if trimmed.chars().count() <= PREVIEW_MAX_LEN {
            trimmed.to_string()
        } else {
            let truncated: String = trimmed.chars().take(PREVIEW_MAX_LEN - 3).collect();
            format!("{truncated}...")
        };

        // Format human timestamp (HH:MM)
        let time_secs = now % 86400;
        let hours = (time_secs / 3600 + 5) % 24; // Normalized local offset approx
        let minutes = (time_secs % 3600) / 60;
        let timestamp = format!("{hours:02}:{minutes:02}");

        let item = ClipboardItem {
            id,
            text: trimmed.to_string(),
            preview,
            timestamp,
            timestamp_epoch: now,
        };

        {
            let mut hist = self.history.write().unwrap();
            // Deduplicate: remove if matching text already exists
            hist.retain(|i| i.text != trimmed);
            // Insert at the front (most recent)
            hist.insert(0, item.clone());
            // Truncate to ring buffer capacity
            if hist.len() > self.max_items {
                hist.truncate(self.max_items);
            }
        }

        let _ = self.save_history();
        Some(item)
    }

    /// Copy text back to the system Wayland clipboard using `wl-copy` and `cliphist`.
    pub fn copy_text(&self, text: &str) -> bool {
        let trimmed = text.trim();
        if trimmed.is_empty() {
            return false;
        }

        *self.last_copied.write().unwrap() = trimmed.to_string();

        // 1. Invoke wl-copy if available
        if Command::new("which")
            .arg("wl-copy")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            if let Ok(mut child) = Command::new("wl-copy").stdin(Stdio::piped()).spawn() {
                if let Some(mut stdin) = child.stdin.take() {
                    let _ = stdin.write_all(trimmed.as_bytes());
                }
                let _ = child.wait();
            }
        }

        // 2. Also feed to cliphist store if available
        if Command::new("which")
            .arg("cliphist")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            if let Ok(mut child) = Command::new("cliphist")
                .arg("store")
                .stdin(Stdio::piped())
                .spawn()
            {
                if let Some(mut stdin) = child.stdin.take() {
                    let _ = stdin.write_all(trimmed.as_bytes());
                }
                let _ = child.wait();
            }
        }

        // 3. Add to in-memory history
        self.add_item(trimmed).is_some()
    }

    /// Remove a specific clipboard item by unique ID.
    pub fn remove_item(&self, id: u64) -> bool {
        let text_to_delete = {
            let hist = self.history.read().unwrap();
            hist.iter().find(|i| i.id == id).map(|i| i.text.clone())
        };

        let removed = {
            let mut hist = self.history.write().unwrap();
            let initial_len = hist.len();
            hist.retain(|i| i.id != id);
            hist.len() < initial_len
        };

        if removed {
            if let Some(text) = text_to_delete {
                self.delete_from_cliphist(&text);
            }
            let _ = self.save_history();
        }
        removed
    }

    /// Remove a clipboard item matching the given text content.
    pub fn remove_item_by_text(&self, text: &str) -> bool {
        let trimmed = text.trim();
        let removed = {
            let mut hist = self.history.write().unwrap();
            let initial_len = hist.len();
            hist.retain(|i| i.text != trimmed);
            hist.len() < initial_len
        };

        if removed {
            self.delete_from_cliphist(trimmed);
            let _ = self.save_history();
        }
        removed
    }

    /// Clear all stored clipboard history from memory, disk, and cliphist.
    pub fn clear(&self) -> bool {
        {
            let mut hist = self.history.write().unwrap();
            hist.clear();
        }
        *self.last_copied.write().unwrap() = String::new();

        // Wipe cliphist if available
        if Command::new("which")
            .arg("cliphist")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            let _ = Command::new("cliphist").arg("wipe").output();
        }

        self.save_history().is_ok()
    }

    /// Shell out to cliphist to remove matching text if cliphist is available.
    fn delete_from_cliphist(&self, query: &str) {
        if Command::new("which")
            .arg("cliphist")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            let _ = Command::new("cliphist")
                .arg("delete-query")
                .arg(query)
                .output();
        }
    }

    /// Persist current ring buffer snapshot to `~/.cache/agility-shell/clipboard_history.json`.
    fn save_history(&self) -> Result<()> {
        let hist_file = self.cache_dir.join("clipboard_history.json");
        if let Some(parent) = hist_file.parent() {
            let _ = fs::create_dir_all(parent);
        }
        let content = serde_json::to_string_pretty(&self.get_history())?;
        let tmp_file = hist_file.with_file_name(format!("clip_tmp_{}.json", std::process::id()));
        fs::write(&tmp_file, content)?;
        fs::rename(&tmp_file, &hist_file)?;
        Ok(())
    }

    /// Launch background Wayland clipboard event listener (`wl-paste --watch cliphist store`).
    /// Ensures zero CPU usage when clipboard remains idle.
    pub fn start_watcher(self: &Arc<Self>, mut shutdown_rx: broadcast::Receiver<()>) {
        let has_wl_paste = Command::new("which")
            .arg("wl-paste")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        let has_cliphist = Command::new("which")
            .arg("cliphist")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        if !has_wl_paste || !has_cliphist {
            info!("Wayland clipboard watcher: wl-paste or cliphist not found in PATH; operating in pure in-memory mode.");
            return;
        }

        info!("Starting Wayland clipboard event listener (wl-paste --watch cliphist store)...");

        // Spawn `wl-paste --watch cliphist store` support process
        let mut child = match Command::new("wl-paste")
            .arg("--watch")
            .arg("cliphist")
            .arg("store")
            .spawn()
        {
            Ok(c) => c,
            Err(e) => {
                warn!("Failed to spawn wl-paste clipboard watcher: {e:#}");
                return;
            }
        };

        // Determine cliphist database path
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/cachy".to_string());
        let cliphist_db = PathBuf::from(&home)
            .join(".cache")
            .join("cliphist")
            .join("db");

        let service = Arc::clone(self);
        tokio::spawn(async move {
            let mut last_modified = fs::metadata(&cliphist_db).and_then(|m| m.modified()).ok();

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        info!("Terminating clipboard watcher process...");
                        let _ = child.kill();
                        break;
                    }
                    _ = tokio::time::sleep(std::time::Duration::from_millis(500)) => {
                        if let Ok(meta) = fs::metadata(&cliphist_db) {
                            if let Ok(mod_time) = meta.modified() {
                                if last_modified.map(|lm| mod_time > lm).unwrap_or(true) {
                                    last_modified = Some(mod_time);
                                    // Extract latest entry from cliphist
                                    if let Ok(out) = Command::new("sh")
                                        .arg("-c")
                                        .arg("cliphist list | head -n 1 | cliphist decode")
                                        .output()
                                    {
                                        if out.status.success() {
                                            let text = String::from_utf8_lossy(&out.stdout);
                                            let trimmed = text.trim();
                                            if !trimmed.is_empty() && trimmed != service.last_copied.read().unwrap().as_str() {
                                                service.add_item(trimmed);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        });
    }
}

/// D-Bus interface wrapper implementing `org.agility.Daemon.Clipboard`.
pub struct ClipboardInterface {
    service: Arc<ClipboardService>,
}

impl ClipboardInterface {
    pub fn new(service: Arc<ClipboardService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Clipboard")]
impl ClipboardInterface {
    /// Retrieve full clipboard history serialized as JSON.
    async fn get_history(&self) -> String {
        self.service.get_history_json()
    }

    /// Retrieve count of current clipboard items.
    async fn get_item_count(&self) -> u32 {
        self.service.get_item_count()
    }

    /// Copy text back to the system clipboard and prepend to history.
    async fn copy_text(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        text: &str,
    ) -> bool {
        let success = self.service.copy_text(text);
        if success {
            let history_json = self.service.get_history_json();
            let _ = Self::clipboard_changed(&emitter, &history_json).await;
            let _ = Self::item_copied(&emitter, text).await;
        }
        success
    }

    /// Remove a specific clipboard item by unique ID.
    async fn remove_item(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        id: u64,
    ) -> bool {
        let removed = self.service.remove_item(id);
        if removed {
            let history_json = self.service.get_history_json();
            let _ = Self::clipboard_changed(&emitter, &history_json).await;
        }
        removed
    }

    /// Remove a clipboard item by matching text content.
    async fn remove_item_by_text(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        text: &str,
    ) -> bool {
        let removed = self.service.remove_item_by_text(text);
        if removed {
            let history_json = self.service.get_history_json();
            let _ = Self::clipboard_changed(&emitter, &history_json).await;
        }
        removed
    }

    /// Add a new text selection to clipboard history.
    async fn add_item(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        text: &str,
    ) -> bool {
        let added = self.service.add_item(text).is_some();
        if added {
            let history_json = self.service.get_history_json();
            let _ = Self::clipboard_changed(&emitter, &history_json).await;
        }
        added
    }

    /// Clear all stored clipboard history.
    async fn clear(&self, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) -> bool {
        let success = self.service.clear();
        let history_json = self.service.get_history_json();
        let _ = Self::clipboard_changed(&emitter, &history_json).await;
        success
    }

    /// Emitted when clipboard history updates, an item is added, or history is cleared.
    #[zbus(signal)]
    pub async fn clipboard_changed(
        emitter: &SignalEmitter<'_>,
        history_json: &str,
    ) -> zbus::Result<()>;

    /// Emitted when text is copied to the system clipboard.
    #[zbus(signal)]
    pub async fn item_copied(emitter: &SignalEmitter<'_>, text: &str) -> zbus::Result<()>;
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

    static TEST_COUNTER: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(1);

    fn create_test_service() -> (Arc<ClipboardService>, TestDirGuard) {
        let seq = TEST_COUNTER.fetch_add(1, Ordering::SeqCst);
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_clip_{nanos}_{seq}"));
        let cache_dir = temp_dir.join("cache");
        let _ = fs::create_dir_all(&cache_dir);

        let service = ClipboardService::new(cache_dir, MAX_CLIPBOARD_ITEMS);
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_add_and_deduplicate_items() {
        let (service, _guard) = create_test_service();

        assert_eq!(service.get_item_count(), 0);

        // Add 3 items
        let _item1 = service.add_item("First line").unwrap();
        let _item2 = service.add_item("Second line").unwrap();
        let item3 = service.add_item("Third line").unwrap();

        assert_eq!(service.get_item_count(), 3);
        assert_eq!(item3.text, "Third line");

        // Re-adding First line should move it to index 0 and keep total count 3
        let item1_dup = service.add_item("First line").unwrap();
        assert_eq!(service.get_item_count(), 3);

        let hist = service.get_history();
        assert_eq!(hist[0].id, item1_dup.id);
        assert_eq!(hist[0].text, "First line");
        assert_eq!(hist[1].text, "Third line");
        assert_eq!(hist[2].text, "Second line");
    }

    #[test]
    fn test_ring_buffer_capacity_limit_50() {
        let (service, _guard) = create_test_service();

        for i in 1..=60 {
            service.add_item(&format!("Clipboard item number {i}"));
        }

        assert_eq!(service.get_item_count(), 50);
        let hist = service.get_history();
        assert_eq!(hist[0].text, "Clipboard item number 60");
        assert_eq!(hist[49].text, "Clipboard item number 11");
    }

    #[test]
    fn test_preview_string_truncation() {
        let (service, _guard) = create_test_service();

        let short_text = "Short text under 120 chars.";
        let item_short = service.add_item(short_text).unwrap();
        assert_eq!(item_short.preview, short_text);

        let long_text = "A".repeat(150);
        let item_long = service.add_item(&long_text).unwrap();
        assert!(item_long.preview.ends_with("..."));
        assert_eq!(item_long.preview.chars().count(), 120);
    }

    #[test]
    fn test_remove_and_clear_operations() {
        let (service, _guard) = create_test_service();

        let item1 = service.add_item("Item Alpha").unwrap();
        let _item2 = service.add_item("Item Beta").unwrap();
        let _item3 = service.add_item("Item Gamma").unwrap();

        assert_eq!(service.get_item_count(), 3);

        // Remove by id
        assert!(service.remove_item(item1.id));
        assert_eq!(service.get_item_count(), 2);

        // Remove by text
        assert!(service.remove_item_by_text("Item Beta"));
        assert_eq!(service.get_item_count(), 1);

        // Clear
        assert!(service.clear());
        assert_eq!(service.get_item_count(), 0);
    }

    #[test]
    fn test_persistence_across_service_restarts() {
        let (service1, guard) = create_test_service();

        service1.add_item("Persisted Alpha");
        service1.add_item("Persisted Beta");
        assert_eq!(service1.get_item_count(), 2);

        // Reopen service using same cache directory
        let service2 = ClipboardService::new(service1.cache_dir.clone(), MAX_CLIPBOARD_ITEMS);
        assert_eq!(service2.get_item_count(), 2);
        let hist = service2.get_history();
        assert_eq!(hist[0].text, "Persisted Beta");
        assert_eq!(hist[1].text, "Persisted Alpha");

        drop(guard);
    }
}
