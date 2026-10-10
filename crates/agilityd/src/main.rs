//! Agility Shell Daemon (`agilityd`)
//! High-performance Rust backend for Agility Shell on Wayland.

pub mod cli;
pub mod dbus;
pub mod modules;
pub mod signals;
pub mod state;

use anyhow::Result;
use clap::Parser;
use std::sync::Arc;
use tracing::{info, warn};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> Result<()> {
    let args = cli::Cli::parse();

    // Initialize structured logging with RUST_LOG filter support
    let default_filter = if args.test {
        "agilityd=info,warn"
    } else {
        "agilityd=info,warn,error"
    };

    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| default_filter.into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!(
        "Agility Shell Daemon (agilityd) v{} [pid: {}]",
        env!("CARGO_PKG_VERSION"),
        std::process::id()
    );

    // Initialize State Manager
    let state = state::DaemonState::new(args.config_dir, args.cache_dir);

    // Seed and validate configuration / cache directories
    state.seed_and_validate_directories()?;

    // Self-test execution mode (--test)
    if args.test {
        info!("Running agilityd self-test verification...");
        let dbus_conn = dbus::establish_dbus_connection(Arc::clone(&state)).await?;
        if dbus_conn.is_some() {
            info!("D-Bus session service registration: OK");
        } else {
            warn!("D-Bus session bus unavailable in test environment (allowed for mock/headless tests)");
        }

        let status = state.status();
        info!("State validation: OK [uptime: {}s, compositor: {}]", status.uptime_secs, status.compositor);
        println!("Agility Shell Daemon self-test PASSED.");
        return Ok(());
    }

    info!("Target compositor: Niri (Wayland)");

    // Establish D-Bus connection and register org.agility.Daemon
    let _conn = dbus::establish_dbus_connection(Arc::clone(&state)).await?;

    // Subscribe to daemon shutdown broadcast
    let mut shutdown_rx = state.subscribe_shutdown();

    // Spawn Unix signal handler (SIGINT, SIGTERM, SIGHUP)
    let signal_state = Arc::clone(&state);
    tokio::spawn(async move {
        if let Err(e) = signals::run_signal_handler(signal_state).await {
            warn!("Signal handler error: {e:#}");
        }
    });

    info!("Agility Shell Daemon initialized and listening for events.");

    // Wait until shutdown is triggered
    let _ = shutdown_rx.recv().await;

    info!("Graceful shutdown initiated. Terminating agilityd...");
    Ok(())
}
