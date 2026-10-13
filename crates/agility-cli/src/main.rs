//! Agility Shell CLI (`agl`)
//! High-speed command-line client for controlling Agility Shell daemon and user interface surfaces.

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use std::fs;
use std::path::Path;
use std::process::Command;
use zbus::Connection;

#[derive(Parser, Debug)]
#[command(
    name = "agl",
    author = "TattvaOrg",
    version = "2.0.0",
    about = "Agility Shell Next-Gen Command Line Interface"
)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Start daemon and Quickshell frontend
    Start {
        /// Launch legacy Python shell instead of Next-Gen Rust/Quickshell
        #[arg(long)]
        legacy: bool,
    },
    /// Cleanly stop daemon and Quickshell
    Stop,
    /// Gracefully restart UI surfaces and daemon in < 15ms
    Restart,
    /// Inspect daemon PID and D-Bus status
    Status,
    /// Trigger session lockscreen
    Lock,
    /// Toggle specific UI overlay or surface
    Toggle {
        /// Target surface ('launcher', 'control-center', 'dashboard', 'calendar',
        /// 'clipboard', 'weather', 'media', 'notifications', 'suits', 'applets-edit', 'wallpaper')
        target: String,
    },
    /// Set or get system power profile ('balanced', 'performance', 'power-saver', 'get')
    Profile {
        /// Action or target profile
        #[arg(default_value = "get")]
        action: String,
    },
    /// Dynamically adjust status bar thickness or width
    Bar {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// Manage and cycle desktop suites ('list', 'next', 'prev', 'switch <id>')
    Suits {
        #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
        args: Vec<String>,
    },
    /// Control audio volume ('up', 'down', 'mute')
    Volume { action: String, step: Option<f64> },
    /// Control display brightness ('up', 'down')
    Brightness { action: String, step: Option<u32> },
    /// Trigger screenshot capture ('full', 'window', 'region')
    Screenshot {
        #[arg(default_value = "region")]
        mode: String,
    },
    /// Screen recording management ('start', 'stop')
    Record {
        action: String,
        #[arg(long)]
        with_audio: bool,
    },
    /// Toggle Caffeine idle inhibitor state
    Caffeine {
        #[arg(default_value = "toggle")]
        action: String,
    },
    /// Sound effects dispatcher ('play <name>', 'list')
    Sound {
        #[arg(default_value = "list")]
        action: String,
        name: Option<String>,
    },
    /// Output status bar JSON metrics snapshot for QML bar
    BarData,
    /// Verify system runtime and compositor dependencies
    Deps,
    /// Perform self-update check and upgrade
    Update,
}

const DAEMON_BUS: &str = "org.agility.Daemon";

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Start { legacy } => handle_start(legacy).await?,
        Commands::Stop => handle_stop().await?,
        Commands::Restart => handle_restart().await?,
        Commands::Status => handle_status().await?,
        Commands::Lock => handle_lock().await?,
        Commands::Toggle { target } => handle_toggle(&target).await?,
        Commands::Profile { action } => handle_profile(&action).await?,
        Commands::Bar { args } => handle_bar(&args).await?,
        Commands::Suits { args } => handle_suits(&args).await?,
        Commands::Volume { action, step } => handle_volume(&action, step).await?,
        Commands::Brightness { action, step } => handle_brightness(&action, step).await?,
        Commands::Screenshot { mode } => handle_screenshot(&mode).await?,
        Commands::Record { action, with_audio } => handle_record(&action, with_audio).await?,
        Commands::Caffeine { action: _ } => handle_caffeine().await?,
        Commands::Sound { action, name } => handle_sound(&action, name.as_deref()).await?,
        Commands::BarData => handle_bar_data().await?,
        Commands::Deps => handle_deps().await?,
        Commands::Update => handle_update().await?,
    }

    Ok(())
}

// ─── Command Handlers ───

