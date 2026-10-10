//! Audio and media controller module (PipeWire/PulseAudio & MPRIS2).
//! Implements `org.agility.Daemon.Audio` and `org.agility.Daemon.Media` D-Bus interfaces.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::process::Command;
use std::sync::{Arc, RwLock};
use std::time::Duration;
use tokio::sync::broadcast;
use tracing::{debug, info};
use zbus::object_server::SignalEmitter;
use zbus::Connection;

/// Audio device descriptor (sink or source).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioDevice {
    pub name: String,
    pub description: String,
    pub volume: f64,
    pub muted: bool,
    pub is_default: bool,
}

/// In-memory audio telemetry snapshot.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AudioSnapshot {
    pub volume: f64,
    pub muted: bool,
    pub mic_volume: f64,
    pub mic_muted: bool,
    pub sinks: Vec<AudioDevice>,
    pub sources: Vec<AudioDevice>,
    pub visualizer_bars: Vec<f64>,
}

impl Default for AudioSnapshot {
    fn default() -> Self {
        Self {
            volume: 0.8,
            muted: false,
            mic_volume: 0.5,
            mic_muted: false,
            sinks: vec![AudioDevice {
                name: "default-sink".into(),
                description: "Built-in Audio Analog Stereo".into(),
                volume: 0.8,
                muted: false,
                is_default: true,
            }],
            sources: vec![AudioDevice {
                name: "default-source".into(),
                description: "Built-in Audio Analog Stereo".into(),
                volume: 0.5,
                muted: false,
                is_default: true,
            }],
            visualizer_bars: vec![0.0; 16],
        }
    }
}

/// D-Bus Service implementing `org.agility.Daemon.Audio`.
#[derive(Clone)]
pub struct AudioService {
    snapshot: Arc<RwLock<AudioSnapshot>>,
}

impl AudioService {
    pub fn new() -> Arc<Self> {
        let mut snapshot = AudioSnapshot::default();
        Self::poll_audio_hardware(&mut snapshot);

        Arc::new(Self {
            snapshot: Arc::new(RwLock::new(snapshot)),
        })
    }

    /// Sample audio sink and source levels from PipeWire (wpctl / pactl).
    fn poll_audio_hardware(snapshot: &mut AudioSnapshot) {
        // Query sink volume via wpctl
        if let Ok(output) = Command::new("wpctl")
            .args(["get-volume", "@DEFAULT_AUDIO_SINK@"])
            .output()
        {
            if output.status.success() {
                let out_str = String::from_utf8_lossy(&output.stdout);
                let (vol, muted) = Self::parse_wpctl_volume(&out_str);
                snapshot.volume = vol;
                snapshot.muted = muted;
            }
        }

        // Query source volume via wpctl
        if let Ok(output) = Command::new("wpctl")
            .args(["get-volume", "@DEFAULT_AUDIO_SOURCE@"])
            .output()
        {
            if output.status.success() {
                let out_str = String::from_utf8_lossy(&output.stdout);
                let (vol, muted) = Self::parse_wpctl_volume(&out_str);
                snapshot.mic_volume = vol;
                snapshot.mic_muted = muted;
            }
        }

        // Query available sinks and sources via pactl if available
        if let Ok(output) = Command::new("pactl")
            .args(["list", "sinks", "short"])
            .output()
        {
            if output.status.success() {
                let out_str = String::from_utf8_lossy(&output.stdout);
                let mut sinks = Vec::new();
                for line in out_str.lines() {
                    let parts: Vec<&str> = line.split_whitespace().collect();
                    if parts.len() >= 2 {
                        let name = parts[1].to_string();
                        let is_def = !name.contains(".monitor");
                        sinks.push(AudioDevice {
                            name: name.clone(),
                            description: name,
                            volume: snapshot.volume,
                            muted: snapshot.muted,
                            is_default: is_def,
                        });
                    }
                }
                if !sinks.is_empty() {
                    snapshot.sinks = sinks;
                }
            }
        }

        // Generate dynamic amplitude visualizer bars (simulated responsive FFT stream for QML)
        let active_multiplier = if snapshot.muted { 0.0 } else { snapshot.volume };
        let mut bars = Vec::with_capacity(16);
        let time_factor = (std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_millis() as f64)
            / 300.0;

        for i in 0..16 {
            let val = ((time_factor + (i as f64 * 0.4)).sin().abs() * 0.8 + 0.1) * active_multiplier;
            bars.push((val.clamp(0.0, 1.0) * 100.0).round() / 100.0);
        }
        snapshot.visualizer_bars = bars;
    }

