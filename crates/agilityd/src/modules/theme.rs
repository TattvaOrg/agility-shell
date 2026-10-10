//! Dynamic Theming Engine (Matugen + Material You + Templates).
//! Implements `org.agility.Daemon.Theme` and `org.freedesktop.impl.portal.Settings` D-Bus interfaces.

use agility_common::ThemeTokens;
use anyhow::{Context, Result};
use image::{imageops, ImageFormat, Rgba};
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Arc, RwLock};
use std::time::Instant;
use tracing::{error, info, warn};
use zbus::object_server::SignalEmitter;
use zbus::zvariant::OwnedValue;

/// Default Gaussian blur radius for the lockscreen & glass backgrounds.
pub const DEFAULT_BLUR_RADIUS: f32 = 16.0;

/// Target dimensions for fast blurred wallpaper generation.
pub const BLUR_TARGET_WIDTH: u32 = 960;
pub const BLUR_TARGET_HEIGHT: u32 = 540;

/// Fallback preset names supported by agilityd.
pub const PRESETS: &[&str] = &["Dark", "Light", "TokyoNight", "Catppuccin", "Gruvbox"];

/// Dynamic theming and wallpaper orchestration service.
pub struct ThemeService {
    config_dir: PathBuf,
    cache_dir: PathBuf,
    tokens: Arc<RwLock<ThemeTokens>>,
    active_wallpaper: Arc<RwLock<String>>,
    active_preset: Arc<RwLock<Option<String>>>,
}

impl ThemeService {
    /// Initialize theme service with cached tokens or fallback presets.
    pub fn new(config_dir: PathBuf, cache_dir: PathBuf) -> Arc<Self> {
        let theme_cache_file = cache_dir.join("theme.json");
        let wallpaper_cache_file = cache_dir.join("wallpaper");

        let mut initial_tokens = ThemeTokens::dark();
        if theme_cache_file.exists() {
            if let Ok(data) = fs::read_to_string(&theme_cache_file) {
                if let Ok(parsed) = serde_json::from_str::<ThemeTokens>(&data) {
                    initial_tokens = parsed;
                }
            }
        }

        let mut initial_wall = String::new();
        if wallpaper_cache_file.exists() {
            if let Ok(wall) = fs::read_to_string(&wallpaper_cache_file) {
                let trimmed = wall.trim();
                if !trimmed.is_empty() && Path::new(trimmed).exists() {
                    initial_wall = trimmed.to_string();
                }
            }
        }

        if !initial_wall.is_empty() && initial_tokens.active_wallpaper.is_empty() {
            initial_tokens.active_wallpaper = initial_wall.clone();
        }

        let active_preset = if !initial_tokens.active_preset.is_empty() {
            Some(initial_tokens.active_preset.clone())
        } else {
            Some("Dark".to_string())
        };

        let service = Arc::new(Self {
            config_dir,
            cache_dir,
            tokens: Arc::new(RwLock::new(initial_tokens)),
            active_wallpaper: Arc::new(RwLock::new(initial_wall)),
            active_preset: Arc::new(RwLock::new(active_preset)),
        });

        // Ensure cache directory and templates exist
        let _ = fs::create_dir_all(service.cache_dir.join("templates"));

        service
    }

    /// Read currently cached theme tokens snapshot.
    pub fn tokens(&self) -> ThemeTokens {
        self.tokens.read().unwrap().clone()
    }

    /// Retrieve JSON serialized theme tokens.
    pub fn get_theme_json(&self) -> String {
        serde_json::to_string(&self.tokens()).unwrap_or_default()
    }

    /// Check if dark mode is currently active.
    pub fn is_dark(&self) -> bool {
        self.tokens.read().unwrap().is_dark
    }

    /// Get current active preset name if set.
    pub fn active_preset(&self) -> String {
        self.active_preset
            .read()
            .unwrap()
            .clone()
            .unwrap_or_else(|| "Custom".to_string())
    }

    /// Get path to active wallpaper.
    pub fn active_wallpaper(&self) -> String {
        self.active_wallpaper.read().unwrap().clone()
    }

