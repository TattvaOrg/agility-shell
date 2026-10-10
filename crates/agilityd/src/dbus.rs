//! D-Bus session bus service registration and root `org.agility.Daemon` interface.

use crate::state::DaemonState;
use agility_common::{paths, DBUS_NAME};
use anyhow::Result;
use std::sync::Arc;
use tracing::{info, warn};
use zbus::connection::Builder;
use zbus::Connection;

/// Root daemon D-Bus interface exposed on `/org/agility/Daemon`.
pub struct DaemonInterface {
    state: Arc<DaemonState>,
}

impl DaemonInterface {
    pub fn new(state: Arc<DaemonState>) -> Self {
        Self { state }
    }
}

#[zbus::interface(name = "org.agility.Daemon")]
impl DaemonInterface {
    /// Ping daemon to check responsiveness.
    async fn ping(&self) -> String {
        "pong".to_string()
    }

    /// Retrieve agilityd version string.
    async fn get_version(&self) -> String {
        env!("CARGO_PKG_VERSION").to_string()
    }

    /// Retrieve runtime status serialized as JSON.
    async fn get_status(&self) -> String {
        serde_json::to_string(&self.state.status()).unwrap_or_default()
    }

    /// Retrieve active master config JSON.
    async fn get_config(&self) -> String {
        self.state.get_config_json()
    }

    /// Trigger configuration reload from disk.
    async fn reload(&self) -> zbus::fdo::Result<()> {
        self.state.trigger_reload();
        Ok(())
    }

    /// Request graceful shutdown of agilityd.
    async fn quit(&self) -> zbus::fdo::Result<()> {
        self.state.trigger_shutdown();
        Ok(())
    }
}

/// Establish D-Bus connection on session bus, request `org.agility.Daemon` name,
/// and register the root interface.
pub async fn establish_dbus_connection(
    state: Arc<DaemonState>,
) -> Result<Option<Connection>> {
    let daemon_iface = DaemonInterface::new(Arc::clone(&state));

    let builder_res = Builder::session();
    let builder = match builder_res {
        Ok(b) => b,
        Err(e) => {
            warn!("Failed to initiate D-Bus session connection: {e:#}");
            return Ok(None);
        }
    };

    match builder
        .name(DBUS_NAME)?
        .serve_at(paths::DAEMON, daemon_iface)?
        .build()
        .await
    {
        Ok(conn) => {
            info!(
                "Successfully registered D-Bus service '{}' at '{}'",
                DBUS_NAME,
                paths::DAEMON
            );
            Ok(Some(conn))
        }
        Err(e) => {
            warn!("D-Bus session bus unavailable or name acquisition failed: {e:#}");
            Ok(None)
        }
    }
}
