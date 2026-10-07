//! Agility Shell CLI (`agl`)
//! Command-line client for controlling Agility Shell daemon and user interface.

use anyhow::Result;
use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(
    name = "agl",
    author = "TattvaOrg",
    version,
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
    /// Restart UI surfaces and daemon
    Restart,
    /// Check daemon process and D-Bus registration status
    Status,
    /// Trigger session lockscreen
    Lock,
    /// Toggle specific UI overlay or surface
    Toggle {
        /// Target surface to toggle
        target: String,
    },
    /// Inspect or adjust system power profile
    Profile {
        /// Target profile ('balanced', 'performance', 'power-saver', 'get')
        action: Option<String>,
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
    /// Control audio sink volume ('up', 'down', 'mute')
    Volume {
        action: String,
        step: Option<f64>,
    },
    /// Control display brightness ('up', 'down')
    Brightness {
        action: String,
        step: Option<u32>,
    },
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
    /// Toggle Caffeine idle inhibitor
    Caffeine,
    /// Verify system runtime and compositor dependencies
    Deps,
    /// Perform self-update check and upgrade
    Update,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Commands::Start { legacy } => {
            if legacy {
                println!("Starting legacy Python Agility Shell stack...");
            } else {
                println!("Starting Agility Shell Next-Gen daemon (agilityd)...");
            }
        }
        Commands::Stop => println!("Stopping Agility Shell..."),
        Commands::Restart => println!("Restarting Agility Shell..."),
        Commands::Status => println!("Inspecting Agility Shell status..."),
        Commands::Lock => println!("Requesting session lock..."),
        Commands::Toggle { target } => println!("Toggling surface: {target}"),
        Commands::Profile { action } => println!("Power profile: {:?}", action),
        Commands::Bar { args } => println!("Bar command args: {:?}", args),
        Commands::Suits { args } => println!("Suits command args: {:?}", args),
        Commands::Volume { action, step } => println!("Volume: {action} (step: {step:?})"),
        Commands::Brightness { action, step } => println!("Brightness: {action} (step: {step:?})"),
        Commands::Screenshot { mode } => println!("Capturing screenshot ({mode})..."),
        Commands::Record { action, with_audio } => {
            println!("Recording: {action} (audio: {with_audio})")
        }
        Commands::Caffeine => println!("Toggling caffeine idle inhibitor..."),
        Commands::Deps => println!("Checking system dependencies for Agility Shell..."),
        Commands::Update => println!("Checking for Agility Shell updates..."),
    }

    Ok(())
}
