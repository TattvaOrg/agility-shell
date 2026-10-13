//! Command-line argument parsing for `agilityd`.

use clap::Parser;
use std::path::PathBuf;

#[derive(Parser, Debug, Clone)]
#[command(
    name = "agilityd",
    author = "TattvaOrg",
    version,
    about = "Agility Shell Core Daemon — high-performance Wayland shell backend"
)]
pub struct Cli {
    /// Run daemon in background mode
    #[arg(short = 'd', long)]
    pub daemon: bool,

    /// Run daemon in foreground mode (default if neither flag is set)
    #[arg(short = 'f', long)]
    pub foreground: bool,

    /// Run self-test and configuration validation, then exit
    #[arg(short = 't', long)]
    pub test: bool,

    /// Custom configuration directory (overrides default ~/.config/agility-shell)
    #[arg(long)]
    pub config_dir: Option<PathBuf>,

    /// Custom cache directory (overrides default ~/.cache/agility-shell)
    #[arg(long)]
    pub cache_dir: Option<PathBuf>,
}
