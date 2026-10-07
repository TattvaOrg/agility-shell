//! Agility Shell Daemon (`agilityd`)
//! High-performance Rust backend for Agility Shell on Wayland.

pub mod modules;

use anyhow::Result;
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize structured logging with RUST_LOG filter support
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "agilityd=info,warn".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("Starting Agility Shell Daemon (agilityd) v{}", env!("CARGO_PKG_VERSION"));
    info!("Target compositor: Niri (Wayland)");

    // Graceful shutdown listener
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            info!("Received SIGINT (Ctrl+C). Shutting down agilityd gracefully...");
        }
    }

    info!("Agility Shell Daemon terminated.");
    Ok(())
}