    /// Parse wpctl output string: "Volume: 0.80" or "Volume: 0.80 [MUTED]"
    fn parse_wpctl_volume(output: &str) -> (f64, bool) {
        let muted = output.contains("[MUTED]");
        let vol = output
            .split_whitespace()
            .nth(1)
            .and_then(|v| v.parse::<f64>().ok())
            .unwrap_or(0.0);
        (vol, muted)
    }

    /// Spawns background poller updating audio levels every 500ms.
    pub fn start_polling(
        self: &Arc<Self>,
        interval: Duration,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let snapshot_ref = Arc::clone(&self.snapshot);

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(interval);
            debug!("Audio hardware background poller started");

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Shutting down audio hardware poller");
                        break;
                    }
                    _ = ticker.tick() => {
                        if let Ok(mut lock) = snapshot_ref.write() {
                            Self::poll_audio_hardware(&mut lock);
                        }
                    }
                }
            }
        });
    }
}

#[zbus::interface(name = "org.agility.Daemon.Audio")]
impl AudioService {
    /// Default audio sink volume (0.0 - 1.5).
    #[zbus(property(emits_changed_signal = "false"))]
    async fn volume(&self) -> f64 {
        self.snapshot.read().unwrap().volume
    }

    /// Default audio sink mute state.
    #[zbus(property)]
    async fn muted(&self) -> bool {
        self.snapshot.read().unwrap().muted
    }

    /// Default microphone volume (0.0 - 1.0).
    #[zbus(property(emits_changed_signal = "false"))]
    async fn mic_volume(&self) -> f64 {
        self.snapshot.read().unwrap().mic_volume
    }

    /// Default microphone mute state.
    #[zbus(property)]
    async fn mic_muted(&self) -> bool {
        self.snapshot.read().unwrap().mic_muted
    }

    /// Available output audio devices serialized as JSON array.
    #[zbus(property)]
    async fn sinks(&self) -> String {
        serde_json::to_string(&self.snapshot.read().unwrap().sinks).unwrap_or_else(|_| "[]".to_string())
    }

    /// Available input audio devices serialized as JSON array.
    #[zbus(property)]
    async fn sources(&self) -> String {
        serde_json::to_string(&self.snapshot.read().unwrap().sources).unwrap_or_else(|_| "[]".to_string())
    }

    /// Real-time audio visualizer amplitude bars.
    #[zbus(property)]
    async fn visualizer_bars(&self) -> Vec<f64> {
        self.snapshot.read().unwrap().visualizer_bars.clone()
    }

    /// Set default sink volume directly.
    async fn set_volume(&self, vol: f64) -> zbus::fdo::Result<()> {
        let clamped = vol.clamp(0.0, 1.5);
        info!("Setting audio sink volume to {clamped:.2}");
        let _ = Command::new("wpctl")
            .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{clamped:.2}")])
            .status();

        if let Ok(mut lock) = self.snapshot.write() {
            lock.volume = clamped;
        }
        Ok(())
    }

    /// Adjust default sink volume by relative delta.
    async fn adjust_volume(&self, delta: f64) -> zbus::fdo::Result<()> {
        let current = self.snapshot.read().unwrap().volume;
        let new_vol = (current + delta).clamp(0.0, 1.5);
        self.set_volume(new_vol).await
    }

    /// Toggle default audio sink mute state.
    async fn toggle_mute(&self) -> zbus::fdo::Result<()> {
        info!("Toggling audio sink mute");
        let _ = Command::new("wpctl")
            .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
            .status();

        if let Ok(mut lock) = self.snapshot.write() {
            lock.muted = !lock.muted;
        }
        Ok(())
    }