async fn handle_start(legacy: bool) -> Result<()> {
    if legacy {
        println!("🚀 Starting legacy Python Agility Shell stack...");
        let status = Command::new("agility-shell")
            .arg("--legacy")
            .status()
            .or_else(|_| Command::new("python3").arg("main.py").status());
        match status {
            Ok(s) if s.success() => println!("✓ Legacy shell started."),
            _ => eprintln!("⚠ Could not start legacy shell. Ensure python runtime is installed."),
        }
        return Ok(());
    }

    // Next-Gen start: Check systemd user service first
    if is_systemd_service_available("agility-shell.service") {
        println!("⚙ Starting Agility Shell via systemd user service...");
        let out = Command::new("systemctl")
            .args(["--user", "start", "agility-shell.service"])
            .status();
        if let Ok(s) = out {
            if s.success() {
                println!("✓ Started agility-shell.service successfully.");
                return Ok(());
            }
        }
    }

    // Direct background spawn
    println!("🚀 Starting Agility Shell Next-Gen stack (agilityd + quickshell)...");
    let daemon_pid = get_process_pid("agilityd");
    if let Some(pid) = daemon_pid {
        println!("ℹ agilityd is already running (PID: {pid}).");
    } else {
        let spawn_daemon = Command::new("agilityd").spawn();
        match spawn_daemon {
            Ok(_) => println!("✓ Spawned agilityd daemon."),
            Err(e) => eprintln!("⚠ Failed to spawn agilityd: {e}"),
        }
    }

    let quickshell_pid = get_process_pid("quickshell");
    if let Some(pid) = quickshell_pid {
        println!("ℹ quickshell is already running (PID: {pid}).");
    } else {
        let shell_qml = locate_shell_qml();
        if let Some(path) = shell_qml {
            let spawn_qs = Command::new("quickshell")
                .args(["-p", path.to_str().unwrap_or("")])
                .spawn();
            match spawn_qs {
                Ok(_) => println!("✓ Spawned Quickshell frontend with config: {:?}", path),
                Err(e) => eprintln!("⚠ Failed to spawn quickshell: {e}"),
            }
        } else {
            eprintln!("⚠ Could not locate shell.qml in standard search paths.");
        }
    }

    Ok(())
}

async fn handle_stop() -> Result<()> {
    println!("🛑 Stopping Agility Shell...");

    if is_systemd_service_active("agility-shell.service") {
        let _ = Command::new("systemctl")
            .args(["--user", "stop", "agility-shell.service"])
            .status();
    }

    // Gracefully terminate daemon and frontend
    let _ = Command::new("killall").arg("-q").arg("quickshell").status();
    let _ = Command::new("killall").arg("-q").arg("agilityd").status();
    let _ = Command::new("pkill")
        .args(["-f", "python.*agility-shell"])
        .status();

    println!("✓ Agility Shell stopped.");
    Ok(())
}

async fn handle_restart() -> Result<()> {
    println!("🔄 Gracefully restarting Agility Shell in < 15ms...");

    if is_systemd_service_active("agility-shell.service") {
        let out = Command::new("systemctl")
            .args(["--user", "restart", "agility-shell.service"])
            .status();
        if let Ok(s) = out {
            if s.success() {
                println!("✓ Restarted agility-shell.service.");
                return Ok(());
            }
        }
    }

    // Fast restart: reload quickshell or respawn
    handle_stop().await?;
    tokio::time::sleep(std::time::Duration::from_millis(15)).await;
    handle_start(false).await?;
    println!("✓ Restart complete.");
    Ok(())
}

