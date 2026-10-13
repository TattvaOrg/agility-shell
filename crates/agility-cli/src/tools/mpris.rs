//! Music Player Discovery Tool (Replaces quickshell/agility/Modules/Music/scripts/get_music_players.py)

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MusicPlayerEntry {
    pub id: String,
    pub name: String,
    pub exec: String,
    pub icon: String,
    pub running: bool,
}

pub fn get_music_players() -> Vec<MusicPlayerEntry> {
    let mut results: Vec<MusicPlayerEntry> = Vec::new();
    let mut seen_ids: HashSet<String> = HashSet::new();

    // Check active players from playerctl
    let running_players: HashSet<String> = Command::new("playerctl")
        .args(["-l"])
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| {
            s.lines()
                .map(|l| l.split('.').next().unwrap_or(l).to_lowercase())
                .collect()
        })
        .unwrap_or_default();

    let known_players = [
        "spotify",
        "vlc",
        "mpv",
        "amberol",
        "audacious",
        "rhythmbox",
        "clementine",
        "strawberry",
        "feishin",
        "tauon",
        "deadbeef",
        "elisa",
        "cmus",
        "ncspot",
    ];

    let xdg_data_dirs = std::env::var("XDG_DATA_DIRS")
        .unwrap_or_else(|_| "/usr/local/share:/usr/share".to_string());
    let mut search_dirs: Vec<PathBuf> = xdg_data_dirs
        .split(':')
        .map(|p| Path::new(p).join("applications"))
        .collect();

    if let Ok(home) = std::env::var("HOME") {
        let home_path = Path::new(&home);
        search_dirs.push(home_path.join(".local/share/applications"));
        search_dirs.push(home_path.join(".local/share/flatpak/exports/share/applications"));
    }
    search_dirs.push(PathBuf::from("/var/lib/flatpak/exports/share/applications"));

    for dir in search_dirs {
        if !dir.is_dir() {
            continue;
        }

        let entries = match fs::read_dir(&dir) {
            Ok(e) => e,
            Err(_) => continue,
        };

        for entry in entries.flatten() {
            let path = entry.path();
            if path.extension().and_then(|ext| ext.to_str()) != Some("desktop") {
                continue;
            }

            if let Ok(content) = fs::read_to_string(&path) {
                if let Some(player) =
                    parse_music_desktop(&content, &known_players, &running_players)
                {
                    if !seen_ids.contains(&player.id) {
                        seen_ids.insert(player.id.clone());
                        results.push(player);
                    }
                }
            }
        }
    }

    results.sort_by(|a, b| {
        b.running
            .cmp(&a.running)
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });
    results
}

fn parse_music_desktop(
    content: &str,
    known: &[&str],
    running: &HashSet<String>,
) -> Option<MusicPlayerEntry> {
    let mut name = String::new();
    let mut exec = String::new();
    let mut icon = String::new();
    let mut categories = String::new();
    let mut no_display = false;

    let mut in_entry = false;
    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed == "[Desktop Entry]" {
            in_entry = true;
            continue;
        } else if trimmed.starts_with('[') {
            in_entry = false;
            continue;
        }

        if in_entry {
            if let Some((k, v)) = trimmed.split_once('=') {
                match k.trim() {
                    "Name" if name.is_empty() => name = v.trim().to_string(),
                    "Exec" if exec.is_empty() => {
                        exec = v.trim().split(" %").next().unwrap_or("").to_string()
                    }
                    "Icon" if icon.is_empty() => icon = v.trim().to_string(),
                    "Categories" => categories = v.trim().to_lowercase(),
                    "NoDisplay" => no_display = v.trim().eq_ignore_ascii_case("true"),
                    _ => {}
                }
            }
        }
    }

    if no_display || name.is_empty() || exec.is_empty() {
        return None;
    }

    let exec_lower = exec.to_lowercase();
    let is_known = known
        .iter()
        .any(|k| exec_lower.contains(k) || name.to_lowercase().contains(k));
    let is_audio = categories.contains("audio")
        || categories.contains("music")
        || categories.contains("audiovideo");

    if is_known || is_audio {
        let id = Path::new(&exec)
            .file_name()
            .and_then(|f| f.to_str())
            .unwrap_or(&name)
            .to_lowercase();
        let is_running = running.contains(&id);

        Some(MusicPlayerEntry {
            id,
            name,
            exec,
            icon,
            running: is_running,
        })
    } else {
        None
    }
}

pub fn run() -> i32 {
    let players = get_music_players();
    match serde_json::to_string(&players) {
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
