use crate::mpris::color_extractor::{
    extract_palette_from_image, ColorRgba, DualPalette, PaletteAnimator,
};
use mpris::{PlaybackStatus, PlayerFinder};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use tracing::{debug, info, warn};


pub struct MprisManager {
    animator: Arc<Mutex<PaletteAnimator>>,
    is_playing: Arc<AtomicBool>,
    running: Arc<AtomicBool>,
}

impl MprisManager {
    pub fn new(solid_color: [f32; 4], mode: &str) -> Self {
        let initial_palette = if mode == "solid" {
            let primary = ColorRgba::new(solid_color[0], solid_color[1], solid_color[2], solid_color[3]);
            let (h, s, l) = primary.to_hsl();
            let secondary = ColorRgba::from_hsl((h + 0.42) % 1.0, s, l);
            DualPalette { primary, secondary }
        } else {
            DualPalette::default()
        };

        Self {
            animator: Arc::new(Mutex::new(PaletteAnimator::new(initial_palette))),
            is_playing: Arc::new(AtomicBool::new(false)),
            running: Arc::new(AtomicBool::new(true)),
        }
    }

    pub fn current_palette(&self) -> DualPalette {
        let mut anim = self.animator.lock().unwrap();
        anim.update()
    }

    pub fn is_playing(&self) -> bool {
        self.is_playing.load(Ordering::Relaxed)
    }

    pub fn start(&self, color_mode: String, solid_color: [f32; 4]) {
        let animator = Arc::clone(&self.animator);
        let is_playing = Arc::clone(&self.is_playing);
        let running = Arc::clone(&self.running);

        thread::spawn(move || {
            info!("Starting MPRIS metadata & album art color watcher...");

            if color_mode == "solid" {
                info!("Color mode is 'solid'; using configured solid accent color.");
                let primary = ColorRgba::new(solid_color[0], solid_color[1], solid_color[2], solid_color[3]);
                let (h, s, l) = primary.to_hsl();
                let secondary = ColorRgba::from_hsl((h + 0.42) % 1.0, s, l);
                let target = DualPalette { primary, secondary };
                animator.lock().unwrap().set_target(target);
                return;
            }

            let player_finder = match PlayerFinder::new() {
                Ok(finder) => finder,
                Err(e) => {
                    warn!("MPRIS D-Bus interface unavailable ({e:#}). Keeping default palette.");
                    return;
                }
            };

            let mut last_art_url = String::new();

            while running.load(Ordering::Relaxed) {
                match player_finder.find_active() {
                    Ok(player) => {
                        let playing = player
                            .get_playback_status()
                            .map(|s| s == PlaybackStatus::Playing)
                            .unwrap_or(false);
                        is_playing.store(playing, Ordering::Relaxed);

                        if let Ok(metadata) = player.get_metadata() {
                            if let Some(art_url) = metadata.art_url() {
                                if art_url != last_art_url {
                                    last_art_url = art_url.to_string();
                                    debug!("Detected new album art URL: {}", art_url);

                                    let local_path: Option<PathBuf> = if let Some(stripped) = art_url.strip_prefix("file://") {
                                        Some(PathBuf::from(stripped))
                                    } else if Path::new(art_url).exists() {
                                        Some(PathBuf::from(art_url))
                                    } else {
                                        None
                                    };

                                    if let Some(ref path) = local_path {
                                        if let Some(palette) = extract_palette_from_image(path) {
                                            info!(
                                                "Extracted new album art palette: primary #{:02x}{:02x}{:02x}, secondary #{:02x}{:02x}{:02x}",
                                                (palette.primary.r * 255.0) as u8,
                                                (palette.primary.g * 255.0) as u8,
                                                (palette.primary.b * 255.0) as u8,
                                                (palette.secondary.r * 255.0) as u8,
                                                (palette.secondary.g * 255.0) as u8,
                                                (palette.secondary.b * 255.0) as u8,
                                            );
                                            animator.lock().unwrap().set_target(palette);
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Err(_) => {
                        is_playing.store(false, Ordering::Relaxed);
                    }
                }

                thread::sleep(Duration::from_millis(600));
            }
        });
    }

    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
    }
}