    /// Set default microphone volume directly.
    async fn set_mic_volume(&self, vol: f64) -> zbus::fdo::Result<()> {
        let clamped = vol.clamp(0.0, 1.0);
        info!("Setting microphone volume to {clamped:.2}");
        let _ = Command::new("wpctl")
            .args(["set-volume", "@DEFAULT_AUDIO_SOURCE@", &format!("{clamped:.2}")])
            .status();

        if let Ok(mut lock) = self.snapshot.write() {
            lock.mic_volume = clamped;
        }
        Ok(())
    }

    /// Toggle default microphone mute state.
    async fn toggle_mic_mute(&self) -> zbus::fdo::Result<()> {
        info!("Toggling microphone mute");
        let _ = Command::new("wpctl")
            .args(["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
            .status();

        if let Ok(mut lock) = self.snapshot.write() {
            lock.mic_muted = !lock.mic_muted;
        }
        Ok(())
    }

    /// Set default audio output sink.
    async fn set_default_sink(&self, name: String) -> zbus::fdo::Result<()> {
        info!("Setting default sink to '{name}'");
        let _ = Command::new("pactl")
            .args(["set-default-sink", &name])
            .status();
        Ok(())
    }

    /// Set default audio input source.
    async fn set_default_source(&self, name: String) -> zbus::fdo::Result<()> {
        info!("Setting default source to '{name}'");
        let _ = Command::new("pactl")
            .args(["set-default-source", &name])
            .status();
        Ok(())
    }

    /// Signal emitted when default sink volume or mute state changes.
    #[zbus(signal)]
    pub async fn volume_changed(emitter: &SignalEmitter<'_>, vol: f64, muted: bool) -> zbus::Result<()>;

    /// Signal emitted when microphone volume or mute state changes.
    #[zbus(signal)]
    pub async fn mic_changed(emitter: &SignalEmitter<'_>, vol: f64, muted: bool) -> zbus::Result<()>;
}

/// MPRIS2 media player metadata snapshot.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct MediaSnapshot {
    pub active_player: String,
    pub playback_status: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub position: i64,
    pub length: i64,
}

/// D-Bus Service implementing `org.agility.Daemon.Media`.
#[derive(Clone)]
pub struct MediaService {
    snapshot: Arc<RwLock<MediaSnapshot>>,
}

impl MediaService {
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            snapshot: Arc::new(RwLock::new(MediaSnapshot {
                active_player: "".into(),
                playback_status: "Stopped".into(),
                title: "No Media Playing".into(),
                artist: "".into(),
                album: "".into(),
                art_url: "".into(),
                position: 0,
                length: 0,
            })),
        })
    }

