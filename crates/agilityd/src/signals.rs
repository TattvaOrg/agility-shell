//! Unix signal handling (`SIGINT`, `SIGTERM`, `SIGHUP`) for `agilityd`.

use crate::state::DaemonState;
use anyhow::Result;
use std::sync::Arc;
use tokio::signal::unix::{signal, SignalKind};
use tracing::info;

/// Run background signal monitor listening for SIGINT, SIGTERM, and SIGHUP.
pub async fn run_signal_handler(state: Arc<DaemonState>) -> Result<()> {
    let mut sigint = signal(SignalKind::interrupt())?;
    let mut sigterm = signal(SignalKind::terminate())?;
    let mut sighup = signal(SignalKind::hangup())?;

    loop {
        tokio::select! {
            _ = sigint.recv() => {
                info!("Received SIGINT. Triggering graceful shutdown...");
                state.trigger_shutdown();
                break;
            }
            _ = sigterm.recv() => {
                info!("Received SIGTERM. Triggering graceful shutdown...");
                state.trigger_shutdown();
                break;
            }
            _ = sighup.recv() => {
                info!("Received SIGHUP. Triggering configuration reload...");
                state.trigger_reload();
            }
        }
    }

    Ok(())
}
