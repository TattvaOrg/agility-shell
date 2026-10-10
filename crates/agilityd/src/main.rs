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

    // Discover compositor (Niri or Mock fallback)
    let niri_sock = modules::compositor::find_niri_socket();
    let compositor: Arc<dyn modules::compositor::Compositor> = if let Some(ref sock) = niri_sock {
        info!("Discovered active Niri socket: {:?}", sock);
        Arc::new(modules::compositor::NiriCompositor::new(sock.clone()))
    } else {
        warn!("No active Niri socket discovered; initializing mock compositor backend");
        Arc::new(modules::compositor::MockCompositor::new())
    };

    // Initialize Workspaces D-Bus service
    let workspaces_service =
        modules::compositor::WorkspacesService::new(Arc::clone(&compositor)).await?;

    // Initialize Hardware & System Telemetry services
    let hardware_service = modules::telemetry::HardwareService::new();
    let system_service = modules::system::SystemService::new();

    // Initialize Audio & Media services
    let audio_service = modules::audio::AudioService::new();
    let media_service = modules::audio::MediaService::new();

    // Initialize Connectivity service (Network & Bluetooth)
    let connectivity_service = modules::connectivity::ConnectivityService::new();

    // Initialize Launcher service (Application Indexer & Fuzzy Search)
    let launcher_service = modules::launcher::LauncherService::new();

    // Initialize Suits service (Desktop Suites & Settings Engine)
    let suits_service =
        modules::suits::SuitsService::new(state.config_dir.clone(), state.cache_dir.clone());

    // Initialize Theme service (Dynamic Theming & XDG Portal Backend)
    let theme_service =
        modules::theme::ThemeService::new(state.config_dir.clone(), state.cache_dir.clone());

    // Initialize Notifications service (Freedesktop Notification Server & Persistent Store)
    let notifications_service = modules::notifications::NotificationService::new(
        state.config_dir.clone(),
        state.cache_dir.clone(),
    );

    // Initialize Clipboard service (Ring buffer & wl-copy/cliphist integration)
    let clipboard_service = modules::clipboard::ClipboardService::new(
        state.cache_dir.clone(),
        modules::clipboard::MAX_CLIPBOARD_ITEMS,
    );

    // Initialize Power service (Caffeine inhibitor, power profiles, night light & idle monitoring)
    let power_service =
        modules::power::PowerService::new(state.config_dir.clone(), state.cache_dir.clone());

    // Initialize Weather service (Open-Meteo & IP Geolocation background fetcher)
    let weather_service = modules::weather::WeatherService::new(state.cache_dir.clone());

    // Initialize MediaCapture service (Screenshots via grim/slurp & recordings via wl-screenrec/wf-recorder)
    let media_capture_service = modules::media_capture::MediaCaptureService::new(None, None);

    // Initialize System Tray Host (StatusNotifierWatcher)
    let tray_service = modules::tray::TrayService::new();

    // Initialize Sound effects dispatcher (pw-play / paplay)
    let sounds_service = modules::sounds::SoundService::new(None);

    // Initialize Lock service (Secure Linux PAM Lockscreen Worker)
    let lock_service = Arc::new(modules::lock::LockService::new(None));

    // Self-test execution mode (--test)
    if args.test {
        info!("Running agilityd self-test verification...");
        let dbus_conn = dbus::establish_dbus_connection(
            Arc::clone(&state),
            Arc::clone(&workspaces_service),
            Arc::clone(&hardware_service),
            Arc::clone(&system_service),
            Arc::clone(&audio_service),
            Arc::clone(&media_service),
            Arc::clone(&connectivity_service),
            Arc::clone(&launcher_service),
            Arc::clone(&suits_service),
            Arc::clone(&theme_service),
            Arc::clone(&notifications_service),
            Arc::clone(&clipboard_service),
            Arc::clone(&power_service),
            Arc::clone(&weather_service),
            Arc::clone(&media_capture_service),
            Arc::clone(&tray_service),
            Arc::clone(&sounds_service),
            Arc::clone(&lock_service),
        )
        .await?;
        if dbus_conn.is_some() {
            info!("D-Bus session service registration: OK");
        } else {
            warn!("D-Bus session bus unavailable in test environment (allowed for mock/headless tests)");
        }

        let status = state.status();
        info!(
            "State validation: OK [uptime: {}s, compositor: {}]",
            status.uptime_secs,
            compositor.name()
        );
        println!("Agility Shell Daemon self-test PASSED.");
        return Ok(());
    }

    info!("Target compositor: {} (Wayland)", compositor.name());

    // Start background telemetry pollers
    hardware_service.start_polling(
        std::time::Duration::from_secs(1),
        std::time::Duration::from_secs(10),
        state.subscribe_shutdown(),
    );
    system_service.start_polling(
        std::time::Duration::from_secs(3),
        state.subscribe_shutdown(),
    );

    // Start audio & media pollers
    audio_service.start_polling(
        std::time::Duration::from_millis(500),
        state.subscribe_shutdown(),
    );
    media_service.start_polling(
        std::time::Duration::from_secs(1),
        state.subscribe_shutdown(),
    );

    // Start connectivity poller
    connectivity_service.start_polling(
        std::time::Duration::from_secs(3),
        state.subscribe_shutdown(),
    );

    // Start clipboard event listener (wl-paste --watch cliphist store)
    clipboard_service.start_watcher(state.subscribe_shutdown());

    // Start power & idle watcher (swayidle and battery monitoring)
    power_service.start_watcher(state.subscribe_shutdown());

    // Start weather poller (10-minute refresh interval)
    weather_service.start_poller(
        std::time::Duration::from_secs(600),
        state.subscribe_shutdown(),
    );

    // Start media capture watcher (clean recording finalization on shutdown)
    media_capture_service.start_watcher(state.subscribe_shutdown());

    // Start asynchronous event stream if Niri is active
    if niri_sock.is_some() {
        workspaces_service.start_event_stream(niri_sock, state.subscribe_shutdown());
    }

    // Establish D-Bus connection and register interfaces
    let _conn = dbus::establish_dbus_connection(
        Arc::clone(&state),
        Arc::clone(&workspaces_service),
        Arc::clone(&hardware_service),
        Arc::clone(&system_service),
        Arc::clone(&audio_service),
        Arc::clone(&media_service),
        Arc::clone(&connectivity_service),
        Arc::clone(&launcher_service),
        Arc::clone(&suits_service),
        Arc::clone(&theme_service),
        Arc::clone(&notifications_service),
        Arc::clone(&clipboard_service),
        Arc::clone(&power_service),
        Arc::clone(&weather_service),
        Arc::clone(&media_capture_service),
        Arc::clone(&tray_service),
        Arc::clone(&sounds_service),
        Arc::clone(&lock_service),
    )
    .await?;

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