    /// Switch dark mode on or off. Re-extracts palette or swaps preset.
    pub fn set_dark_mode(&self, is_dark: bool) -> Result<ThemeTokens> {
        let wall = self.active_wallpaper();
        let preset_opt = self.active_preset.read().unwrap().clone();

        let mut new_tokens = if !wall.is_empty() && Path::new(&wall).exists() {
            // Re-extract palette from wallpaper in requested dark/light mode
            self.extract_palette(Path::new(&wall), is_dark)
                .unwrap_or_else(|_| {
                    if is_dark {
                        ThemeTokens::dark()
                    } else {
                        ThemeTokens::light()
                    }
                })
        } else if let Some(ref preset) = preset_opt {
            let target_preset = match preset.to_lowercase().as_str() {
                "light" if is_dark => "Dark",
                "dark" if !is_dark => "Light",
                _ => preset.as_str(),
            };
            ThemeTokens::from_preset(target_preset).unwrap_or_else(|| {
                if is_dark {
                    ThemeTokens::dark()
                } else {
                    ThemeTokens::light()
                }
            })
        } else if is_dark {
            ThemeTokens::dark()
        } else {
            ThemeTokens::light()
        };

        new_tokens.is_dark = is_dark;
        new_tokens.active_wallpaper = wall;

        self.apply_new_tokens(new_tokens)
    }

    /// Toggle between dark and light modes.
    pub fn toggle_dark_mode(&self) -> Result<ThemeTokens> {
        let current_dark = self.is_dark();
        self.set_dark_mode(!current_dark)
    }

    /// Switch theme to one of the static presets (Dark, Light, TokyoNight, Catppuccin, Gruvbox).
    pub fn set_preset(&self, preset_name: &str) -> Result<ThemeTokens> {
        let tokens = ThemeTokens::from_preset(preset_name)
            .with_context(|| format!("Unknown preset '{preset_name}'. Available: {:?}", PRESETS))?;

        *self.active_preset.write().unwrap() = Some(preset_name.to_string());
        self.apply_new_tokens(tokens)
    }

    /// Set wallpaper, execute transitions, blur, extract palette, and render templates.
    pub fn set_wallpaper(
        &self,
        path: &str,
        transition_type: Option<&str>,
        duration: Option<f64>,
    ) -> Result<ThemeTokens> {
        let wall_path = PathBuf::from(path);
        if !wall_path.exists() {
            anyhow::bail!("Wallpaper file not found: {:?}", wall_path);
        }

        let abs_path = wall_path.canonicalize().unwrap_or(wall_path);
        let abs_str = abs_path.to_string_lossy().to_string();

        *self.active_wallpaper.write().unwrap() = abs_str.clone();
        *self.active_preset.write().unwrap() = None;

        // Persist wallpaper path cache
        let wall_cache = self.cache_dir.join("wallpaper");
        let _ = fs::write(&wall_cache, &abs_str);

        // 1. Invoke wallpaper setter (awww / swww)
        let t_type = transition_type.unwrap_or("grow");
        let t_dur = duration.unwrap_or(0.35);
        Self::dispatch_wallpaper_backend(&abs_str, t_type, t_dur);

        // 2. Fast blurred wallpaper generation (<15ms)
        let blurred_cache = self.cache_dir.join("wallpaper_blurred");
        if let Err(e) =
            Self::generate_blurred_wallpaper(&abs_path, &blurred_cache, DEFAULT_BLUR_RADIUS)
        {
            warn!("Failed to generate blurred wallpaper cache: {e:#}");
        }

        // 3. Extract dynamic color palette
        let is_dark = self.is_dark();
        let mut tokens = self
            .extract_palette(&abs_path, is_dark)
            .unwrap_or_else(|e| {
                warn!("Color extraction failed ({e:#}), falling back to default theme");
                if is_dark {
                    ThemeTokens::dark()
                } else {
                    ThemeTokens::light()
                }
            });

        tokens.active_wallpaper = abs_str;
        tokens.is_dark = is_dark;
        tokens.active_preset = "Wallpaper".to_string();

        self.apply_new_tokens(tokens)
    }

    /// Fast Rust-native blurred wallpaper generator using `image` crate.
    /// Resizes to 960x540 and applies Gaussian blur in < 15ms.
    pub fn generate_blurred_wallpaper(
        source_path: &Path,
        dest_path: &Path,
        blur_radius: f32,
    ) -> Result<()> {
        let start = Instant::now();
        let img = image::open(source_path)
            .with_context(|| format!("Failed to read wallpaper image: {:?}", source_path))?;

        // Fast downscale thumbnail to target 16:9 dimensions after converting to RGB8 (JPEG has no alpha)
        let rgb = img.to_rgb8();
        let thumb = imageops::thumbnail(&rgb, BLUR_TARGET_WIDTH, BLUR_TARGET_HEIGHT);

        // Apply fast Gaussian blur
        let blurred = imageops::blur(&thumb, blur_radius);

        if let Some(parent) = dest_path.parent() {
            let _ = fs::create_dir_all(parent);
        }

        let tmp_dest = dest_path.with_file_name(format!(
            "blur_tmp_{}_{}.jpg",
            std::process::id(),
            start.elapsed().as_micros()
        ));

        // Save as optimized JPEG
        blurred.save_with_format(&tmp_dest, ImageFormat::Jpeg)?;
        fs::rename(&tmp_dest, dest_path)?;

        let elapsed = start.elapsed();
        info!(
            "Generated blurred wallpaper cache at {:?} in {:.2}ms",
            dest_path,
            elapsed.as_secs_f64() * 1000.0
        );
        Ok(())
    }