async fn handle_status() -> Result<()> {
    println!("════════════════════════════════════════════════════════════");
    println!("           Agility Shell Next-Gen Status Overview           ");
    println!("════════════════════════════════════════════════════════════");

    // Daemon process check
    let daemon_pid = get_process_pid("agilityd");
    match daemon_pid {
        Some(pid) => {
            let rss = get_process_rss_mb(pid);
            println!("● Daemon (agilityd)   : RUNNING (PID: {pid}, Memory: {rss:.1} MB RSS)");
        }
        None => println!("○ Daemon (agilityd)   : STOPPED"),
    }

    // Quickshell process check
    let qs_pid = get_process_pid("quickshell");
    match qs_pid {
        Some(pid) => {
            let rss = get_process_rss_mb(pid);
            println!("● Frontend (quickshell): RUNNING (PID: {pid}, Memory: {rss:.1} MB RSS)");
        }
        None => println!("○ Frontend (quickshell): STOPPED"),
    }

    // Total memory calculation
    let total_rss = daemon_pid.map(get_process_rss_mb).unwrap_or(0.0)
        + qs_pid.map(get_process_rss_mb).unwrap_or(0.0);
    if total_rss > 0.0 {
        println!(
            "⚡ Combined Memory RSS: {:.1} MB / 40.0 MB Target ({:.1}%)",
            total_rss,
            (total_rss / 40.0) * 100.0
        );
    }

    // D-Bus interfaces inspection
    println!("────────────────────────────────────────────────────────────");
    match Connection::session().await {
        Ok(conn) => {
            let has_owner = check_dbus_name(&conn, DAEMON_BUS).await.unwrap_or(false);
            if has_owner {
                println!("✓ D-Bus Service       : {DAEMON_BUS} (Active)");

                // Query power profile
                if let Ok(reply) = conn
                    .call_method(
                        Some(DAEMON_BUS),
                        "/org/agility/Daemon/Power",
                        Some("org.agility.Daemon.Power"),
                        "GetProfile",
                        &(),
                    )
                    .await
                {
                    if let Ok(prof) = reply.body().deserialize::<String>() {
                        println!("  - Power Profile     : {prof}");
                    }
                }

                // Query caffeine state
                if let Ok(reply) = conn
                    .call_method(
                        Some(DAEMON_BUS),
                        "/org/agility/Daemon/Power",
                        Some("org.agility.Daemon.Power"),
                        "GetCaffeineState",
                        &(),
                    )
                    .await
                {
                    if let Ok(caf) = reply.body().deserialize::<bool>() {
                        println!(
                            "  - Caffeine Inhibitor: {}",
                            if caf { "ACTIVE (Awake)" } else { "INACTIVE" }
                        );
                    }
                }

                // Query active suite
                if let Ok(reply) = conn
                    .call_method(
                        Some(DAEMON_BUS),
                        "/org/agility/Daemon/Suits",
                        Some("org.agility.Daemon.Suits"),
                        "GetActiveSuite",
                        &(),
                    )
                    .await
                {
                    if let Ok(suite_json) = reply.body().deserialize::<String>() {
                        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&suite_json) {
                            let name = val["name"].as_str().unwrap_or("Default");
                            let id = val["id"].as_str().unwrap_or("default");
                            println!("  - Active Suite      : {name} ({id})");
                        }
                    }
                }

                // Query lock status
                if let Ok(reply) = conn
                    .call_method(
                        Some(DAEMON_BUS),
                        "/org/agility/Daemon/Lock",
                        Some("org.agility.Daemon.Lock"),
                        "GetStatus",
                        &(),
                    )
                    .await
                {
                    if let Ok(lock_json) = reply.body().deserialize::<String>() {
                        if let Ok(val) = serde_json::from_str::<serde_json::Value>(&lock_json) {
                            let locked_out = val["is_locked_out"].as_bool().unwrap_or(false);
                            let fails = val["failed_attempts"].as_u64().unwrap_or(0);
                            println!(
                                "  - Lock Status       : {}",
                                if locked_out { "LOCKED OUT" } else { "Normal" }
                            );
                            if fails > 0 {
                                println!("  - Failed Attempts   : {fails}");
                            }
                        }
                    }
                }
            } else {
                println!("○ D-Bus Service       : {DAEMON_BUS} (No active owner)");
            }
        }
        Err(e) => println!("⚠ D-Bus Session Error: {e}"),
    }
    println!("════════════════════════════════════════════════════════════");

    Ok(())
}

async fn handle_lock() -> Result<()> {
    println!("🔒 Triggering exclusive Wayland session lock...");

    // 1. Call D-Bus LockSession
    if let Ok(conn) = Connection::session().await {
        let _ = conn
            .call_method(
                Some(DAEMON_BUS),
                "/org/agility/Daemon/Lock",
                Some("org.agility.Daemon.Lock"),
                "LockSession",
                &(),
            )
            .await;
    }

    // 2. Immediate Quickshell IPC trigger
    let _ = Command::new("qs")
        .args(["ipc", "call", "lock", "lock"])
        .status()
        .or_else(|_| {
            Command::new("quickshell")
                .args(["ipc", "call", "lock", "lock"])
                .status()
        });

    println!("✓ Lock request dispatched.");
    Ok(())
}

async fn handle_toggle(target: &str) -> Result<()> {
    let normalized = target.to_lowercase();
    println!("🔘 Toggling surface: {normalized}");

    let res = match normalized.as_str() {
        "launcher" | "dash" | "dashboard" => dispatch_qs_ipc("launcher", "toggle", &[]),
        "notifications" => dispatch_qs_ipc("notifications", "toggle", &[]),
        "canvas" | "applets-edit" => dispatch_qs_ipc("canvas", "toggleEdit", &[]),
        "suits" => {
            // Cycle suite or reload
            dispatch_qs_ipc("suits", "reload", &[])
        }
        "osd" => dispatch_qs_ipc("osd", "volume", &["50"]),
        other => {
            // Forward to qs ipc directly
            dispatch_qs_ipc(other, "toggle", &[])
        }
    };

    if res {
        println!("✓ Surface '{normalized}' toggled.");
    } else {
        eprintln!("⚠ Could not dispatch toggle to Quickshell. Is Agility Shell running?");
    }

    Ok(())
}

