use anyhow::Result;
use serde::Serialize;
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Serialize, Clone)]
pub struct BindItem {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub is_subheader: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub keys: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub desc: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct KeybindSection {
    pub section: String,
    pub binds: Vec<BindItem>,
}

fn map_mod(m: &str) -> String {
    match m {
        "$mainMod" | "mainMod" | "SUPER" => "Super".to_string(),
        "SHIFT" => "Shift".to_string(),
        "CTRL" => "Ctrl".to_string(),
        "ALT" => "Alt".to_string(),
        other => other.to_string(),
    }
}

fn map_key(k: &str) -> String {
    let trimmed = k.trim();
    match trimmed {
        "Return" => "Enter".to_string(),
        "SPACE" => "Space".to_string(),
        "Tab" => "Tab".to_string(),
        "left" => "←".to_string(),
        "right" => "→".to_string(),
        "up" => "↑".to_string(),
        "down" => "↓".to_string(),
        "mouse_down" => "Scroll ↓".to_string(),
        "mouse_up" => "Scroll ↑".to_string(),
        "mouse:272" => "LClick".to_string(),
        "mouse:273" => "RClick".to_string(),
        "XF86AudioRaiseVolume" => "Vol ↑".to_string(),
        "XF86AudioLowerVolume" => "Vol ↓".to_string(),
        "XF86AudioMute" => "Mute".to_string(),
        "XF86AudioMicMute" => "Mic Mute".to_string(),
        "XF86MonBrightnessUp" => "Bri ↑".to_string(),
        "XF86MonBrightnessDown" => "Bri ↓".to_string(),
        "XF86AudioPlay" => "Play/Pause".to_string(),
        "XF86AudioNext" => "Next".to_string(),
        "XF86AudioPrev" => "Prev".to_string(),
        "XF86AudioStop" => "Stop".to_string(),
        single if single.len() == 1 => single.to_uppercase(),
        other => other.to_string(),
    }
}

fn map_section(name: &str) -> &str {
    match name {
        "Applications" => "Applications",
        "Tools" | "Volume" | "Brightness" | "Media Player" => "System",
        "Quickshell Widgets" | "Quickshell Apps" => "Quickshell",
        "Window Management" | "Window Groups" | "Navigation" | "Mouse Binds" => "Windows",
        "Workspaces" => "Workspaces",
        other => other,
    }
}

pub fn parse_keybinds(filepath: Option<PathBuf>) -> Result<()> {
    let path = filepath.unwrap_or_else(|| {
        if let Ok(home) = std::env::var("HOME") {
            PathBuf::from(home).join(".config/hypr/keybinds.lua")
        } else {
            PathBuf::from("/etc/hypr/keybinds.lua")
        }
    });

    if !path.exists() {
        println!("[]");
        return Ok(());
    }

    let content = match fs::read_to_string(&path) {
        Ok(c) => c,
        Err(_) => {
            println!("[]");
            return Ok(());
        }
    };

    let mut merged: HashMap<String, Vec<BindItem>> = HashMap::new();
    let mut section_order: Vec<String> = Vec::new();
    let mut current_target: Option<String> = None;
    let mut current_desc: Option<String> = None;
    let mut seen_group: HashMap<String, bool> = HashMap::new();

    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;

    while i < lines.len() {
        let mut line = lines[i].trim_end().to_string();
        i += 1;

        if line.is_empty() || line.starts_with("local") || line.starts_with('$') {
            continue;
        }

        if let Some(rest) = line.strip_prefix("-- ## ") {
            let name = rest.trim();
            let target = map_section(name).to_string();
            if !merged.contains_key(&target) {
                merged.insert(target.clone(), Vec::new());
                section_order.push(target.clone());
            }

            if let Some(list) = merged.get_mut(&target) {
                list.push(BindItem {
                    is_subheader: Some(true),
                    name: Some(name.to_string()),
                    keys: None,
                    desc: None,
                });
            }
            current_target = Some(target);
            seen_group.clear();
            continue;
        }

        if let Some(rest) = line.strip_prefix("-- # ") {
            current_desc = Some(rest.trim().to_string());
            continue;
        }

        if line.starts_with("hl.") && !line.contains(',') {
            while !line.contains(',') && i < lines.len() {
                line.push(' ');
                line.push_str(lines[i].trim());
                i += 1;
            }
        }

        let mut raw_mods = String::new();
        let mut raw_key = String::new();

        if let Some(idx) = line.find("hl.bind") {
            let after = &line[idx + 7..];
            if let Some(open_paren) = after.find('(') {
                let inside = &after[open_paren + 1..];
                if let Some(comma) = inside.find(',') {
                    let arg = inside[..comma].trim();
                    let clean = arg
                        .replace("mainMod", "SUPER")
                        .replace("..", "")
                        .replace(['"', '\''], "")
                        .trim()
                        .to_string();
                    let parts: Vec<&str> = clean.split(" + ").collect();
                    if parts.len() >= 2 {
                        raw_mods = parts[..parts.len() - 1].join(" ");
                        raw_key = parts[parts.len() - 1].trim().to_string();
                    } else if parts.len() == 1 {
                        raw_key = parts[0].trim().to_string();
                    }
                }
            }
        } else if let Some(idx) = line.find("hl.keyword") {
            let after = &line[idx + 10..];
            if let Some(open_paren) = after.find('(') {
                let inside = &after[open_paren + 1..];
                let tokens: Vec<&str> = inside.split(',').collect();
                if tokens.len() >= 3 {
                    raw_mods = tokens[1].replace(['"', '\''], "").trim().to_string();
                    raw_key = tokens[2].replace(['"', '\''], "").trim().to_string();
                }
            }
        }

        if raw_key.is_empty() {
            continue;
        }
        let target = match &current_target {
            Some(t) => t.clone(),
            None => continue,
        };

        let desc = match current_desc.take() {
            Some(d) => d,
            None => continue,
        };

        if seen_group.contains_key(&desc) {
            continue;
        }
        seen_group.insert(desc.clone(), true);

        let mod_parts: Vec<String> = raw_mods
            .replace("mainMod", "SUPER")
            .replace("..", "")
            .replace(['"', '\''], "")
            .split_whitespace()
            .map(map_mod)
            .collect();

        let key = map_key(&raw_key);

        let (desc_clean, keys) = if let (Some(start), Some(end)) = (desc.find('('), desc.rfind(')'))
        {
            if start < end {
                let hint = desc[start + 1..end].to_string();
                let clean = desc[..start].trim().to_string();
                let mut k = mod_parts;
                k.push(hint);
                (clean, k)
            } else {
                let mut k = mod_parts;
                k.push(key);
                (desc, k)
            }
        } else {
            let mut k = mod_parts;
            k.push(key);
            (desc, k)
        };

        if let Some(list) = merged.get_mut(&target) {
            list.push(BindItem {
                is_subheader: None,
                name: None,
                keys: Some(keys),
                desc: Some(desc_clean),
            });
        }
    }

    let mut sections: Vec<KeybindSection> = section_order
        .into_iter()
        .filter_map(|name| {
            merged.remove(&name).map(|binds| KeybindSection {
                section: name,
                binds,
            })
        })
        .collect();

    let quickshell_binds = vec![
        BindItem {
            is_subheader: Some(true),
            name: Some("Package Manager".to_string()),
            keys: None,
            desc: Some(String::new()),
        },
        BindItem {
            is_subheader: None,
            name: None,
            keys: Some(vec!["/".to_string()]),
            desc: Some("Focus search".to_string()),
        },
        BindItem {
            is_subheader: None,
            name: None,
            keys: Some(vec!["Esc".to_string()]),
            desc: Some("Close / Blur search".to_string()),
        },
        BindItem {
            is_subheader: None,
            name: None,
            keys: Some(vec!["Navigation".to_string()]),
            desc: Some("Navigate list".to_string()),
        },
        BindItem {
            is_subheader: None,
            name: None,
            keys: Some(vec!["Ctrl".to_string(), "I".to_string()]),
            desc: Some("Open details".to_string()),
        },
    ];

    let mut qs_found = false;
    for sec in &mut sections {
        if sec.section == "Quickshell" {
            sec.binds.extend(quickshell_binds.clone());
            qs_found = true;
            break;
        }
    }
    if !qs_found {
        sections.push(KeybindSection {
            section: "Quickshell".to_string(),
            binds: quickshell_binds,
        });
    }

    let json_output = serde_json::to_string(&sections)?;
    println!("{}", json_output);
    Ok(())
}