    /// Color extraction: Matugen CLI (primary) with pure-Rust dominant color fallback.
    pub fn extract_palette(&self, wallpaper_path: &Path, is_dark: bool) -> Result<ThemeTokens> {
        let mode = if is_dark { "dark" } else { "light" };

        // 1. Try Matugen CLI invocation
        if let Ok(tokens) = Self::extract_matugen(wallpaper_path, mode, is_dark) {
            return Ok(tokens);
        }

        // 2. Fallback to native pure-Rust dominant color extraction
        Self::extract_native_dominant(wallpaper_path, is_dark)
    }

    /// Invoke `matugen` CLI with `--source-color-index 0` and parse JSON palette.
    fn extract_matugen(wallpaper_path: &Path, mode: &str, is_dark: bool) -> Result<ThemeTokens> {
        let output = Command::new("matugen")
            .arg("image")
            .arg(wallpaper_path)
            .arg("-m")
            .arg(mode)
            .arg("-j")
            .arg("hex")
            .arg("--source-color-index")
            .arg("0")
            .arg("--dry-run")
            .output()
            .context("Failed to execute matugen binary")?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("matugen returned error: {}", stderr.trim());
        }

        let json_str = String::from_utf8_lossy(&output.stdout);
        let parsed: serde_json::Value =
            serde_json::from_str(&json_str).context("Failed to parse matugen JSON output")?;

        let colors = parsed
            .get("colors")
            .context("Missing 'colors' in matugen json")?;

        let get_color = |key: &str, fallback: &str| -> String {
            colors
                .get(key)
                .and_then(|v| {
                    v.get(mode)
                        .or_else(|| v.get("default"))
                        .and_then(|m| m.get("color"))
                        .and_then(|c| c.as_str())
                })
                .unwrap_or(fallback)
                .to_string()
        };

        let primary = get_color("primary", if is_dark { "#2a98df" } else { "#006398" });
        let secondary = get_color("secondary", if is_dark { "#8392a3" } else { "#51606f" });
        let surface = get_color("surface", if is_dark { "#181c20" } else { "#f1f4f9" });
        let background = get_color("background", if is_dark { "#0f1113" } else { "#fcfcff" });
        let surface_container = get_color(
            "surface_container",
            if is_dark { "#272a2e" } else { "#e6e8ee" },
        );
        let outline = get_color("outline", "#72787e");
        let on_primary = get_color("on_primary", "#ffffff");
        let on_surface = get_color("on_surface", if is_dark { "#e2e2e5" } else { "#1a1c1e" });
        let tertiary = get_color("tertiary", if is_dark { "#d2bfe7" } else { "#67587a" });

        let accent_colors = vec![
            primary.clone(),
            tertiary,
            secondary.clone(),
            get_color("surface_tint", &primary),
        ];

