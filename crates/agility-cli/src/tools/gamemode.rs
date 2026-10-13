//! GameMode and Power Profile Controller (Replaces quickshell/agility/Core/Services/scripts/game_mode.py)

use serde::{Deserialize, Serialize};
use std::fs;
use std::path::Path;
use std::process::Command;

const PREV_PROFILE_FILE: &str = "/tmp/minflair_prev_power_profile";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameModeStatus {
    pub gamemode_active: bool,
    pub power_profile: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GameModeResult {
    pub status: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub restored_profile: Option<String>,
}

pub fn get_status() -> GameModeStatus {
    let daemon_active = Command::new("gamemoded")
        .arg("-s")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.contains("is active"))
        .unwrap_or(false);

    let power_profile = Command::new("powerprofilesctl")
        .arg("get")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "balanced".to_string());

    GameModeStatus {
        gamemode_active: daemon_active,
        power_profile,
    }
}

pub fn apply() -> GameModeResult {
    let current_profile = Command::new("powerprofilesctl")
        .arg("get")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.trim().to_string())
        .unwrap_or_else(|| "balanced".to_string());

    if !Path::new(PREV_PROFILE_FILE).exists() {
        let _ = fs::write(PREV_PROFILE_FILE, &current_profile);
    }

    let _ = Command::new("powerprofilesctl")
        .args(["set", "performance"])
        .status();

    GameModeResult {
        status: "applied".to_string(),
        restored_profile: None,
    }
}

pub fn revert() -> GameModeResult {
    let mut prev_profile = "balanced".to_string();
    if Path::new(PREV_PROFILE_FILE).exists() {
        if let Ok(content) = fs::read_to_string(PREV_PROFILE_FILE) {
            prev_profile = content.trim().to_string();
        }
        let _ = fs::remove_file(PREV_PROFILE_FILE);
    }

    let _ = Command::new("powerprofilesctl")
        .args(["set", &prev_profile])
        .status();

    GameModeResult {
        status: "reverted".to_string(),
        restored_profile: Some(prev_profile),
    }
}

pub fn run(args: &[String]) -> i32 {
    let action = args.first().map(|s| s.as_str()).unwrap_or("status");
    let output = match action {
        "status" => serde_json::to_string(&get_status()),
        "apply" => serde_json::to_string(&apply()),
        "revert" => serde_json::to_string(&revert()),
        other => {
            eprintln!("Unknown action: {other}");
            return 1;
        }
    };

    match output {
        Ok(json) => {
            println!("{json}");
            0
        }
        Err(e) => {
            eprintln!("Serialization error: {e}");
            1
        }
    }
}
