//! Application scanner tool (Replaces quickshell/agility/Modules/Launcher/scripts/get_apps.py)

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppAction {
    pub name: String,
    pub exec: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppInfo {
    pub name: String,
    pub exec: String,
    pub icon: String,
    pub terminal: bool,
    pub actions: Vec<AppAction>,
}

pub fn get_apps() -> Vec<AppInfo> {
    let mut apps: Vec<AppInfo> = Vec::new();
    let mut seen_execs: HashSet<String> = HashSet::new();

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
                if let Some(app) = parse_desktop_file(&content) {
                    let mut exec_key = app.exec.clone();
                    if exec_key.starts_with("/usr/bin/") {
                        exec_key = exec_key[9..].to_string();
                    }
                    if !seen_execs.contains(&exec_key) {
                        seen_execs.insert(exec_key);
                        apps.push(app);
                    }
                }
            }
        }
    }

    apps.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    apps
}

fn parse_desktop_file(content: &str) -> Option<AppInfo> {
    let mut current_section = "";
    let mut name = String::new();
    let mut raw_exec = String::new();
    let mut icon = String::new();
    let mut terminal = false;
    let mut no_display = false;
    let mut hidden = false;
    let mut action_keys: Vec<String> = Vec::new();
    let mut action_map: std::collections::HashMap<String, (String, String)> = std::collections::HashMap::new();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.is_empty() || trimmed.starts_with('#') {
            continue;
        }

        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            current_section = &trimmed[1..trimmed.len() - 1];
            continue;
        }

        if let Some((key, val)) = trimmed.split_once('=') {
            let key = key.trim();
            let val = val.trim();

            if current_section == "Desktop Entry" {
                match key {
                    "Name" if name.is_empty() => name = val.to_string(),
                    "Exec" if raw_exec.is_empty() => raw_exec = val.to_string(),
                    "Icon" if icon.is_empty() => icon = val.trim_matches('"').to_string(),
                    "Terminal" => terminal = val.eq_ignore_ascii_case("true"),
                    "NoDisplay" => no_display = val.eq_ignore_ascii_case("true"),
                    "Hidden" => hidden = val.eq_ignore_ascii_case("true"),
                    "Actions" => {
                        action_keys = val
                            .split(';')
                            .map(|s| s.trim().to_string())
                            .filter(|s| !s.is_empty())
                            .collect();
                    }
                    _ => {}
                }
            } else if current_section.starts_with("Desktop Action ") {
                let action_name = &current_section["Desktop Action ".len()..];
                let entry = action_map
                    .entry(action_name.to_string())
                    .or_insert_with(|| (String::new(), String::new()));
                if key == "Name" {
                    entry.0 = val.to_string();
                } else if key == "Exec" {
                    entry.1 = clean_exec(val);
                }
            }
        }
    }

    if no_display || hidden || name.is_empty() || raw_exec.is_empty() {
        return None;
    }

    let cleaned_exec = clean_exec(&raw_exec);
    let mut actions = Vec::new();
    for ak in action_keys {
        if let Some((a_name, a_exec)) = action_map.get(&ak) {
            if !a_name.is_empty() && !a_exec.is_empty() {
                actions.push(AppAction {
                    name: a_name.clone(),
                    exec: a_exec.clone(),
                });
            }
        }
    }

    Some(AppInfo {
        name,
        exec: cleaned_exec,
        icon,
        terminal,
        actions,
    })
}

fn clean_exec(raw: &str) -> String {
    let base = raw.split(" %").next().unwrap_or(raw);
    base.replace('"', "").trim().to_string()
}

pub fn run() -> i32 {
    let apps = get_apps();
    match serde_json::to_string(&apps) {
        Ok(json) => {
            println!("{json}");
            0
        }
        Err(e) => {
            eprintln!("Error serializing apps: {e}");
            1
        }
    }
}