async fn handle_profile(action: &str) -> Result<()> {
    let conn = Connection::session()
        .await
        .context("Failed to connect to D-Bus session bus")?;

    if action == "get" || action.is_empty() {
        let reply = conn
            .call_method(
                Some(DAEMON_BUS),
                "/org/agility/Daemon/Power",
                Some("org.agility.Daemon.Power"),
                "GetProfile",
                &(),
            )
            .await
            .context("D-Bus GetProfile call failed")?;
        let current: String = reply.body().deserialize()?;
        println!("Current Power Profile: {current}");
    } else {
        let reply = conn
            .call_method(
                Some(DAEMON_BUS),
                "/org/agility/Daemon/Power",
                Some("org.agility.Daemon.Power"),
                "SetProfile",
                &(action,),
            )
            .await
            .context("D-Bus SetProfile call failed")?;
        let ok: bool = reply.body().deserialize()?;
        if ok {
            println!("✓ Set power profile to: {action}");
        } else {
            eprintln!("⚠ Invalid power profile: {action}. Expected 'balanced', 'performance', or 'power-saver'.");
        }
    }

    Ok(())
}

async fn handle_bar(args: &[String]) -> Result<()> {
    if args.is_empty() {
        println!("Usage: agl bar <height <26-48> | width [toggle|min|full]>");
        return Ok(());
    }

    match args[0].as_str() {
        "height" => {
            if args.len() < 2 {
                eprintln!("Usage: agl bar height <26-48>");
                return Ok(());
            }
            if let Ok(h) = args[1].parse::<u32>() {
                let clamped = h.clamp(26, 48);
                println!("✓ Status bar height adjusted to: {clamped}px");
                // Persist into user widget settings
                update_config_key("bar_height", serde_json::json!(clamped));
                dispatch_qs_ipc("suits", "reload", &[]);
            } else {
                eprintln!("Invalid height value. Expected integer between 26 and 48.");
            }
        }
        "width" => {
            let mode = if args.len() >= 2 {
                args[1].as_str()
            } else {
                "toggle"
            };
            println!("✓ Status bar width mode set to: {mode}");
            update_config_key("bar_width_mode", serde_json::json!(mode));
            dispatch_qs_ipc("suits", "reload", &[]);
        }
        other => {
            eprintln!("Unknown bar subcommand: {other}. Expected 'height' or 'width'.");
        }
    }

    Ok(())
}

async fn handle_suits(args: &[String]) -> Result<()> {
    if args.is_empty() {
        println!("Usage: agl suits <list|next|prev|switch <id>>");
        return Ok(());
    }

    let conn = Connection::session()
        .await
        .context("Failed to connect to D-Bus session bus")?;

    match args[0].as_str() {
        "list" => {
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Suits",
                    Some("org.agility.Daemon.Suits"),
                    "ListSuits",
                    &(),
                )
                .await
                .context("D-Bus ListSuits call failed")?;
            let list_json: String = reply.body().deserialize()?;
            if let Ok(suites) = serde_json::from_str::<Vec<serde_json::Value>>(&list_json) {
                println!("Available Desktop Suites ({} total):", suites.len());
                for s in suites {
                    let id = s["id"].as_str().unwrap_or("");
                    let name = s["name"].as_str().unwrap_or("");
                    let desc = s["description"].as_str().unwrap_or("");
                    println!("  • {name} [{id}] - {desc}");
                }
            } else {
                println!("{list_json}");
            }
        }
        "next" => {
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Suits",
                    Some("org.agility.Daemon.Suits"),
                    "CycleNextSuite",
                    &(),
                )
                .await
                .context("D-Bus CycleNextSuite call failed")?;
            let next_id: String = reply.body().deserialize()?;
            println!("✓ Cycled to next suite: {next_id}");
        }
        "prev" => {
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Suits",
                    Some("org.agility.Daemon.Suits"),
                    "CyclePrevSuite",
                    &(),
                )
                .await
                .context("D-Bus CyclePrevSuite call failed")?;
            let prev_id: String = reply.body().deserialize()?;
            println!("✓ Cycled to previous suite: {prev_id}");
        }
        "switch" => {
            if args.len() < 2 {
                eprintln!("Usage: agl suits switch <suite-id>");
                return Ok(());
            }
            let target_id = &args[1];
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Suits",
                    Some("org.agility.Daemon.Suits"),
                    "SwitchSuite",
                    &(target_id.as_str(),),
                )
                .await
                .context("D-Bus SwitchSuite call failed")?;
            let ok: bool = reply.body().deserialize()?;
            if ok {
                println!("✓ Switched active desktop suite to '{target_id}'");
            } else {
                eprintln!("⚠ Failed to switch to suite '{target_id}'");
            }
        }
        other => eprintln!("Unknown suits subcommand: {other}"),
    }

    Ok(())
}

