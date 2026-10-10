//! Compositor IPC interface (Niri socket stream, workspace management).
//! Implements multi-compositor trait abstraction and `org.agility.Daemon.Workspaces` D-Bus interface.

use agility_common::WorkspaceInfo;
use anyhow::{Context, Result};
use async_trait::async_trait;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, RwLock};
use std::time::Duration;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tokio::sync::broadcast;
use tracing::{debug, info, warn};
use zbus::object_server::SignalEmitter;

/// Unified compositor abstraction allowing support for Niri, Hyprland, and generic wlroots.
#[async_trait]
pub trait Compositor: Send + Sync {
    /// Friendly name of the compositor backend.
    fn name(&self) -> &'static str;

    /// Activate a specific workspace by ID.
    async fn activate_workspace(&self, id: u32) -> Result<()>;

    /// Close the currently focused window.
    async fn close_focused_window(&self) -> Result<()>;

    /// Switch keyboard layout by zero-based index.
    async fn switch_keyboard_layout(&self, idx: u32) -> Result<()>;

    /// Query the current workspaces list.
    async fn query_workspaces(&self) -> Result<Vec<WorkspaceInfo>>;

    /// Query the currently focused window title and app_id.
    async fn query_focused_window(&self) -> Result<(String, String)>;

    /// Query the configured keyboard layouts and current index.
    async fn query_keyboard_layouts(&self) -> Result<(Vec<String>, u32)>;
}

/// Discover active Niri socket from environment variable or standard runtime paths.
pub fn find_niri_socket() -> Option<PathBuf> {
    if let Ok(sock) = std::env::var("NIRI_SOCKET") {
        let p = PathBuf::from(sock);
        if p.exists() {
            return Some(p);
        }
    }

    let uid = std::env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| {
        std::env::var("UID")
            .map(|u| format!("/run/user/{u}"))
            .unwrap_or_else(|_| "/run/user/1000".to_string())
    });
    let runtime_path = Path::new(&uid);
    if let Ok(entries) = std::fs::read_dir(runtime_path) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(name) = path.file_name().and_then(|n| n.to_str()) {
                if name.starts_with("niri.") && name.ends_with(".sock") {
                    return Some(path);
                }
            }
        }
    }

    None
}

/// Native Niri Wayland Compositor backend communicating over Unix Domain Socket.
pub struct NiriCompositor {
    socket_path: PathBuf,
}

impl NiriCompositor {
    pub fn new(socket_path: PathBuf) -> Self {
        Self { socket_path }
    }

    /// Send a JSON request over a one-shot Unix socket connection and return parsed response.
    async fn send_request(&self, request: Value) -> Result<Value> {
        let mut stream = UnixStream::connect(&self.socket_path)
            .await
            .with_context(|| format!("Failed to connect to Niri socket at {:?}", self.socket_path))?;

        let mut payload = serde_json::to_vec(&request)?;
        payload.push(b'\n');
        stream.write_all(&payload).await?;

        let mut reader = BufReader::new(stream);
        let mut line = String::new();
        reader.read_line(&mut line).await?;

        let resp: Value = serde_json::from_str(&line)
            .with_context(|| format!("Failed to parse Niri response: {line}"))?;

        Ok(resp)
    }
}

