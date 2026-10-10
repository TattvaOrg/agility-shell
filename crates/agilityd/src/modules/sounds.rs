//! Sound Effects Player.
//! Dispatches system sound events (`session-start`, `session-quit`, `notification`,
//! `battery-low`, `battery-warning`, `battery-charge`, `error`, `confirm`, `alarm`,
//! `widget-placed`, `widget-removed`) via `pw-play` or `paplay`.
//! Exposes `org.agility.Daemon.Sounds` D-Bus interface.

use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::Arc;
use tracing::{info, warn};
use zbus::object_server::SignalEmitter;

/// Recognized shell sound event names.
pub const VALID_SOUNDS: &[&str] = &[
    "session-start",
    "session-quit",
    "notification",
    "battery-low",
    "battery-warning",
    "battery-charge",
    "error",
    "confirm",
    "alarm",
    "widget-placed",
    "widget-removed",
];

/// Sound effects dispatcher service.
pub struct SoundService {
    sounds_dir: PathBuf,
    player_bin: Option<String>,
}

impl SoundService {
    /// Initialize SoundService, detecting available audio player (`pw-play` or `paplay`).
    pub fn new(sounds_dir: Option<PathBuf>) -> Arc<Self> {
        let player = if Self::has_binary("pw-play") {
            Some("pw-play".to_string())
        } else if Self::has_binary("paplay") {
            Some("paplay".to_string())
        } else {
            None
        };

        let dir = sounds_dir.unwrap_or_else(|| {
            // First check if current directory or executable parent has sounds/
            let local = PathBuf::from("sounds");
            if local.is_dir() {
                local
            } else {
                PathBuf::from("/usr/share/agility-shell/sounds")
            }
        });

        Arc::new(Self {
            sounds_dir: dir,
            player_bin: player,
        })
    }

    /// Retrieve configured sounds directory.
    pub fn sounds_dir(&self) -> &Path {
        &self.sounds_dir
    }

    /// Retrieve detected playback binary name.
    pub fn player_bin(&self) -> Option<&str> {
        self.player_bin.as_deref()
    }

    /// Check if a sound name is recognized by the sound theme.
    pub fn is_valid_sound(name: &str) -> bool {
        VALID_SOUNDS.contains(&name)
    }

    /// Resolve absolute or relative path to requested sound file.
    pub fn get_sound_path(&self, sound_name: &str) -> Option<PathBuf> {
        if !Self::is_valid_sound(sound_name) {
            return None;
        }

        let wav = format!("{sound_name}.wav");
        let candidate = self.sounds_dir.join(&wav);
        if candidate.is_file() {
            return Some(candidate);
        }

        // Fallback relative search
        let fallback = PathBuf::from("sounds").join(&wav);
        if fallback.is_file() {
            return Some(fallback);
        }

        None
    }

    /// Asynchronously play a sound effect by name.
    pub fn play(&self, sound_name: &str) -> bool {
        if !Self::is_valid_sound(sound_name) {
            warn!("Unknown sound event requested: {sound_name}");
            return false;
        }

        let sound_path = match self.get_sound_path(sound_name) {
            Some(p) => p,
            None => {
                warn!(
                    "Sound file for '{sound_name}' not found in {:?}",
                    self.sounds_dir
                );
                return false;
            }
        };

        let player = match self.player_bin.as_ref() {
            Some(p) => p,
            None => {
                warn!("Neither pw-play nor paplay found in PATH to play audio");
                return false;
            }
        };

        match Command::new(player).arg(&sound_path).spawn() {
            Ok(_) => {
                info!("Playing sound '{sound_name}' via {player}");
                true
            }
            Err(e) => {
                warn!("Failed to spawn {player} for {sound_name}: {e:#}");
                false
            }
        }
    }

    fn has_binary(bin: &str) -> bool {
        Command::new("which")
            .arg(bin)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }
}

/// D-Bus interface wrapper implementing `org.agility.Daemon.Sounds`.
pub struct SoundsInterface {
    service: Arc<SoundService>,
}

impl SoundsInterface {
    pub fn new(service: Arc<SoundService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Sounds")]
impl SoundsInterface {
    /// Play a recognized system sound effect by name.
    async fn play(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        sound_name: &str,
    ) -> bool {
        let success = self.service.play(sound_name);
        if success {
            let _ = Self::sound_played(&emitter, sound_name).await;
        }
        success
    }

    /// Emitted when a sound effect is dispatched.
    #[zbus(signal)]
    pub async fn sound_played(emitter: &SignalEmitter<'_>, sound_name: &str) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sound_name_validation() {
        assert!(SoundService::is_valid_sound("notification"));
        assert!(SoundService::is_valid_sound("session-start"));
        assert!(SoundService::is_valid_sound("battery-low"));
        assert!(SoundService::is_valid_sound("confirm"));
        assert!(!SoundService::is_valid_sound("invalid-sound-effect"));
    }

    #[test]
    fn test_sound_service_path_resolution() {
        let temp_dir = std::env::temp_dir().join("agility_test_sounds");
        let _ = std::fs::create_dir_all(&temp_dir);
        let test_wav = temp_dir.join("confirm.wav");
        let _ = std::fs::write(&test_wav, b"RIFF....WAVE");

        let service = SoundService::new(Some(temp_dir.clone()));
        let resolved = service.get_sound_path("confirm");
        assert!(resolved.is_some());
        assert_eq!(resolved.unwrap(), test_wav);

        // Non-existent sound
        assert!(service.get_sound_path("unknown").is_none());

        let _ = std::fs::remove_dir_all(&temp_dir);
    }
}
