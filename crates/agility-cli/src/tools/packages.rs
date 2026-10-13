//! Package Manager Search Tool (Replaces quickshell/agility/Modules/PackageManager/scripts/search_packages.py)

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::process::Command;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageItem {
    pub name: String,
    pub version: String,
    pub repo: String,
    pub source: String,
    pub description: String,
    pub installed: bool,
}

pub fn search_packages(query: &str) -> Vec<PackageItem> {
    let installed_names: HashSet<String> = Command::new("pacman")
        .arg("-Qq")
        .output()
        .ok()
        .and_then(|o| String::from_utf8(o.stdout).ok())
        .map(|s| s.lines().map(|l| l.trim().to_string()).collect())
        .unwrap_or_default();

    let mut results = Vec::new();

    // 1. Search official repos via pacman -Ss
    if let Ok(out) = Command::new("pacman").args(["-Ss", query]).output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            parse_pacman_ss(&s, &installed_names, &mut results);
        }
    }

    // 2. Search AUR via yay -Ss if installed
    if let Ok(out) = Command::new("yay").args(["-Ss", "--aur", query]).output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            parse_pacman_ss(&s, &installed_names, &mut results);
        }
    }

    results
}

fn parse_pacman_ss(output: &str, installed: &HashSet<String>, results: &mut Vec<PackageItem>) {
    let mut current_header: Option<(String, String, String)> = None;
    for line in output.lines() {
        if line.starts_with(' ') || line.starts_with('\t') {
            if let Some((repo, name, ver)) = current_header.take() {
                let desc = line.trim().to_string();
                let is_inst = installed.contains(&name);
                let source = if repo.eq_ignore_ascii_case("aur") { "AUR".to_string() } else { "pacman".to_string() };
                results.push(PackageItem {
                    name,
                    version: ver,
                    repo,
                    source,
                    description: desc,
                    installed: is_inst,
                });
            }
        } else if let Some((repo_name, rest)) = line.split_once('/') {
            let parts: Vec<&str> = rest.split_whitespace().collect();
            if !parts.is_empty() {
                let pkg_name = parts[0].to_string();
                let ver = parts.get(1).unwrap_or(&"").to_string();
                current_header = Some((repo_name.to_string(), pkg_name, ver));
            }
        }
    }
}

pub fn get_installed() -> Vec<PackageItem> {
    let mut packages = Vec::new();
    if let Ok(out) = Command::new("pacman").arg("-Q").output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            for line in s.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if !parts.is_empty() {
                    let name = parts[0].to_string();
                    let version = parts.get(1).unwrap_or(&"").to_string();
                    packages.push(PackageItem {
                        name,
                        version,
                        repo: "pacman".to_string(),
                        source: "pacman".to_string(),
                        description: String::new(),
                        installed: true,
                    });
                }
            }
        }
    }
    packages
}

pub fn get_updates() -> Vec<PackageItem> {
    let mut packages = Vec::new();
    if let Ok(out) = Command::new("checkupdates").output() {
        if let Ok(s) = String::from_utf8(out.stdout) {
            for line in s.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 4 && parts[2] == "->" {
                    packages.push(PackageItem {
                        name: parts[0].to_string(),
                        version: format!("{} -> {}", parts[1], parts[3]),
                        repo: "pacman".to_string(),
                        source: "pacman".to_string(),
                        description: String::new(),
                        installed: true,
                    });
                }
            }
        }
    }
    packages
}

pub fn run(args: &[String]) -> i32 {
    let first = args.first().map(|s| s.as_str()).unwrap_or("");
    let items = match first {
        "--list-installed" | "installed" => get_installed(),
        "--list-updates" | "updates" => get_updates(),
        "--featured" => {
            let cat = args.get(1).map(|s| s.as_str()).unwrap_or("featured");
            search_packages(cat)
        }
        "search" => {
            let query = args.get(1).map(|s| s.as_str()).unwrap_or("");
            if query.is_empty() { Vec::new() } else { search_packages(query) }
        }
        other => {
            if other.is_empty() {
                Vec::new()
            } else {
                search_packages(other)
            }
        }
    };
    println!("{}", serde_json::to_string(&items).unwrap_or_default());
    0
}