#[async_trait]
impl Compositor for NiriCompositor {
    fn name(&self) -> &'static str {
        "Niri"
    }

    async fn activate_workspace(&self, id: u32) -> Result<()> {
        let req = json!({
            "Action": {
                "FocusWorkspace": {
                    "reference": {
                        "Id": id
                    }
                }
            }
        });
        let resp = self.send_request(req).await?;
        if resp.get("Ok").is_some() {
            Ok(())
        } else {
            anyhow::bail!("Niri error focusing workspace {id}: {resp:?}");
        }
    }

    async fn close_focused_window(&self) -> Result<()> {
        let req = json!({
            "Action": {
                "CloseWindow": {
                    "id": null
                }
            }
        });
        let resp = self.send_request(req).await?;
        if resp.get("Ok").is_some() {
            Ok(())
        } else {
            anyhow::bail!("Niri error closing focused window: {resp:?}");
        }
    }

    async fn switch_keyboard_layout(&self, idx: u32) -> Result<()> {
        let req = json!({
            "Action": {
                "SwitchLayout": {
                    "layout": {
                        "Index": idx
                    }
                }
            }
        });
        let resp = self.send_request(req).await?;
        if resp.get("Ok").is_some() {
            Ok(())
        } else {
            anyhow::bail!("Niri error switching keyboard layout to {idx}: {resp:?}");
        }
    }

    async fn query_workspaces(&self) -> Result<Vec<WorkspaceInfo>> {
        // Query windows to get window_count per workspace
        let windows_resp = self.send_request(json!("Windows")).await.unwrap_or(Value::Null);
        let mut window_counts: HashMap<u32, u32> = HashMap::new();
        if let Some(windows) = windows_resp.get("Ok").and_then(|o| o.get("Windows")).and_then(|w| w.as_array()) {
            for win in windows {
                if let Some(ws_id) = win.get("workspace_id").and_then(|v| v.as_u64()) {
                    *window_counts.entry(ws_id as u32).or_insert(0) += 1;
                }
            }
        }

        let resp = self.send_request(json!("Workspaces")).await?;
        let ws_array = resp
            .get("Ok")
            .and_then(|o| o.get("Workspaces"))
            .and_then(|w| w.as_array())
            .context("Invalid Workspaces response from Niri")?;

        let mut results = Vec::new();
        for item in ws_array {
            let id = item.get("id").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
            let idx = item.get("idx").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
            let name = item.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
            let output = item.get("output").and_then(|v| v.as_str()).unwrap_or("").to_string();
            let is_active = item.get("is_active").and_then(|v| v.as_bool()).unwrap_or(false);
            let window_count = *window_counts.get(&id).unwrap_or(&0);

            results.push(WorkspaceInfo {
                id,
                idx,
                name,
                output,
                is_active,
                window_count,
            });
        }

        Ok(results)
    }

    async fn query_focused_window(&self) -> Result<(String, String)> {
        let resp = self.send_request(json!("FocusedWindow")).await?;
        if let Some(win) = resp.get("Ok").and_then(|o| o.get("FocusedWindow")) {
            if win.is_object() {
                let title = win.get("title").and_then(|v| v.as_str()).unwrap_or("").to_string();
                let app_id = win.get("app_id").and_then(|v| v.as_str()).unwrap_or("").to_string();
                return Ok((title, app_id));
            }
        }
        Ok(("".to_string(), "".to_string()))
    }

    async fn query_keyboard_layouts(&self) -> Result<(Vec<String>, u32)> {
        let resp = self.send_request(json!("KeyboardLayouts")).await?;
        let kl = resp
            .get("Ok")
            .and_then(|o| o.get("KeyboardLayouts"))
            .context("Invalid KeyboardLayouts response from Niri")?;

        let names: Vec<String> = kl
            .get("names")
            .and_then(|n| n.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(|s| s.to_string()))
                    .collect()
            })
            .unwrap_or_default();

        let current_idx = kl.get("current_idx").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
        Ok((names, current_idx))
    }
}

/// In-memory mock compositor for automated tests and headless environments.
pub struct MockCompositor {
    workspaces: Arc<RwLock<Vec<WorkspaceInfo>>>,
    active_workspace: Arc<RwLock<u32>>,
    focused_window: Arc<RwLock<(String, String)>>,
    keyboard_layouts: Arc<RwLock<(Vec<String>, u32)>>,
}

impl MockCompositor {
    pub fn new() -> Self {
        let initial_ws = vec![
            WorkspaceInfo {
                id: 1,
                idx: 1,
                name: "1".into(),
                output: "HEADLESS-1".into(),
                is_active: true,
                window_count: 1,
            },
            WorkspaceInfo {
                id: 2,
                idx: 2,
                name: "2".into(),
                output: "HEADLESS-1".into(),
                is_active: false,
                window_count: 0,
            },
        ];

        Self {
            workspaces: Arc::new(RwLock::new(initial_ws)),
            active_workspace: Arc::new(RwLock::new(1)),
            focused_window: Arc::new(RwLock::new(("Alacritty".into(), "Alacritty".into()))),
            keyboard_layouts: Arc::new(RwLock::new((vec!["English (US)".into()], 0))),
        }
    }
}

impl Default for MockCompositor {
    fn default() -> Self {
        Self::new()
    }
}

