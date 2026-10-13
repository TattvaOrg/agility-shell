//! Hyprland preferences reader and updater (Replaces quickshell/agility/Core/Services/scripts/read_hypr_prefs.py and update_hypr_prefs.py)

use serde_json::{Map, Value};
use std::process::Command;

const OPTIONS: &[&str] = &[
    "decoration:blur:enabled",
    "decoration:rounding",
    "decoration:active_opacity",
    "decoration:inactive_opacity",
    "decoration:blur:size",
    "decoration:blur:passes",
    "general:gaps_in",
    "general:gaps_out",
    "general:border_size",
    "decoration:shadow:enabled",
    "decoration:shadow:range",
    "decoration:shadow:render_power",
    "animations:enabled",
    "input:sensitivity",
    "input:accel_profile",
    "input:natural_scroll",
    "input:scroll_factor",
    "input:left_handed",
    "input:follow_mouse",
    "cursor:inactive_timeout",
    "cursor:no_warps",
    "input:touchpad:natural_scroll",
    "input:touchpad:tap-to-click",
    "input:touchpad:disable_while_typing",
];

pub fn read_prefs() -> Value {
    let mut map = Map::new();

    for opt in OPTIONS {
        if let Ok(out) = Command::new("hyprctl")
            .args(["getoption", opt, "-j"])
            .output()
        {
            if let Ok(s) = String::from_utf8(out.stdout) {
                if let Ok(data) = serde_json::from_str::<Value>(&s) {
                    if let Some(v) = data.get("int") {
                        map.insert(opt.to_string(), v.clone());
                    } else if let Some(v) = data.get("float") {
                        map.insert(opt.to_string(), v.clone());
                    } else if let Some(v) = data.get("bool") {
                        map.insert(opt.to_string(), v.clone());
                    } else if let Some(v) = data.get("str") {
                        map.insert(opt.to_string(), v.clone());
                    } else if let Some(v) = data.get("custom") {
                        map.insert(opt.to_string(), v.clone());
                    }
                }
            }
        }
    }

    Value::Object(map)
}

pub fn update_prefs(json_str: &str) -> bool {
    if let Ok(data) = serde_json::from_str::<Value>(json_str) {
        if let Some(obj) = data.as_object() {
            for (k, v) in obj {
                let val_str = match v {
                    Value::Bool(b) => {
                        if *b {
                            "1".to_string()
                        } else {
                            "0".to_string()
                        }
                    }
                    Value::Number(n) => n.to_string(),
                    Value::String(s) => s.clone(),
                    _ => v.to_string(),
                };
                let _ = Command::new("hyprctl")
                    .args(["keyword", k, &val_str])
                    .status();
            }
            return true;
        }
    }
    false
}

pub fn run(args: &[String]) -> i32 {
    let first = args.first().map(|s| s.as_str()).unwrap_or("read");
    if first == "read" {
        let prefs = read_prefs();
        println!("{}", serde_json::to_string(&prefs).unwrap_or_default());
        0
    } else if first == "update" {
        if let Some(arg) = args.get(1) {
            if update_prefs(arg) {
                0
            } else {
                1
            }
        } else {
            eprintln!("Missing JSON args for update");
            1
        }
    } else if first.trim().starts_with('{') {
        if update_prefs(first) {
            0
        } else {
            1
        }
    } else {
        let prefs = read_prefs();
        println!("{}", serde_json::to_string(&prefs).unwrap_or_default());
        0
    }
}