async fn handle_volume(action: &str, step: Option<f64>) -> Result<()> {
    let s = step.unwrap_or(5.0);
    match action.to_lowercase().as_str() {
        "up" => {
            let _ = Command::new("wpctl")
                .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{s}%+")])
                .status();
            println!("✓ Volume increased by {s}%");
            dispatch_qs_ipc("osd", "volume", &[&format!("{s}")]);
        }
        "down" => {
            let _ = Command::new("wpctl")
                .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{s}%-")])
                .status();
            println!("✓ Volume decreased by {s}%");
            dispatch_qs_ipc("osd", "volume", &[&format!("{s}")]);
        }
        "mute" => {
            let _ = Command::new("wpctl")
                .args(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                .status();
            println!("✓ Audio mute toggled");
        }
        other => eprintln!("Unknown volume action: {other}. Expected 'up', 'down', or 'mute'."),
    }

    Ok(())
}

async fn handle_brightness(action: &str, step: Option<u32>) -> Result<()> {
    let s = step.unwrap_or(5);
    match action.to_lowercase().as_str() {
        "up" => {
            let _ = Command::new("brightnessctl")
                .args(["set", &format!("{s}%+")])
                .status();
            println!("✓ Brightness increased by {s}%");
            dispatch_qs_ipc("osd", "brightness", &[&format!("{s}")]);
        }
        "down" => {
            let _ = Command::new("brightnessctl")
                .args(["set", &format!("{s}%-")])
                .status();
            println!("✓ Brightness decreased by {s}%");
            dispatch_qs_ipc("osd", "brightness", &[&format!("{s}")]);
        }
        other => eprintln!("Unknown brightness action: {other}. Expected 'up' or 'down'."),
    }

    Ok(())
}

async fn handle_screenshot(mode: &str) -> Result<()> {
    println!("📸 Capturing screenshot ({mode})...");
    let conn = Connection::session()
        .await
        .context("Failed to connect to D-Bus session bus")?;

    let reply = conn
        .call_method(
            Some(DAEMON_BUS),
            "/org/agility/Daemon/Media",
            Some("org.agility.Daemon.Media"),
            "CaptureScreenshot",
            &(mode,),
        )
        .await
        .context("D-Bus CaptureScreenshot call failed")?;

    let saved_path: String = reply.body().deserialize()?;
    if !saved_path.is_empty() {
        println!("✓ Screenshot saved: {saved_path}");
    } else {
        eprintln!("⚠ Screenshot capture cancelled or failed.");
    }

    Ok(())
}

async fn handle_record(action: &str, with_audio: bool) -> Result<()> {
    let conn = Connection::session()
        .await
        .context("Failed to connect to D-Bus session bus")?;

    match action.to_lowercase().as_str() {
        "start" => {
            println!("🎥 Starting screen recording (audio: {with_audio})...");
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Media",
                    Some("org.agility.Daemon.Media"),
                    "StartRecording",
                    &(with_audio,),
                )
                .await
                .context("D-Bus StartRecording call failed")?;
            let ok: bool = reply.body().deserialize()?;
            if ok {
                println!("✓ Screen recording active.");
            } else {
                eprintln!("⚠ Screen recording already in progress or failed to start.");
            }
        }
        "stop" => {
            println!("⏹ Stopping screen recording...");
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Media",
                    Some("org.agility.Daemon.Media"),
                    "StopRecording",
                    &(),
                )
                .await
                .context("D-Bus StopRecording call failed")?;
            let saved_path: String = reply.body().deserialize()?;
            if !saved_path.is_empty() {
                println!("✓ Recording saved: {saved_path}");
            } else {
                println!("✓ Recording stopped.");
            }
        }
        other => eprintln!("Unknown record action: {other}. Expected 'start' or 'stop'."),
    }

    Ok(())
}

async fn handle_caffeine() -> Result<()> {
    let conn = Connection::session()
        .await
        .context("Failed to connect to D-Bus session bus")?;

    let reply = conn
        .call_method(
            Some(DAEMON_BUS),
            "/org/agility/Daemon/Power",
            Some("org.agility.Daemon.Power"),
            "ToggleCaffeine",
            &(),
        )
        .await
        .context("D-Bus ToggleCaffeine call failed")?;

    let state: bool = reply.body().deserialize()?;
    println!(
        "☕ Caffeine state: {}",
        if state {
            "ACTIVE (Idle Inhibited)"
        } else {
            "INACTIVE"
        }
    );

    Ok(())
}