#[async_trait]
impl Compositor for MockCompositor {
    fn name(&self) -> &'static str {
        "Mock"
    }

    async fn activate_workspace(&self, id: u32) -> Result<()> {
        let mut active = self.active_workspace.write().unwrap();
        *active = id;
        let mut ws_list = self.workspaces.write().unwrap();
        for ws in ws_list.iter_mut() {
            ws.is_active = ws.id == id;
        }
        Ok(())
    }

    async fn close_focused_window(&self) -> Result<()> {
        let mut fw = self.focused_window.write().unwrap();
        *fw = ("".into(), "".into());
        Ok(())
    }

    async fn switch_keyboard_layout(&self, idx: u32) -> Result<()> {
        let mut kl = self.keyboard_layouts.write().unwrap();
        kl.1 = idx;
        Ok(())
    }

    async fn query_workspaces(&self) -> Result<Vec<WorkspaceInfo>> {
        Ok(self.workspaces.read().unwrap().clone())
    }

    async fn query_focused_window(&self) -> Result<(String, String)> {
        Ok(self.focused_window.read().unwrap().clone())
    }

    async fn query_keyboard_layouts(&self) -> Result<(Vec<String>, u32)> {
        Ok(self.keyboard_layouts.read().unwrap().clone())
    }
}

/// D-Bus Service implementing `org.agility.Daemon.Workspaces`.
#[derive(Clone)]
pub struct WorkspacesService {
    active_workspace: Arc<RwLock<u32>>,
    workspaces: Arc<RwLock<Vec<WorkspaceInfo>>>,
    focused_window_title: Arc<RwLock<String>>,
    focused_app_id: Arc<RwLock<String>>,
    keyboard_layouts: Arc<RwLock<Vec<String>>>,
    current_keyboard_layout: Arc<RwLock<String>>,
    current_keyboard_layout_idx: Arc<RwLock<u32>>,
    compositor: Arc<dyn Compositor>,
}

impl WorkspacesService {
    pub async fn new(compositor: Arc<dyn Compositor>) -> Result<Arc<Self>> {
        let initial_ws = compositor.query_workspaces().await.unwrap_or_default();
        let active_id = initial_ws
            .iter()
            .find(|w| w.is_active)
            .map(|w| w.id)
            .unwrap_or(1);

        let (initial_title, initial_app_id) = compositor
            .query_focused_window()
            .await
            .unwrap_or_else(|_| ("".into(), "".into()));

        let (kl_names, kl_idx) = compositor
            .query_keyboard_layouts()
            .await
            .unwrap_or_else(|_| (vec!["English (US)".into()], 0));

        let current_layout_name = kl_names
            .get(kl_idx as usize)
            .cloned()
            .unwrap_or_else(|| "English (US)".into());

        let service = Arc::new(Self {
            active_workspace: Arc::new(RwLock::new(active_id)),
            workspaces: Arc::new(RwLock::new(initial_ws)),
            focused_window_title: Arc::new(RwLock::new(initial_title)),
            focused_app_id: Arc::new(RwLock::new(initial_app_id)),
            keyboard_layouts: Arc::new(RwLock::new(kl_names)),
            current_keyboard_layout: Arc::new(RwLock::new(current_layout_name)),
            current_keyboard_layout_idx: Arc::new(RwLock::new(kl_idx)),
            compositor,
        });

        Ok(service)
    }