        Ok(ThemeTokens {
            is_dark,
            primary_color: primary,
            secondary_color: secondary,
            surface_color: surface,
            background_color: background,
            accent_colors,
            active_wallpaper: wallpaper_path.to_string_lossy().to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Wallpaper".to_string(),
            on_primary,
            on_surface,
            surface_container,
            outline,
        })
    }

    /// Pure-Rust dominant color extraction without external dependencies.
    pub fn extract_native_dominant(wallpaper_path: &Path, is_dark: bool) -> Result<ThemeTokens> {
        let img = image::open(wallpaper_path)?;
        let thumb = imageops::thumbnail(&img, 64, 64);

        let mut color_bins: HashMap<(u8, u8, u8), u32> = HashMap::new();
        for pixel in thumb.pixels() {
            let Rgba([r, g, b, a]) = *pixel;
            if a < 128 {
                continue;
            }
            // Quantize to 4-bit per channel
            let qr = (r >> 4) << 4;
            let qg = (g >> 4) << 4;
            let qb = (b >> 4) << 4;

            // Filter out extreme near-black or near-white from primary candidates
            let lum = (qr as f32 * 0.299 + qg as f32 * 0.587 + qb as f32 * 0.114) as u8;
            if (lum > 20 && lum < 235) || color_bins.is_empty() {
                *color_bins.entry((qr, qg, qb)).or_insert(0) += 1;
            }
        }

        let mut sorted: Vec<((u8, u8, u8), u32)> = color_bins.into_iter().collect();
        sorted.sort_by_key(|b| std::cmp::Reverse(b.1));

        let dominant = sorted
            .first()
            .map(|(rgb, _)| *rgb)
            .unwrap_or((42, 152, 223));

        let dominant_hex = format!("#{:02x}{:02x}{:02x}", dominant.0, dominant.1, dominant.2);

        let secondary_hex = sorted
            .get(1)
            .map(|(rgb, _)| format!("#{:02x}{:02x}{:02x}", rgb.0, rgb.1, rgb.2))
            .unwrap_or_else(|| {
                if is_dark {
                    "#8392a3".to_string()
                } else {
                    "#51606f".to_string()
                }
            });

        let (bg, surf, surf_c, on_p, on_s, outline) = if is_dark {
            (
                "#0f1113".to_string(),
                "#181c20".to_string(),
                "#272a2e".to_string(),
                "#ffffff".to_string(),
                "#e2e2e5".to_string(),
                "#72787e".to_string(),
            )
        } else {
            (
                "#fcfcff".to_string(),
                "#f1f4f9".to_string(),
                "#e6e8ee".to_string(),
                "#ffffff".to_string(),
                "#1a1c1e".to_string(),
                "#72787e".to_string(),
            )
        };

        let accents = vec![
            dominant_hex.clone(),
            secondary_hex.clone(),
            "#94ccff".to_string(),
            "#d2bfe7".to_string(),
        ];

        Ok(ThemeTokens {
            is_dark,
            primary_color: dominant_hex,
            secondary_color: secondary_hex,
            surface_color: surf,
            background_color: bg,
            accent_colors: accents,
            active_wallpaper: wallpaper_path.to_string_lossy().to_string(),
            border_radius: 12,
            font_family: "Inter".to_string(),
            font_mono: "JetBrains Mono".to_string(),
            active_preset: "Wallpaper".to_string(),
            on_primary: on_p,
            on_surface: on_s,
            surface_container: surf_c,
            outline,
        })
    }

    /// Shell out to `awww` or `swww` wallpaper daemons.
    fn dispatch_wallpaper_backend(path: &str, transition_type: &str, duration: f64) {
        if Command::new("which")
            .arg("awww")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            let dur_str = format!("{duration:.2}");
            let _ = Command::new("awww")
                .arg("img")
                .arg(path)
                .arg("--transition-type")
                .arg(transition_type)
                .arg("--transition-duration")
                .arg(&dur_str)
                .spawn();
            return;
        }

        if Command::new("which")
            .arg("swww")
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
        {
            let dur_str = format!("{duration:.2}");
            let _ = Command::new("swww")
                .arg("img")
                .arg(path)
                .arg("--transition-type")
                .arg(transition_type)
                .arg("--transition-duration")
                .arg(&dur_str)
                .spawn();
        }
    }

    /// Update internal state, cache on disk, generate templates, and sync portal / gsettings.
    fn apply_new_tokens(&self, tokens: ThemeTokens) -> Result<ThemeTokens> {
        *self.tokens.write().unwrap() = tokens.clone();

        // 1. Cache theme.json atomically
        let cache_file = self.cache_dir.join("theme.json");
        if let Ok(json) = serde_json::to_string_pretty(&tokens) {
            let _ = fs::write(&cache_file, json);
        }

        // 2. Render templates for terminals and Niri borders
        let _ = self.apply_templates(&tokens);

        // 3. Synchronize GSettings color scheme
        let _ = self.sync_gsettings_color_scheme(tokens.is_dark);

        // 4. Live reload supported external apps
        let _ = self.reload_apps();

        Ok(tokens)
    }

    /// Render terminal configurations (Kitty, Alacritty, Foot) and Niri borders.
    pub fn apply_templates(&self, tokens: &ThemeTokens) -> Result<()> {
        let t_dir = self.cache_dir.join("templates");
        let _ = fs::create_dir_all(&t_dir);

        let home_dir = std::env::var("HOME").unwrap_or_else(|_| "/home/cachy".to_string());
        let config_root = PathBuf::from(&home_dir).join(".config");

        let strip_hash = |hex: &str| -> String { hex.trim_start_matches('#').to_string() };

        // 1. Kitty
        let kitty_content = format!(
            "# Agility Shell Generated Theme\n\
             foreground            {on_surface}\n\
             background            {bg}\n\
             selection_foreground  {on_primary}\n\
             selection_background  {primary}\n\
             cursor                {primary}\n\
             cursor_text_color     {bg}\n\
             active_border_color   {primary}\n\
             inactive_border_color {outline}\n\
             color0                {surface}\n\
             color8                {surface_container}\n\
             color4                {primary}\n\
             color12               {primary}\n\
             color6                {secondary}\n\
             color14               {secondary}\n\
             color7                {on_surface}\n\
             color15               #ffffff\n",
            on_surface = tokens.on_surface,
            bg = tokens.background_color,
            on_primary = tokens.on_primary,
            primary = tokens.primary_color,
            outline = tokens.outline,
            surface = tokens.surface_color,
            surface_container = tokens.surface_container,
            secondary = tokens.secondary_color,
        );
        let _ = fs::write(t_dir.join("kitty.conf"), &kitty_content);
        let kitty_user_dir = config_root.join("kitty");
        if kitty_user_dir.exists() {
            let _ = fs::write(kitty_user_dir.join("agility-colors.conf"), &kitty_content);
        }

        // 2. Alacritty
        let alacritty_content = format!(
            "# Agility Shell Generated Theme\n\
             [colors.primary]\n\
             background = \"{bg}\"\n\
             foreground = \"{on_surface}\"\n\n\
             [colors.cursor]\n\
             text = \"{bg}\"\n\
             cursor = \"{primary}\"\n\n\
             [colors.normal]\n\
             black = \"{surface}\"\n\
             blue = \"{primary}\"\n\
             cyan = \"{secondary}\"\n\
             white = \"{on_surface}\"\n\n\
             [colors.bright]\n\
             black = \"{surface_container}\"\n\
             blue = \"{primary}\"\n\
             cyan = \"{secondary}\"\n\
             white = \"#ffffff\"\n",
            bg = tokens.background_color,
            on_surface = tokens.on_surface,
            primary = tokens.primary_color,
            surface = tokens.surface_color,
            secondary = tokens.secondary_color,
            surface_container = tokens.surface_container,
        );
        let _ = fs::write(t_dir.join("alacritty.toml"), &alacritty_content);
        let alacritty_user_dir = config_root.join("alacritty");
        if alacritty_user_dir.exists() {
            let _ = fs::write(
                alacritty_user_dir.join("agility-colors.toml"),
                &alacritty_content,
            );
        }

        // 3. Foot
        let foot_content = format!(
            "# Agility Shell Generated Theme\n\
             [colors]\n\
             background={bg}\n\
             foreground={on_surface}\n\
             regular0={surface}\n\
             regular4={primary}\n\
             regular6={secondary}\n\
             regular7={on_surface}\n\
             bright0={surface_container}\n\
             bright4={primary}\n\
             bright6={secondary}\n\
             bright7=ffffff\n",
            bg = strip_hash(&tokens.background_color),
            on_surface = strip_hash(&tokens.on_surface),
            surface = strip_hash(&tokens.surface_color),
            primary = strip_hash(&tokens.primary_color),
            secondary = strip_hash(&tokens.secondary_color),
            surface_container = strip_hash(&tokens.surface_container),
        );
        let _ = fs::write(t_dir.join("foot.ini"), &foot_content);
        let foot_user_dir = config_root.join("foot");
        if foot_user_dir.exists() {
            let _ = fs::write(foot_user_dir.join("agility-colors.ini"), &foot_content);
        }

        // 4. Niri Borders
        let niri_content = format!(
            "// Agility Shell Generated Borders\n\
             layout {{\n\
                 focus-ring {{\n\
                     active-color \"{primary}\"\n\
                     inactive-color \"{surface_container}\"\n\
                 }}\n\
                 border {{\n\
                     active-color \"{primary}\"\n\
                     inactive-color \"{outline}\"\n\
                 }}\n\
             }}\n",
            primary = tokens.primary_color,
            surface_container = tokens.surface_container,
            outline = tokens.outline,
        );
        let _ = fs::write(t_dir.join("niri-borders.kdl"), &niri_content);
        let niri_user_dir = config_root.join("niri");
        if niri_user_dir.exists() {
            let _ = fs::write(niri_user_dir.join("agility-borders.kdl"), &niri_content);
        }
        let config_niri_dir = self.config_dir.join("niri");
        if config_niri_dir.exists() {
            let _ = fs::write(config_niri_dir.join("agility-borders.kdl"), &niri_content);
        }

        Ok(())
    }

    /// Trigger live reloads for external tools.
    pub fn reload_apps(&self) -> Result<()> {
        // Niri border reload
        let _ = Command::new("niri")
            .arg("msg")
            .arg("action")
            .arg("load-config-file")
            .spawn();

        // Foot terminal reload
        let _ = Command::new("killall").arg("-SIGUSR1").arg("foot").spawn();

        Ok(())
    }

    /// Synchronize GNOME / GTK / Flatpak color-scheme preference via gsettings.
    pub fn sync_gsettings_color_scheme(&self, is_dark: bool) -> Result<()> {
        let scheme = if is_dark { "prefer-dark" } else { "default" };
        let _ = Command::new("gsettings")
            .arg("set")
            .arg("org.gnome.desktop.interface")
            .arg("color-scheme")
            .arg(scheme)
            .spawn();
        Ok(())
    }
}