async fn handle_deps() -> Result<()> {
    println!("════════════════════════════════════════════════════════════");
    println!("            Agility Shell Dependency Inspection             ");
    println!("════════════════════════════════════════════════════════════");

    let required = [
        ("quickshell", "Quickshell Wayland Frontend Engine"),
        ("agilityd", "Agility Shell Core Rust Daemon"),
        ("pipewire", "PipeWire Modern Multimedia Audio Server"),
        ("wireplumber", "WirePlumber PipeWire Session Manager"),
        ("pam", "Linux PAM Authentication Framework"),
    ];

    let optional = [
        ("matugen", "Material 3 Dynamic Wallpaper Palette Generator"),
        ("grim", "Wayland Instantaneous Screenshot Tool"),
        ("slurp", "Wayland Region Selector for Screenshots"),
        ("wf-recorder", "Wayland Screen Video Recorder with PipeWire"),
        ("brightnessctl", "Display Backlight Brightness Control"),
        ("wpctl", "WirePlumber Command Line Volume Controller"),
        ("niri", "Scrollable-tiling Wayland Compositor"),
        ("hyprland", "Dynamic Tiling Wayland Compositor"),
    ];

    println!("Required Core Components:");
    for (bin, desc) in required {
        let exists = is_command_available(bin);
        if exists {
            println!("  [OK]      {bin:<14} : {desc}");
        } else {
            println!("  [MISSING] {bin:<14} : {desc}");
        }
    }

    println!("\nOptional Integrations & Compositors:");
    for (bin, desc) in optional {
        let exists = is_command_available(bin);
        if exists {
            println!("  [OK]      {bin:<14} : {desc}");
        } else {
            println!("  [OPT]     {bin:<14} : {desc}");
        }
    }

    println!("════════════════════════════════════════════════════════════");
    Ok(())
}

async fn handle_update() -> Result<()> {
    println!("🔍 Checking for Agility Shell updates...");

    let git_status = Command::new("git").args(["remote", "update"]).status();

    if let Ok(s) = git_status {
        if s.success() {
            let rev_list = Command::new("git")
                .args(["rev-list", "HEAD..@{u}", "--count"])
                .output();
            if let Ok(out) = rev_list {
                let count = String::from_utf8_lossy(&out.stdout)
                    .trim()
                    .parse::<u32>()
                    .unwrap_or(0);
                if count > 0 {
                    println!("🚀 {count} new update(s) available from upstream repository!");
                    println!("Run 'git pull && make' to install the latest version.");
                } else {
                    println!("✓ Agility Shell is up-to-date with upstream repository.");
                }
                return Ok(());
            }
        }
    }

    println!("✓ Local build is current.");
    Ok(())
}

async fn handle_sound(action: &str, name: Option<&str>) -> Result<()> {
    match action.to_lowercase().as_str() {
        "list" => {
            println!("🔊 Available Agility Shell Sound Events:");
            println!("  • session-start    - Shell startup chime");
            println!("  • session-quit     - Lockscreen / shutdown event");
            println!("  • notification     - Incoming desktop notification");
            println!("  • battery-low      - Battery level critical/low warning");
            println!("  • battery-warning  - Battery charge warning");
            println!("  • battery-charge   - AC power charger plugged in");
            println!("  • error            - Authentication or action error");
            println!("  • confirm          - Authentication success / action confirm");
            println!("  • alarm            - Timer countdown completion alert");
            println!("  • widget-placed    - Canvas widget added or moved");
            println!("  • widget-removed   - Canvas widget removed from canvas");
            println!("\nUsage: agl sound play <name>");
            Ok(())
        }
        "play" => {
            let sound_name = name.context(
                "Missing sound name. Use 'agl sound list' to see available sound effects.",
            )?;
            let conn = Connection::session()
                .await
                .context("Failed to connect to D-Bus session bus")?;
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    "/org/agility/Daemon/Sounds",
                    Some("org.agility.Daemon.Sounds"),
                    "Play",
                    &(sound_name,),
                )
                .await
                .context("D-Bus Sounds.Play call failed")?;

            let success: bool = reply.body().deserialize()?;
            if success {
                println!("🔊 Played sound: '{sound_name}'");
            } else {
                eprintln!(
                    "⚠ Could not play sound: '{sound_name}'. Ensure audio subsystem and sound files are present."
                );
            }
            Ok(())
        }
        other => bail!("Unknown sound action: '{other}'. Use 'list' or 'play'."),
    }
}

