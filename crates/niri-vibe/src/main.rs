//! niri-vibe: Production-Ready Lumn-Style Ambient Edge Glow for Niri & Wayland
//! High-performance Rust binary using Smithay Client Toolkit, WGPU, PipeWire, and RustFFT.

pub mod audio;
pub mod config;
pub mod lock;
pub mod mpris;
pub mod render;
pub mod wayland;

use anyhow::{Context, Result};
use audio::AudioEngine;
use clap::Parser;
use config::{parse_hex_color, Config};
use lock::LockListener;
use mpris::MprisManager;
use render::RenderContext;
use smithay_client_toolkit::{
    compositor::CompositorState, output::OutputState, registry::RegistryState,
    shell::wlr_layer::LayerShell,
};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tracing::info;

use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};
use wayland_client::{globals::registry_queue_init, Connection};

#[derive(Parser, Debug)]
#[command(
    name = "niri-vibe",
    author = "TattvaOrg",
    version = "0.1.0",
    about = "Production-ready Lumn ambient edge glow effect for Niri and Wayland"
)]
struct Cli {
    /// Path to custom configuration file
    #[arg(short, long)]
    config: Option<PathBuf>,

    /// Override edge glow intensity (0.0 to 1.0)
    #[arg(long)]
    intensity: Option<f32>,

    /// Override edge glow thickness in pixels
    #[arg(long)]
    thickness: Option<u32>,

    /// Override FPS cap
    #[arg(long)]
    fps: Option<u32>,

    /// Override solid accent color (e.g. #FF3B30)
    #[arg(long)]
    solid_color: Option<String>,
}

#[tokio::main]
async fn main() -> Result<()> {
    let cli = Cli::parse();

    // Initialize structured logging with RUST_LOG filter support
    let default_filter = "niri_vibe=info,warn,error";
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| default_filter.into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!(
        "niri-vibe v{} [pid: {}] initializing...",
        env!("CARGO_PKG_VERSION"),
        std::process::id()
    );

    // 1. Load or initialize configuration
    let mut config = Config::load_or_create(cli.config.as_deref())?;
    if let Some(intensity) = cli.intensity {
        config.glow.intensity = intensity.clamp(0.0, 1.0);
    }
    if let Some(thickness) = cli.thickness {
        config.glow.thickness_px = thickness;
    }
    if let Some(fps) = cli.fps {
        config.general.fps_cap = fps.max(15);
    }
    if let Some(ref color) = cli.solid_color {
        config.glow.solid_color = color.clone();
        config.glow.color_mode = "solid".to_string();
    }

    let solid_color_rgba = parse_hex_color(&config.glow.solid_color);

    // 2. Initialize Audio Engine (PipeWire capture + FFT)
    let audio_engine = Arc::new(AudioEngine::new());
    audio_engine.start(config.glow.idle_breathing);

    // 3. Initialize MPRIS Album Art Watcher & Palette Extractor
    let mpris_manager = Arc::new(MprisManager::new(solid_color_rgba, &config.glow.color_mode));
    mpris_manager.start(config.glow.color_mode.clone(), solid_color_rgba);

    // 4. Initialize Session Lock Listener
    let (lock_listener, is_locked) = LockListener::new();
    lock_listener.start();

    // 5. Connect to Wayland compositor
    let wayland_conn = Connection::connect_to_env()
        .context("Failed to connect to Wayland compositor. Is WAYLAND_DISPLAY set?")?;
    let (globals, mut event_queue) = registry_queue_init(&wayland_conn)
        .context("Failed to initialize Wayland registry queue")?;
    let qh = event_queue.handle();

    // 6. Bind core SCTK protocols
    let compositor_state = CompositorState::bind(&globals, &qh)
        .context("Compositor does not implement wl_compositor")?;
    let layer_shell = LayerShell::bind(&globals, &qh)
        .context("Compositor does not implement zwlr_layer_shell_v1. Is your compositor Niri or wlroots-compatible?")?;
    let output_state = OutputState::new(&globals, &qh);
    let registry_state = RegistryState::new(&globals);

    // 7. Initialize WGPU Render Context
    let render_context = Arc::new(RenderContext::new()?);
    let display_ptr = wayland_conn.backend().display_ptr() as *mut std::ffi::c_void;

    // 8. Create unified Wayland app state
    let mut app_state = wayland::WaylandAppState::new(
        registry_state,
        compositor_state,
        output_state,
        layer_shell,
        render_context,
        display_ptr,
        config.clone(),
        Arc::clone(&audio_engine),
        Arc::clone(&mpris_manager),
        is_locked,
    );

    // Set up graceful shutdown signal handler (SIGINT / SIGTERM)
    let shutdown_signal = Arc::new(AtomicBool::new(false));
    let sig_clone = Arc::clone(&shutdown_signal);
    tokio::spawn(async move {
        let _ = tokio::signal::ctrl_c().await;
        info!("Received shutdown signal (Ctrl+C). Terminating niri-vibe gracefully...");
        sig_clone.store(true, Ordering::SeqCst);
    });

    info!(
        "niri-vibe successfully initialized. Starting render & event loop at {} FPS cap...",
        config.general.fps_cap
    );

    let frame_duration = Duration::from_secs_f32(1.0 / config.general.fps_cap as f32);
    let mut last_frame = Instant::now();

    // 9. Main Wayland and Render Loop
    while !shutdown_signal.load(Ordering::Relaxed) && !app_state.exit {
        // Dispatch pending Wayland protocol events without blocking indefinitely
        event_queue
            .dispatch_pending(&mut app_state)
            .context("Error dispatching Wayland event queue")?;

        // Render ambient edge glow frame across all connected outputs
        app_state.render_frame();

        // Throttle to configured FPS cap to maintain <5% CPU usage
        let elapsed = last_frame.elapsed();
        if elapsed < frame_duration {
            std::thread::sleep(frame_duration - elapsed);
        }
        last_frame = Instant::now();

        // Flush outgoing Wayland requests
        let _ = wayland_conn.flush();
    }

    // Clean teardown
    audio_engine.stop();
    mpris_manager.stop();
    info!("niri-vibe terminated cleanly.");

    Ok(())
}