    /// Poll session D-Bus for active MPRIS2 players.
    pub async fn poll_mpris(snapshot_ref: &Arc<RwLock<MediaSnapshot>>) {
        let Ok(conn) = Connection::session().await else {
            return;
        };

        // Query session bus for active org.mpris.MediaPlayer2.* services
        let dbus_proxy = zbus::fdo::DBusProxy::new(&conn).await;
        let Ok(proxy) = dbus_proxy else { return };
        let Ok(names) = proxy.list_names().await else { return };

        let mpris_name = names
            .into_iter()
            .find(|n| n.as_str().starts_with("org.mpris.MediaPlayer2.") && !n.as_str().contains("playerctld"));

        if let Some(player_name) = mpris_name {
            let short_name = player_name
                .as_str()
                .strip_prefix("org.mpris.MediaPlayer2.")
                .unwrap_or(player_name.as_str())
                .split('.')
                .next()
                .unwrap_or("")
                .to_string();

            // Query PlaybackStatus
            let status_msg = conn
                .call_method(
                    Some(player_name.as_str()),
                    "/org/mpris/MediaPlayer2",
                    Some("org.freedesktop.DBus.Properties"),
                    "Get",
                    &("org.mpris.MediaPlayer2.Player", "PlaybackStatus"),
                )
                .await;

            let status: String = status_msg
                .ok()
                .and_then(|m| m.body().deserialize::<zbus::zvariant::OwnedValue>().ok())
                .and_then(|v| String::try_from(v).ok())
                .unwrap_or_else(|| "Stopped".into());

            // Query Metadata
            let meta_msg = conn
                .call_method(
                    Some(player_name.as_str()),
                    "/org/mpris/MediaPlayer2",
                    Some("org.freedesktop.DBus.Properties"),
                    "Get",
                    &("org.mpris.MediaPlayer2.Player", "Metadata"),
                )
                .await;

            let mut title = String::new();
            let mut artist = String::new();
            let mut album = String::new();
            let mut art_url = String::new();
            let mut length: i64 = 0;

            if let Ok(m) = meta_msg {
                if let Ok(val) = m.body().deserialize::<zbus::zvariant::OwnedValue>() {
                    if let Ok(dict) = HashMap::<String, zbus::zvariant::OwnedValue>::try_from(val) {
                        if let Some(t) = dict.get("xesam:title") {
                            if let Ok(s) = <&str>::try_from(t) {
                                title = s.to_string();
                            }
                        }
                        if let Some(a) = dict.get("xesam:artist") {
                            if let Ok(list) = <Vec<String>>::try_from(a.clone()) {
                                artist = list.join(", ");
                            } else if let Ok(s) = <&str>::try_from(a) {
                                artist = s.to_string();
                            }
                        }
                        if let Some(al) = dict.get("xesam:album") {
                            if let Ok(s) = <&str>::try_from(al) {
                                album = s.to_string();
                            }
                        }
                        if let Some(u) = dict.get("mpris:artUrl") {
                            if let Ok(s) = <&str>::try_from(u) {
                                art_url = s.to_string();
                            }
                        }
                        if let Some(l) = dict.get("mpris:length") {
                            if let Ok(len) = i64::try_from(l) {
                                length = len;
                            }
                        }
                    }
                }
            }

            if let Ok(mut lock) = snapshot_ref.write() {
                lock.active_player = short_name;
                lock.playback_status = status;
                if !title.is_empty() {
                    lock.title = title;
                }
                lock.artist = artist;
                lock.album = album;
                lock.art_url = art_url;
                lock.length = length;
            }
        } else if let Ok(mut lock) = snapshot_ref.write() {
            lock.active_player.clear();
            lock.playback_status = "Stopped".into();
            lock.title = "No Media Playing".into();
            lock.artist.clear();
            lock.art_url.clear();
        }
    }

    /// Spawns background MPRIS poller checking players every 1 second.
    pub fn start_polling(
        self: &Arc<Self>,
        interval: Duration,
        mut shutdown_rx: broadcast::Receiver<()>,
    ) {
        let snapshot_ref = Arc::clone(&self.snapshot);

        tokio::spawn(async move {
            let mut ticker = tokio::time::interval(interval);
            debug!("MPRIS media poller started");

            loop {
                tokio::select! {
                    _ = shutdown_rx.recv() => {
                        debug!("Shutting down MPRIS poller");
                        break;
                    }
                    _ = ticker.tick() => {
                        Self::poll_mpris(&snapshot_ref).await;
                    }
                }
            }
        });
    }

    /// Call an MPRIS Player method on the active player.
    async fn call_player_method(&self, method: &str) -> zbus::fdo::Result<()> {
        let player = self.snapshot.read().unwrap().active_player.clone();
        if player.is_empty() {
            return Ok(());
        }

        let conn = Connection::session()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("D-Bus session failure: {e}")))?;

        // Find matching player name
        let dbus_proxy = zbus::fdo::DBusProxy::new(&conn)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("DBus proxy error: {e}")))?;
        let names = dbus_proxy.list_names().await.unwrap_or_default();

        if let Some(full_name) = names.iter().find(|n| n.contains(&player)) {
            let _ = conn
                .call_method(
                    Some(full_name.as_str()),
                    "/org/mpris/MediaPlayer2",
                    Some("org.mpris.MediaPlayer2.Player"),
                    method,
                    &(),
                )
                .await;
        }

        Ok(())
    }
}

#[zbus::interface(name = "org.agility.Daemon.Media")]
impl MediaService {
    /// Currently active MPRIS player name (e.g. "spotify", "firefox", "brave").
    #[zbus(property)]
    async fn active_player(&self) -> String {
        self.snapshot.read().unwrap().active_player.clone()
    }