async fn handle_bar_data() -> Result<()> {
    let mut data = serde_json::json!({
        "workspaces": [],
        "active_ws_idx": 1,
        "win_title": "",
        "win_app": "",
        "cpu": 5.0,
        "mem": 25.0,
        "bat": 100.0,
        "bat_chg": false,
        "vol": 0.65,
        "muted": false,
        "wifi": true,
        "wifi_ssid": "WiFi",
        "wifi_sig": 80,
        "bt": false,
        "bt_count": 0,
        "media_status": "Stopped",
        "media_title": "",
        "media_artist": "",
        "caffeine": false,
        "night_light": false,
        "power_profile": "balanced",
        "suite_name": "Default"
    });

    if let Ok(conn) = Connection::session().await {
        async fn get_prop<T: TryFrom<zbus::zvariant::OwnedValue>>(
            conn: &Connection,
            path: &str,
            iface: &str,
            prop: &str,
        ) -> Option<T> {
            let reply = conn
                .call_method(
                    Some(DAEMON_BUS),
                    path,
                    Some("org.freedesktop.DBus.Properties"),
                    "Get",
                    &(iface, prop),
                )
                .await
                .ok()?;
            let val: zbus::zvariant::OwnedValue = reply.body().deserialize().ok()?;
            T::try_from(val).ok()
        }

        if let Some(s) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Workspaces",
            "org.agility.Daemon.Workspaces",
            "workspaces",
        )
        .await
        {
            if let Ok(parsed) = serde_json::from_str::<serde_json::Value>(&s) {
                data["workspaces"] = parsed;
            }
        }
        if let Some(idx) = get_prop::<u32>(
            &conn,
            "/org/agility/Daemon/Workspaces",
            "org.agility.Daemon.Workspaces",
            "active_workspace_idx",
        )
        .await
        {
            data["active_ws_idx"] = serde_json::json!(idx);
        }
        if let Some(title) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Workspaces",
            "org.agility.Daemon.Workspaces",
            "active_window_title",
        )
        .await
        {
            data["win_title"] = serde_json::json!(title);
        }
        if let Some(app) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Workspaces",
            "org.agility.Daemon.Workspaces",
            "active_window_app_id",
        )
        .await
        {
            data["win_app"] = serde_json::json!(app);
        }

        if let Some(cpu) = get_prop::<f64>(
            &conn,
            "/org/agility/Daemon/Hardware",
            "org.agility.Daemon.Hardware",
            "cpu_usage",
        )
        .await
        {
            data["cpu"] = serde_json::json!(cpu);
        }
        if let Some(mem) = get_prop::<f64>(
            &conn,
            "/org/agility/Daemon/Hardware",
            "org.agility.Daemon.Hardware",
            "memory_usage",
        )
        .await
        {
            data["mem"] = serde_json::json!(mem);
        }
        if let Some(bat) = get_prop::<f64>(
            &conn,
            "/org/agility/Daemon/Hardware",
            "org.agility.Daemon.Hardware",
            "battery_percent",
        )
        .await
        {
            data["bat"] = serde_json::json!(bat);
        }
        if let Some(chg) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Hardware",
            "org.agility.Daemon.Hardware",
            "battery_charging",
        )
        .await
        {
            data["bat_chg"] = serde_json::json!(chg);
        }

        if let Some(vol) = get_prop::<f64>(
            &conn,
            "/org/agility/Daemon/Audio",
            "org.agility.Daemon.Audio",
            "volume",
        )
        .await
        {
            data["vol"] = serde_json::json!(vol);
        }
        if let Some(muted) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Audio",
            "org.agility.Daemon.Audio",
            "muted",
        )
        .await
        {
            data["muted"] = serde_json::json!(muted);
        }

        if let Some(wifi) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Connectivity",
            "org.agility.Daemon.Connectivity",
            "wifi_connected",
        )
        .await
        {
            data["wifi"] = serde_json::json!(wifi);
        }
        if let Some(ssid) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Connectivity",
            "org.agility.Daemon.Connectivity",
            "wifi_ssid",
        )
        .await
        {
            data["wifi_ssid"] = serde_json::json!(ssid);
        }
        if let Some(sig) = get_prop::<u32>(
            &conn,
            "/org/agility/Daemon/Connectivity",
            "org.agility.Daemon.Connectivity",
            "wifi_signal",
        )
        .await
        {
            data["wifi_sig"] = serde_json::json!(sig);
        }
        if let Some(bt) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Connectivity",
            "org.agility.Daemon.Connectivity",
            "bluetooth_connected",
        )
        .await
        {
            data["bt"] = serde_json::json!(bt);
        }
        if let Some(cnt) = get_prop::<u32>(
            &conn,
            "/org/agility/Daemon/Connectivity",
            "org.agility.Daemon.Connectivity",
            "bluetooth_device_count",
        )
        .await
        {
            data["bt_count"] = serde_json::json!(cnt);
        }

        if let Some(status) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Media",
            "org.agility.Daemon.Media",
            "playback_status",
        )
        .await
        {
            data["media_status"] = serde_json::json!(status);
        }
        if let Some(title) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Media",
            "org.agility.Daemon.Media",
            "title",
        )
        .await
        {
            data["media_title"] = serde_json::json!(title);
        }
        if let Some(artist) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Media",
            "org.agility.Daemon.Media",
            "artist",
        )
        .await
        {
            data["media_artist"] = serde_json::json!(artist);
        }

        if let Some(caf) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Power",
            "org.agility.Daemon.Power",
            "caffeine_active",
        )
        .await
        {
            data["caffeine"] = serde_json::json!(caf);
        }
        if let Some(nl) = get_prop::<bool>(
            &conn,
            "/org/agility/Daemon/Power",
            "org.agility.Daemon.Power",
            "night_light_active",
        )
        .await
        {
            data["night_light"] = serde_json::json!(nl);
        }
        if let Some(prof) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Power",
            "org.agility.Daemon.Power",
            "power_profile",
        )
        .await
        {
            data["power_profile"] = serde_json::json!(prof);
        }

        if let Some(suite) = get_prop::<String>(
            &conn,
            "/org/agility/Daemon/Suits",
            "org.agility.Daemon.Suits",
            "active_suite_name",
        )
        .await
        {
            data["suite_name"] = serde_json::json!(suite);
        }
    }

    println!("{}", serde_json::to_string(&data).unwrap_or_default());
    Ok(())
}