/// D-Bus interface wrapper for `org.agility.Daemon.Theme`.
pub struct ThemeInterface {
    service: Arc<ThemeService>,
}

impl ThemeInterface {
    pub fn new(service: Arc<ThemeService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.agility.Daemon.Theme")]
impl ThemeInterface {
    /// Retrieve current active theme tokens JSON.
    async fn get_theme(&self) -> String {
        self.service.get_theme_json()
    }

    /// Alias retrieving theme tokens JSON.
    async fn get_tokens(&self) -> String {
        self.service.get_theme_json()
    }

    /// Retrieve active preset name if static preset is active.
    async fn get_active_preset(&self) -> String {
        self.service.active_preset()
    }

    /// Retrieve active wallpaper path.
    async fn get_active_wallpaper(&self) -> String {
        self.service.active_wallpaper()
    }

    /// Query whether dark mode is currently active.
    async fn is_dark_mode(&self) -> bool {
        self.service.is_dark()
    }

    /// Set dark mode explicitly. Emits `ThemeChanged` signal.
    async fn set_dark_mode(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        is_dark: bool,
    ) -> zbus::fdo::Result<bool> {
        match self.service.set_dark_mode(is_dark) {
            Ok(tokens) => {
                let json = serde_json::to_string(&tokens).unwrap_or_default();
                let _ = Self::theme_changed(&emitter, &json).await;
                let _ = Self::dark_mode_changed(&emitter, is_dark).await;
                Ok(true)
            }
            Err(e) => {
                error!("Failed to set dark mode: {e:#}");
                Ok(false)
            }
        }
    }

    /// Toggle dark mode. Emits `ThemeChanged` signal.
    async fn toggle_dark_mode(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> zbus::fdo::Result<bool> {
        match self.service.toggle_dark_mode() {
            Ok(tokens) => {
                let json = serde_json::to_string(&tokens).unwrap_or_default();
                let _ = Self::theme_changed(&emitter, &json).await;
                let _ = Self::dark_mode_changed(&emitter, tokens.is_dark).await;
                Ok(true)
            }
            Err(e) => {
                error!("Failed to toggle dark mode: {e:#}");
                Ok(false)
            }
        }
    }

    /// Switch theme preset (Dark, Light, TokyoNight, Catppuccin, Gruvbox).
    async fn set_preset(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        preset_name: &str,
    ) -> zbus::fdo::Result<bool> {
        match self.service.set_preset(preset_name) {
            Ok(tokens) => {
                let json = serde_json::to_string(&tokens).unwrap_or_default();
                let _ = Self::theme_changed(&emitter, &json).await;
                let _ = Self::dark_mode_changed(&emitter, tokens.is_dark).await;
                Ok(true)
            }
            Err(e) => {
                error!("Failed to set theme preset: {e:#}");
                Ok(false)
            }
        }
    }

    /// Retrieve list of available static presets.
    async fn get_presets(&self) -> Vec<String> {
        PRESETS.iter().map(|s| s.to_string()).collect()
    }

    /// Set wallpaper with smooth transition and re-extract colors.
    async fn set_wallpaper(
        &self,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
        path: &str,
        transition_type: &str,
        duration_secs: f64,
    ) -> zbus::fdo::Result<bool> {
        let t_type = if transition_type.is_empty() {
            None
        } else {
            Some(transition_type)
        };
        let dur = if duration_secs <= 0.0 {
            None
        } else {
            Some(duration_secs)
        };

        match self.service.set_wallpaper(path, t_type, dur) {
            Ok(tokens) => {
                let json = serde_json::to_string(&tokens).unwrap_or_default();
                let _ = Self::theme_changed(&emitter, &json).await;
                Ok(true)
            }
            Err(e) => {
                error!("Failed to set wallpaper: {e:#}");
                Ok(false)
            }
        }
    }

    /// Generate blurred wallpaper cache for a specified path.
    async fn generate_blurred_wallpaper(&self, source_path: &str, blur_radius: f32) -> bool {
        let src = PathBuf::from(source_path);
        let dest = self.service.cache_dir.join("wallpaper_blurred");
        let radius = if blur_radius <= 0.0 {
            DEFAULT_BLUR_RADIUS
        } else {
            blur_radius
        };
        ThemeService::generate_blurred_wallpaper(&src, &dest, radius).is_ok()
    }

    /// Re-render terminal and window manager templates.
    async fn apply_templates(&self) -> bool {
        let tokens = self.service.tokens();
        self.service.apply_templates(&tokens).is_ok()
    }

    /// Trigger reload of external apps.
    async fn reload_apps(&self) -> bool {
        self.service.reload_apps().is_ok()
    }

    /// Emitted when theme color tokens change.
    #[zbus(signal)]
    pub async fn theme_changed(emitter: &SignalEmitter<'_>, tokens_json: &str) -> zbus::Result<()>;

    /// Emitted when dark mode status changes.
    #[zbus(signal)]
    pub async fn dark_mode_changed(emitter: &SignalEmitter<'_>, is_dark: bool) -> zbus::Result<()>;
}

/// XDG Desktop Portal Settings backend (`org.freedesktop.impl.portal.Settings`).
/// Synchronizes `color-scheme` across Flatpaks, GTK, and Qt apps.
pub struct PortalSettingsInterface {
    service: Arc<ThemeService>,
}

impl PortalSettingsInterface {
    pub fn new(service: Arc<ThemeService>) -> Self {
        Self { service }
    }
}

#[zbus::interface(name = "org.freedesktop.impl.portal.Settings")]
impl PortalSettingsInterface {
    /// Read all portal settings for given namespaces.
    async fn read_all(
        &self,
        namespaces: Vec<String>,
    ) -> HashMap<String, HashMap<String, OwnedValue>> {
        let mut result = HashMap::new();
        let query_appearance = namespaces.is_empty()
            || namespaces
                .iter()
                .any(|ns| ns == "org.freedesktop.appearance");

        if query_appearance {
            let mut appearance_map = HashMap::new();
            // 0 = default, 1 = prefer-dark, 2 = prefer-light
            let scheme_code: u32 = if self.service.is_dark() { 1 } else { 2 };
            appearance_map.insert("color-scheme".to_string(), OwnedValue::from(scheme_code));

            let primary = self.service.tokens().primary_color;
            if let Ok(val) = OwnedValue::try_from(zbus::zvariant::Value::from(primary.clone())) {
                appearance_map.insert("accent-color".to_string(), val);
            }

            result.insert("org.freedesktop.appearance".to_string(), appearance_map);
        }

        result
    }

    /// Read single portal setting value.
    async fn read(&self, namespace: String, key: String) -> zbus::fdo::Result<OwnedValue> {
        if namespace == "org.freedesktop.appearance" {
            if key == "color-scheme" {
                let code: u32 = if self.service.is_dark() { 1 } else { 2 };
                return Ok(OwnedValue::from(code));
            }
            if key == "accent-color" {
                let primary = self.service.tokens().primary_color;
                return OwnedValue::try_from(zbus::zvariant::Value::from(primary))
                    .map_err(|e| zbus::fdo::Error::Failed(e.to_string()));
            }
        }
        Err(zbus::fdo::Error::UnknownProperty(format!(
            "Property {namespace}.{key} not found"
        )))
    }

    /// Emitted when a portal setting changes.
    #[zbus(signal)]
    pub async fn setting_changed(
        emitter: &SignalEmitter<'_>,
        namespace: &str,
        key: &str,
        value: zbus::zvariant::Value<'_>,
    ) -> zbus::Result<()>;
}

#[cfg(test)]
mod tests {
    use super::*;

    struct TestDirGuard(PathBuf);
    impl Drop for TestDirGuard {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    fn create_test_theme_service() -> (Arc<ThemeService>, TestDirGuard) {
        let unique = Instant::now().elapsed().as_nanos();
        let temp_dir = std::env::temp_dir().join(format!("agility_test_theme_{unique}"));
        let config_dir = temp_dir.join("config");
        let cache_dir = temp_dir.join("cache");
        let _ = fs::create_dir_all(&config_dir);
        let _ = fs::create_dir_all(&cache_dir);

        let service = ThemeService::new(config_dir, cache_dir);
        (service, TestDirGuard(temp_dir))
    }

    #[test]
    fn test_static_presets() {
        let dark = ThemeTokens::dark();
        assert!(dark.is_dark);
        assert_eq!(dark.active_preset, "Dark");

        let light = ThemeTokens::light();
        assert!(!light.is_dark);
        assert_eq!(light.active_preset, "Light");

        let tokyo = ThemeTokens::from_preset("TokyoNight").unwrap();
        assert_eq!(tokyo.primary_color, "#7aa2f7");

        let catppuccin = ThemeTokens::from_preset("Catppuccin").unwrap();
        assert_eq!(catppuccin.primary_color, "#89b4fa");

        let gruvbox = ThemeTokens::from_preset("Gruvbox").unwrap();
        assert_eq!(gruvbox.primary_color, "#fe8019");

        assert!(ThemeTokens::from_preset("nonexistent").is_none());
    }

    #[test]
    fn test_theme_service_dark_mode_and_presets() {
        let (service, _guard) = create_test_theme_service();

        // Initial default is dark
        assert!(service.is_dark());

        // Toggle to light
        let light_tokens = service.toggle_dark_mode().unwrap();
        assert!(!light_tokens.is_dark);
        assert!(!service.is_dark());

        // Switch to TokyoNight preset
        let tokyo = service.set_preset("TokyoNight").unwrap();
        assert_eq!(tokyo.primary_color, "#7aa2f7");
        assert_eq!(service.active_preset(), "TokyoNight");

        // Verify JSON serialization contains fields
        let json = service.get_theme_json();
        assert!(json.contains("primary_color"));
        assert!(json.contains("#7aa2f7"));
    }

    #[test]
    fn test_portal_settings_interface() {
        let (service, _guard) = create_test_theme_service();
        let portal = PortalSettingsInterface::new(service.clone());

        // Test read color-scheme in dark mode (should be 1)
        let rt = tokio::runtime::Runtime::new().unwrap();
        rt.block_on(async {
            let val = portal
                .read("org.freedesktop.appearance".into(), "color-scheme".into())
                .await
                .unwrap();
            let code = u32::try_from(&val).unwrap();
            assert_eq!(code, 1);

            // Toggle to light mode
            service.set_dark_mode(false).unwrap();
            let val_light = portal
                .read("org.freedesktop.appearance".into(), "color-scheme".into())
                .await
                .unwrap();
            let code_light = u32::try_from(&val_light).unwrap();
            assert_eq!(code_light, 2);

            // Test read_all
            let all = portal
                .read_all(vec!["org.freedesktop.appearance".into()])
                .await;
            assert!(all.contains_key("org.freedesktop.appearance"));
            let app = &all["org.freedesktop.appearance"];
            assert!(app.contains_key("color-scheme"));
            assert!(app.contains_key("accent-color"));
        });
    }

    #[test]
    fn test_fast_blurred_wallpaper_generation() {
        let temp_dir =
            std::env::temp_dir().join(format!("agility_test_blur_{}", std::process::id()));
        let _ = fs::create_dir_all(&temp_dir);

        // Create a dummy 1920x1080 test image
        let src_img = temp_dir.join("test_wall.png");
        let mut img = image::RgbImage::new(1920, 1080);
        for (x, y, pixel) in img.enumerate_pixels_mut() {
            *pixel = image::Rgb([(x % 256) as u8, (y % 256) as u8, 128]);
        }
        img.save(&src_img).unwrap();

        let dest_img = temp_dir.join("test_blurred.jpg");

        let start = Instant::now();
        ThemeService::generate_blurred_wallpaper(&src_img, &dest_img, DEFAULT_BLUR_RADIUS).unwrap();
        let elapsed = start.elapsed();

        assert!(dest_img.exists());
        let meta = fs::metadata(&dest_img).unwrap();
        assert!(meta.len() > 0);

        println!(
            "Blur execution time: {:.2}ms",
            elapsed.as_secs_f64() * 1000.0
        );

        let _ = fs::remove_dir_all(&temp_dir);
    }

    #[test]
    fn test_template_generation() {
        let (service, _guard) = create_test_theme_service();
        let tokens = ThemeTokens::tokyo_night();
        service.apply_templates(&tokens).unwrap();

        let t_dir = service.cache_dir.join("templates");
        assert!(t_dir.join("kitty.conf").exists());
        assert!(t_dir.join("alacritty.toml").exists());
        assert!(t_dir.join("foot.ini").exists());
        assert!(t_dir.join("niri-borders.kdl").exists());

        let kitty_str = fs::read_to_string(t_dir.join("kitty.conf")).unwrap();
        assert!(kitty_str.contains("#7aa2f7"));

        let niri_str = fs::read_to_string(t_dir.join("niri-borders.kdl")).unwrap();
        assert!(niri_str.contains("#7aa2f7"));
    }
}