    /// Spawns background event loop monitoring compositor socket event stream.
    pub fn start_event_stream(
        self: &Arc<Self>,
        socket_path: Option<PathBuf>,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let this = Arc::clone(self);
        tokio::spawn(async move {
            let path = match socket_path {
                Some(p) => p,
                None => {
                    debug!("No compositor socket provided for event stream; running in polled/mock mode");
                    return;
                }
            };

            info!("Starting Niri event stream listener on {:?}", path);

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Shutting down compositor event stream listener");
                        break;
                    }
                    res = Self::run_event_stream_loop(&this, &path) => {
                        if let Err(e) = res {
                            warn!("Niri event stream disconnected: {e:#}. Reconnecting in 1s...");
                            tokio::time::sleep(Duration::from_secs(1)).await;
                        }
                    }
                }
            }
        });
    }

    async fn run_event_stream_loop(service: &Arc<Self>, path: &Path) -> Result<()> {
        let mut stream = UnixStream::connect(path).await?;
        let mut payload = serde_json::to_vec(&json!("EventStream"))?;
        payload.push(b'\n');
        stream.write_all(&payload).await?;

        let mut lines = BufReader::new(stream).lines();
        while let Some(line) = lines.next_line().await? {
            if let Ok(event) = serde_json::from_str::<Value>(&line) {
                service.handle_event(event).await;
            }
        }

        Ok(())
    }

    async fn handle_event(&self, event: Value) {
        if let Some(obj) = event.as_object() {
            if let Some(ws_event) = obj.get("WorkspacesChanged") {
                if let Some(arr) = ws_event.get("workspaces").and_then(|w| w.as_array()) {
                    let mut new_list = Vec::new();
                    for item in arr {
                        let id = item.get("id").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                        let idx = item.get("idx").and_then(|v| v.as_u64()).unwrap_or(0) as u32;
                        let name = item.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
                        let output = item.get("output").and_then(|v| v.as_str()).unwrap_or("").to_string();
                        let is_active = item.get("is_active").and_then(|v| v.as_bool()).unwrap_or(false);

                        if is_active {
                            if let Ok(mut lock) = self.active_workspace.write() {
                                *lock = id;
                            }
                        }

                        new_list.push(WorkspaceInfo {
                            id,
                            idx,
                            name,
                            output,
                            is_active,
                            window_count: 0,
                        });
                    }

                    if let Ok(mut lock) = self.workspaces.write() {
                        *lock = new_list;
                    }
                }
            } else if let Some(act) = obj.get("WorkspaceActivated") {
                if let Some(id) = act.get("id").and_then(|v| v.as_u64()) {
                    let id = id as u32;
                    if let Ok(mut lock) = self.active_workspace.write() {
                        *lock = id;
                    }
                    if let Ok(mut ws_list) = self.workspaces.write() {
                        for ws in ws_list.iter_mut() {
                            ws.is_active = ws.id == id;
                        }
                    }
                }
            } else if let Some(win) = obj.get("WindowOpenedOrChanged").or_else(|| obj.get("WindowFocusChanged")) {
                let (title, app_id) = if let Some(w) = win.get("window") {
                    let t = w.get("title").and_then(|v| v.as_str()).unwrap_or("");
                    let a = w.get("app_id").and_then(|v| v.as_str()).unwrap_or("");
                    (t.to_string(), a.to_string())
                } else if let Ok((t, a)) = self.compositor.query_focused_window().await {
                    (t, a)
                } else {
                    ("".to_string(), "".to_string())
                };

                if let Ok(mut t_lock) = self.focused_window_title.write() {
                    *t_lock = title;
                }
                if let Ok(mut a_lock) = self.focused_app_id.write() {
                    *a_lock = app_id;
                }
            } else if let Some(kl) = obj.get("KeyboardLayoutsChanged") {
                if let Some(names) = kl.get("keyboard_layouts").and_then(|k| k.get("names")).and_then(|n| n.as_array()) {
                    let parsed: Vec<String> = names.iter().filter_map(|v| v.as_str().map(|s| s.to_string())).collect();
                    if let Ok(mut lock) = self.keyboard_layouts.write() {
                        *lock = parsed;
                    }
                }
            } else if let Some(switched) = obj.get("KeyboardLayoutSwitched") {
                if let Some(idx) = switched.get("idx").and_then(|v| v.as_u64()) {
                    let idx = idx as u32;
                    if let Ok(mut lock) = self.current_keyboard_layout_idx.write() {
                        *lock = idx;
                    }
                    if let Ok(layouts) = self.keyboard_layouts.read() {
                        if let Some(name) = layouts.get(idx as usize) {
                            if let Ok(mut name_lock) = self.current_keyboard_layout.write() {
                                *name_lock = name.clone();
                            }
                        }
                    }
                }
            }
        }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Workspaces")]
impl WorkspacesService {
    /// ID of active workspace.
    #[zbus(property)]
    async fn active_workspace(&self) -> u32 {
        *self.active_workspace.read().unwrap()
    }

    /// JSON serialized array of workspace items.
    #[zbus(property)]
    async fn workspaces(&self) -> String {
        let ws = self.workspaces.read().unwrap();
        serde_json::to_string(&*ws).unwrap_or_else(|_| "[]".to_string())
    }

    /// Title of currently focused window.
    #[zbus(property)]
    async fn focused_window_title(&self) -> String {
        self.focused_window_title.read().unwrap().clone()
    }

    /// Application ID / class of focused window.
    #[zbus(property)]
    async fn focused_app_id(&self) -> String {
        self.focused_app_id.read().unwrap().clone()
    }

    /// Array of available keyboard layout names.
    #[zbus(property)]
    async fn keyboard_layouts(&self) -> Vec<String> {
        self.keyboard_layouts.read().unwrap().clone()
    }

    /// Name of active keyboard layout.
    #[zbus(property)]
    async fn current_keyboard_layout(&self) -> String {
        self.current_keyboard_layout.read().unwrap().clone()
    }

    /// Index of active keyboard layout.
    #[zbus(property)]
    async fn current_keyboard_layout_idx(&self) -> u32 {
        *self.current_keyboard_layout_idx.read().unwrap()
    }

    /// Switch active workspace by numeric ID.
    async fn activate_workspace(&self, id: u32) -> zbus::fdo::Result<()> {
        self.compositor.activate_workspace(id).await.map_err(|e| {
            zbus::fdo::Error::Failed(format!("Failed to activate workspace {id}: {e}"))
        })?;

        if let Ok(mut lock) = self.active_workspace.write() {
            *lock = id;
        }
        if let Ok(mut ws_list) = self.workspaces.write() {
            for ws in ws_list.iter_mut() {
                ws.is_active = ws.id == id;
            }
        }

        Ok(())
    }

    /// Close currently focused window.
    async fn close_focused_window(&self) -> zbus::fdo::Result<()> {
        self.compositor.close_focused_window().await.map_err(|e| {
            zbus::fdo::Error::Failed(format!("Failed to close focused window: {e}"))
        })
    }

    /// Switch active keyboard layout by index.
    async fn switch_keyboard_layout(&self, idx: u32) -> zbus::fdo::Result<()> {
        self.compositor.switch_keyboard_layout(idx).await.map_err(|e| {
            zbus::fdo::Error::Failed(format!("Failed to switch keyboard layout {idx}: {e}"))
        })?;

        if let Ok(mut lock) = self.current_keyboard_layout_idx.write() {
            *lock = idx;
        }
        if let Ok(layouts) = self.keyboard_layouts.read() {
            if let Some(name) = layouts.get(idx as usize) {
                if let Ok(mut name_lock) = self.current_keyboard_layout.write() {
                    *name_lock = name.clone();
                }
            }
        }

        Ok(())
    }

    /// Signal emitted when active workspace changes.
    #[zbus(signal)]
    pub async fn workspace_changed(emitter: &SignalEmitter<'_>, id: u32) -> zbus::Result<()>;

    /// Signal emitted when focused window title or app_id changes.
    #[zbus(signal)]
    pub async fn window_changed(emitter: &SignalEmitter<'_>, title: &str, app_id: &str) -> zbus::Result<()>;

    /// Signal emitted when keyboard layout changes.
    #[zbus(signal)]
    pub async fn keyboard_layout_changed(emitter: &SignalEmitter<'_>, name: &str, idx: u32) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Instant;

    #[tokio::test]
    async fn test_mock_compositor_operations() {
        let comp = Arc::new(MockCompositor::new());
        let service = WorkspacesService::new(Arc::clone(&comp) as Arc<dyn Compositor>)
            .await
            .expect("Failed to create WorkspacesService");

        assert_eq!(service.active_workspace().await, 1);
        assert_eq!(service.current_keyboard_layout_idx().await, 0);

        // Switch workspace
        service.activate_workspace(2).await.expect("Failed to activate ws 2");
        assert_eq!(service.active_workspace().await, 2);

        // Switch keyboard layout
        service.switch_keyboard_layout(1).await.expect("Failed to switch layout");
        assert_eq!(service.current_keyboard_layout_idx().await, 1);

        // Close window
        service.close_focused_window().await.expect("Failed to close window");
    }

    #[tokio::test]
    async fn test_workspace_switching_latency_under_4ms() {
        let comp = Arc::new(MockCompositor::new());
        let service = WorkspacesService::new(Arc::clone(&comp) as Arc<dyn Compositor>)
            .await
            .expect("Failed to create WorkspacesService");

        let iterations = 100;
        let start = Instant::now();

        for i in 1..=iterations {
            let target_ws = (i % 5) + 1;
            service
                .activate_workspace(target_ws)
                .await
                .expect("Fast switch failed");
        }

        let elapsed = start.elapsed();
        let avg_micros = elapsed.as_micros() as f64 / iterations as f64;
        let avg_millis = avg_micros / 1000.0;

        assert!(
            avg_millis < 4.0,
            "Latency assertion failed: average workspace switch took {avg_millis:.3}ms (SLA is < 4ms)"
        );
    }
}