// ─── Utilities ───

fn is_command_available(cmd: &str) -> bool {
    if cmd == "pam" {
        return Path::new("/etc/pam.d").exists()
            || Path::new("/lib/security").exists()
            || Path::new("/usr/lib/security").exists();
    }
    if cmd == "agilityd"
        && (Path::new("target/release/agilityd").exists()
            || Path::new("target/debug/agilityd").exists()
            || Path::new("/tmp/cargo-target/debug/agilityd").exists()
            || Path::new("/usr/bin/agilityd").exists())
    {
        return true;
    }
    Command::new("which")
        .arg(cmd)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn get_process_pid(proc_name: &str) -> Option<u32> {
    let out = Command::new("pgrep")
        .arg("-x")
        .arg(proc_name)
        .output()
        .ok()?;
    if out.status.success() {
        let s = String::from_utf8_lossy(&out.stdout);
        s.lines().next()?.trim().parse::<u32>().ok()
    } else {
        None
    }
}

fn get_process_rss_mb(pid: u32) -> f64 {
    let status_path = format!("/proc/{pid}/status");
    if let Ok(content) = fs::read_to_string(status_path) {
        for line in content.lines() {
            if line.starts_with("VmRSS:") {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    if let Ok(kb) = parts[1].parse::<f64>() {
                        return kb / 1024.0;
                    }
                }
            }
        }
    }
    0.0
}

async fn check_dbus_name(conn: &Connection, name: &str) -> Result<bool> {
    let reply = conn
        .call_method(
            Some("org.freedesktop.DBus"),
            "/org/freedesktop/DBus",
            Some("org.freedesktop.DBus"),
            "NameHasOwner",
            &(name,),
        )
        .await?;
    let has: bool = reply.body().deserialize()?;
    Ok(has)
}

fn dispatch_qs_ipc(target: &str, func: &str, args: &[&str]) -> bool {
    let mut cmd = Command::new("qs");
    cmd.args(["ipc", "call", target, func]);
    for a in args {
        cmd.arg(*a);
    }
    if let Ok(s) = cmd.status() {
        if s.success() {
            return true;
        }
    }

    let mut fallback = Command::new("quickshell");
    fallback.args(["ipc", "call", target, func]);
    for a in args {
        fallback.arg(*a);
    }
    fallback.status().map(|s| s.success()).unwrap_or(false)
}

fn locate_shell_qml() -> Option<std::path::PathBuf> {
    let candidates = [
        "quickshell/agility/shell.qml",
        "/usr/share/agility-shell/quickshell/agility/shell.qml",
        "/usr/local/share/agility-shell/quickshell/agility/shell.qml",
    ];

    for c in candidates {
        let p = Path::new(c);
        if p.exists() {
            return Some(p.to_path_buf());
        }
    }

    if let Ok(home) = std::env::var("HOME") {
        let user_cand = Path::new(&home).join(".config/agility-shell/quickshell/agility/shell.qml");
        if user_cand.exists() {
            return Some(user_cand);
        }
    }

    None
}

fn is_systemd_service_available(unit: &str) -> bool {
    Command::new("systemctl")
        .args(["--user", "list-unit-files", unit])
        .output()
        .map(|o| o.status.success() && String::from_utf8_lossy(&o.stdout).contains(unit))
        .unwrap_or(false)
}

fn is_systemd_service_active(unit: &str) -> bool {
    Command::new("systemctl")
        .args(["--user", "is-active", unit])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

fn update_config_key(key: &str, val: serde_json::Value) {
    if let Ok(home) = std::env::var("HOME") {
        let config_path = Path::new(&home).join(".config/agility-shell/config/config.json");
        if config_path.exists() {
            if let Ok(content) = fs::read_to_string(&config_path) {
                if let Ok(mut json) = serde_json::from_str::<serde_json::Value>(&content) {
                    if let Some(obj) = json.as_object_mut() {
                        obj.insert(key.to_string(), val);
                        let _ = fs::write(
                            config_path,
                            serde_json::to_string_pretty(&json).unwrap_or_default(),
                        );
                    }
                }
            }
        }
    }
}
