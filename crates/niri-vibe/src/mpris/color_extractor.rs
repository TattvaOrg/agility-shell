use std::path::Path;
use std::time::Instant;

#[derive(Debug, Clone, Copy)]
pub struct ColorRgba {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl ColorRgba {
    pub const fn new(r: f32, g: f32, b: f32, a: f32) -> Self {
        Self { r, g, b, a }
    }

    pub fn to_array(&self) -> [f32; 4] {
        [self.r, self.g, self.b, self.a]
    }

    pub fn to_hsl(&self) -> (f32, f32, f32) {
        let max = self.r.max(self.g).max(self.b);
        let min = self.r.min(self.g).min(self.b);
        let l = (max + min) / 2.0;

        if (max - min).abs() < 1e-4 {
            return (0.0, 0.0, l);
        }

        let d = max - min;
        let s = if l > 0.5 {
            d / (2.0 - max - min)
        } else {
            d / (max + min)
        };

        let mut h = if (max - self.r).abs() < 1e-4 {
            (self.g - self.b) / d + (if self.g < self.b { 6.0 } else { 0.0 })
        } else if (max - self.g).abs() < 1e-4 {
            (self.b - self.r) / d + 2.0
        } else {
            (self.r - self.g) / d + 4.0
        };
        h /= 6.0;

        (h, s, l)
    }

    pub fn from_hsl(h: f32, s: f32, l: f32) -> Self {
        if s < 1e-4 {
            return Self::new(l, l, l, 1.0);
        }

        let q = if l < 0.5 {
            l * (1.0 + s)
        } else {
            l + s - l * s
        };
        let p = 2.0 * l - q;

        let r = hue_to_rgb(p, q, h + 1.0 / 3.0);
        let g = hue_to_rgb(p, q, h);
        let b = hue_to_rgb(p, q, h - 1.0 / 3.0);

        Self::new(r, g, b, 1.0)
    }

    pub fn lerp(&self, other: &Self, t: f32) -> Self {
        let t = t.clamp(0.0, 1.0);
        Self::new(
            self.r + (other.r - self.r) * t,
            self.g + (other.g - self.g) * t,
            self.b + (other.b - self.b) * t,
            self.a + (other.a - self.a) * t,
        )
    }
}

fn hue_to_rgb(p: f32, q: f32, mut t: f32) -> f32 {
    if t < 0.0 {
        t += 1.0;
    }
    if t > 1.0 {
        t -= 1.0;
    }
    if t < 1.0 / 6.0 {
        return p + (q - p) * 6.0 * t;
    }
    if t < 1.0 / 2.0 {
        return q;
    }
    if t < 2.0 / 3.0 {
        return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    }
    p
}

#[derive(Debug, Clone)]
pub struct DualPalette {
    pub primary: ColorRgba,
    pub secondary: ColorRgba,
}

impl Default for DualPalette {
    fn default() -> Self {
        Self {
            primary: ColorRgba::new(1.0, 0.23, 0.188, 1.0),   // vibrant red
            secondary: ColorRgba::new(0.92, 0.45, 0.72, 1.0), // harmonizing pink/magenta
        }
    }
}

pub struct PaletteAnimator {
    pub current: DualPalette,
    pub target: DualPalette,
    pub start: DualPalette,
    pub transition_start: Instant,
    pub duration_secs: f32,
}

impl PaletteAnimator {
    pub fn new(initial: DualPalette) -> Self {
        Self {
            current: initial.clone(),
            target: initial.clone(),
            start: initial,
            transition_start: Instant::now(),
            duration_secs: 0.300, // 300ms smooth cubic transition
        }
    }

    pub fn set_target(&mut self, new_target: DualPalette) {
        self.start = self.current.clone();
        self.target = new_target;
        self.transition_start = Instant::now();
    }