    /// Playback status ("Playing", "Paused", "Stopped").
    #[zbus(property)]
    async fn playback_status(&self) -> String {
        self.snapshot.read().unwrap().playback_status.clone()
    }

    /// Current track title.
    #[zbus(property)]
    async fn title(&self) -> String {
        self.snapshot.read().unwrap().title.clone()
    }

    /// Current track artist.
    #[zbus(property)]
    async fn artist(&self) -> String {
        self.snapshot.read().unwrap().artist.clone()
    }

    /// Current track album name.
    #[zbus(property)]
    async fn album(&self) -> String {
        self.snapshot.read().unwrap().album.clone()
    }

    /// Cover art URI or filesystem path.
    #[zbus(property)]
    async fn art_url(&self) -> String {
        self.snapshot.read().unwrap().art_url.clone()
    }

    /// Current track position in microseconds.
    #[zbus(property)]
    async fn position(&self) -> i64 {
        self.snapshot.read().unwrap().position
    }

    /// Total track duration in microseconds.
    #[zbus(property)]
    async fn length(&self) -> i64 {
        self.snapshot.read().unwrap().length
    }

    /// Toggle playback between play and pause.
    async fn play_pause(&self) -> zbus::fdo::Result<()> {
        info!("Media action: PlayPause");
        self.call_player_method("PlayPause").await
    }

    /// Skip to next track.
    async fn next(&self) -> zbus::fdo::Result<()> {
        info!("Media action: Next");
        self.call_player_method("Next").await
    }

    /// Skip to previous track.
    async fn previous(&self) -> zbus::fdo::Result<()> {
        info!("Media action: Previous");
        self.call_player_method("Previous").await
    }

    /// Seek forward or backward by microsecond offset.
    async fn seek(&self, offset_usec: i64) -> zbus::fdo::Result<()> {
        info!("Media action: Seek ({offset_usec} usec)");
        let player = self.snapshot.read().unwrap().active_player.clone();
        if player.is_empty() {
            return Ok(());
        }

        let conn = Connection::session()
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("D-Bus session failure: {e}")))?;

        let dbus_proxy = zbus::fdo::DBusProxy::new(&conn)
            .await
            .map_err(|e| zbus::fdo::Error::Failed(format!("DBus proxy error: {e}")))?;
        let names = dbus_proxy.list_names().await.unwrap_or_default();

        if let Some(full_name) = names.iter().find(|n| n.contains(&player)) {
            let _ = conn
                .call_method(
                    Some(full_name.as_str()),
                    "/org/mpris/MediaPlayer2",
                    Some("org.mpris.MediaPlayer2.Player"),
                    "Seek",
                    &(offset_usec),
                )
                .await;
        }

        Ok(())
    }

    /// Signal emitted when track metadata changes.
    #[zbus(signal)]
    pub async fn track_changed(
        emitter: &SignalEmitter<'_>,
        title: &str,
        artist: &str,
        art_url: &str,
    ) -> zbus::Result<()>;

    /// Signal emitted when playback status changes.
    #[zbus(signal)]
    pub async fn status_changed(emitter: &SignalEmitter<'_>, status: &str) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_wpctl_volume() {
        let out1 = "Volume: 0.85\n";
        let (vol1, mut1) = AudioService::parse_wpctl_volume(out1);
        assert_eq!(vol1, 0.85);
        assert!(!mut1);

        let out2 = "Volume: 0.40 [MUTED]\n";
        let (vol2, mut2) = AudioService::parse_wpctl_volume(out2);
        assert_eq!(vol2, 0.40);
        assert!(mut2);
    }

    #[test]
    fn test_audio_snapshot_initialization() {
        let service = AudioService::new();
        let snap = service.snapshot.read().unwrap().clone();
        assert!(snap.volume >= 0.0 && snap.volume <= 1.5);
        assert!(!snap.sinks.is_empty());
        assert_eq!(snap.visualizer_bars.len(), 16);
    }

    #[tokio::test]
    async fn test_media_service_initialization() {
        let media = MediaService::new();
        assert_eq!(media.playback_status().await, "Stopped");
        assert_eq!(media.title().await, "No Media Playing");
    }
}
