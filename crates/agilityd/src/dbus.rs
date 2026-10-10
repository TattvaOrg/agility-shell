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
/// and register root interface and subsystem interfaces.
#[allow(clippy::too_many_arguments)]
pub async fn establish_dbus_connection(
    state: Arc<DaemonState>,
    workspaces_service: Arc<crate::modules::compositor::WorkspacesService>,
    hardware_service: Arc<crate::modules::telemetry::HardwareService>,
    system_service: Arc<crate::modules::system::SystemService>,
    audio_service: Arc<crate::modules::audio::AudioService>,
    media_service: Arc<crate::modules::audio::MediaService>,
    connectivity_service: Arc<crate::modules::connectivity::ConnectivityService>,
    launcher_service: Arc<crate::modules::launcher::LauncherService>,
    suits_service: Arc<crate::modules::suits::SuitsService>,
    theme_service: Arc<crate::modules::theme::ThemeService>,
    notifications_service: Arc<crate::modules::notifications::NotificationService>,
    clipboard_service: Arc<crate::modules::clipboard::ClipboardService>,
) -> Result<Option<Connection>> {
    let daemon_iface = DaemonInterface::new(Arc::clone(&state));
    let workspaces_iface = (*workspaces_service).clone();
    let hardware_iface = (*hardware_service).clone();
    let system_iface = (*system_service).clone();
    let audio_iface = (*audio_service).clone();
    let media_iface = (*media_service).clone();
    let connectivity_iface = (*connectivity_service).clone();
    let launcher_iface = (*launcher_service).clone();
    let suits_iface = crate::modules::suits::SuitsInterface::new(Arc::clone(&suits_service));
    let theme_iface = crate::modules::theme::ThemeInterface::new(Arc::clone(&theme_service));
    let portal_iface =
        crate::modules::theme::PortalSettingsInterface::new(Arc::clone(&theme_service));
    let notifications_iface = crate::modules::notifications::NotificationsInterface::new(
        Arc::clone(&notifications_service),
    );
    let notif_drawer_iface = crate::modules::notifications::NotificationsInterface::new(
        Arc::clone(&notifications_service),
    );
    let clipboard_iface =
        crate::modules::clipboard::ClipboardInterface::new(Arc::clone(&clipboard_service));

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
        .serve_at(paths::WORKSPACES, workspaces_iface)?
        .serve_at(paths::HARDWARE, hardware_iface)?
        .serve_at(paths::SYSTEM, system_iface)?
        .serve_at(paths::AUDIO, audio_iface)?
        .serve_at(paths::MEDIA, media_iface)?
        .serve_at(paths::CONNECTIVITY, connectivity_iface)?
        .serve_at(paths::LAUNCHER, launcher_iface)?
        .serve_at(paths::SUITS, suits_iface)?
        .serve_at(paths::THEME, theme_iface)?
        .serve_at("/org/freedesktop/portal/desktop", portal_iface)?
        .serve_at(paths::NOTIFICATIONS, notifications_iface)?
        .serve_at("/org/agility/Daemon/Notifications", notif_drawer_iface)?
        .serve_at(paths::CLIPBOARD, clipboard_iface)?
        .build()
        .await
    {
        Ok(conn) => {
            // Attempt to claim the well-known Freedesktop Notifications bus name
            match conn
                .request_name(agility_common::DBUS_NOTIFICATIONS_NAME)
                .await
            {
                Ok(_) => info!(
                    "Successfully acquired D-Bus name '{}'",
                    agility_common::DBUS_NOTIFICATIONS_NAME
                ),
                Err(e) => warn!(
                    "Could not claim '{}': {e:#} (another notification daemon may be active)",
                    agility_common::DBUS_NOTIFICATIONS_NAME
                ),
            }

            info!(
                "Successfully registered D-Bus service '{}' with interfaces at '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', '{}', and '/org/freedesktop/portal/desktop'",
                DBUS_NAME,
                paths::DAEMON,
                paths::WORKSPACES,
                paths::HARDWARE,
                paths::SYSTEM,
                paths::AUDIO,
                paths::MEDIA,
                paths::CONNECTIVITY,
                paths::LAUNCHER,
                paths::SUITS,
                paths::THEME,
                paths::NOTIFICATIONS,
                paths::CLIPBOARD
            );
            Ok(Some(conn))
        }
        Err(e) => {
            warn!("D-Bus session bus unavailable or name acquisition failed: {e:#}");
            Ok(None)
        }
    }
}