    pub fn update(&mut self) -> DualPalette {
        let elapsed = self.transition_start.elapsed().as_secs_f32();
        let progress = (elapsed / self.duration_secs).min(1.0);

        // Smooth cubic ease-out: 1 - (1 - t)^3
        let ease = 1.0 - (1.0 - progress).powi(3);

        self.current.primary = self.start.primary.lerp(&self.target.primary, ease);
        self.current.secondary = self.start.secondary.lerp(&self.target.secondary, ease);

        self.current.clone()
    }
}

/// Extracts dominant saturated color using k-means clustering (k=5)
pub fn extract_palette_from_image(path: &Path) -> Option<DualPalette> {
    let img = image::open(path).ok()?;
    // Downsample to 64x64 for near-instant clustering
    let thumb = image::imageops::thumbnail(&img, 64, 64);

    let mut pixels = Vec::with_capacity(64 * 64);
    for p in thumb.pixels() {
        let r = p[0] as f32 / 255.0;

        let g = p[1] as f32 / 255.0;
        let b = p[2] as f32 / 255.0;

        let col = ColorRgba::new(r, g, b, 1.0);
        let (_, _s, l) = col.to_hsl();


        // Discard extreme blacks or whites unless monochrome
        if l > 0.08 && l < 0.94 {
            pixels.push(col);
        }
    }

    if pixels.is_empty() {
        return None;
    }

    // Run k-means with 5 clusters
    let k = 5.min(pixels.len());
    let mut centroids: Vec<ColorRgba> = (0..k)
        .map(|i| pixels[(i * pixels.len()) / k])
        .collect();

    let mut cluster_assignments = vec![0usize; pixels.len()];

    for _iter in 0..8 {
        // Assign pixels to closest centroid (Euclidean distance in RGB)
        for (i, p) in pixels.iter().enumerate() {
            let mut min_dist = f32::MAX;
            let mut best_idx = 0;
            for (c_idx, c) in centroids.iter().enumerate() {
                let dr = p.r - c.r;
                let dg = p.g - c.g;
                let db = p.b - c.b;
                let dist = dr * dr + dg * dg + db * db;
                if dist < min_dist {
                    min_dist = dist;
                    best_idx = c_idx;
                }
            }
            cluster_assignments[i] = best_idx;
        }

        // Recompute centroids
        let mut sums = vec![(0.0f32, 0.0f32, 0.0f32, 0usize); k];
        for (i, &c_idx) in cluster_assignments.iter().enumerate() {
            let p = pixels[i];
            sums[c_idx].0 += p.r;
            sums[c_idx].1 += p.g;
            sums[c_idx].2 += p.b;
            sums[c_idx].3 += 1;
        }

        for (c_idx, (sr, sg, sb, count)) in sums.into_iter().enumerate() {
            if count > 0 {
                centroids[c_idx] = ColorRgba::new(
                    sr / count as f32,
                    sg / count as f32,
                    sb / count as f32,
                    1.0,
                );
            }
        }
    }

    // Pick cluster with highest saturation and rich vibrance
    let mut best_score = -1.0f32;
    let mut best_color = centroids[0];

    for c in &centroids {
        let (_h, s, l) = c.to_hsl();
        // Prefer rich saturation and mid-lightness (0.35 .. 0.65)
        let lightness_penalty = (l - 0.5).abs() * 1.5;
        let score = s * 2.5 + (1.0 - lightness_penalty).max(0.0);
        if score > best_score {
            best_score = score;
            best_color = *c;
        }
    }

    // Boost saturation and brightness slightly if too muddy
    let (h, s, l) = best_color.to_hsl();
    let primary = ColorRgba::from_hsl(
        h,
        s.max(0.65),
        l.clamp(0.40, 0.65),
    );

    // Complementary secondary color (golden angle shift +0.42 for organic harmony)
    let secondary = ColorRgba::from_hsl(
        (h + 0.42) % 1.0,
        s.max(0.70),
        (l + 0.08).clamp(0.45, 0.70),
    );

    Some(DualPalette { primary, secondary })
}
