use rustfft::{num_complex::Complex, FftPlanner};
use std::f32::consts::PI;
use std::time::Instant;

pub struct BassAnalyzer {
    planner: FftPlanner<f32>,
    fft_size: usize,
    sample_rate: f32,
    window: Vec<f32>,
    smoothed_energy: f32,
    last_update: Instant,
    idle_phase: f32,
}

impl BassAnalyzer {
    pub fn new(fft_size: usize, sample_rate: f32) -> Self {
        // Precompute Hann window to eliminate spectral leakage
        let mut window = Vec::with_capacity(fft_size);
        for i in 0..fft_size {
            let w = 0.5 * (1.0 - (2.0 * PI * i as f32 / (fft_size as f32 - 1.0)).cos());
            window.push(w);
        }

        Self {
            planner: FftPlanner::new(),
            fft_size,
            sample_rate,
            window,
            smoothed_energy: 0.0,
            last_update: Instant::now(),
            idle_phase: 0.0,
        }
    }

    /// Processes a slice of f32 samples and extracts the bass amplitude (20-80Hz).
    /// Returns smoothed amplitude clamped to [0.0, 1.0], incorporating snappy attack,
    /// velvety decay, and ethereal sinusoidal breathing.
    pub fn process(&mut self, samples: &[f32], idle_breathing_enabled: bool) -> f32 {
        let now = Instant::now();
        let dt = now.duration_since(self.last_update).as_secs_f32().min(0.1);
        self.last_update = now;

        // Advance idle phase for ethereal breathing (approx 5.2s full period)
        self.idle_phase = (self.idle_phase + dt * 1.2) % (2.0 * PI);
        let idle_glow = if idle_breathing_enabled {
            (self.idle_phase.sin() * 0.5 + 0.5) * 0.08 + 0.06 // 0.06 to 0.14 baseline breathing
        } else {
            0.0
        };

        if samples.len() < self.fft_size {
            // No new audio or insufficient buffer: decay smoothly toward idle floor
            let decay_factor = (-dt / 0.280).exp();
            self.smoothed_energy *= decay_factor;
            return (self.smoothed_energy + idle_glow).clamp(0.0, 1.0);
        }

        // Prepare complex buffer with Hann window applied
        let mut buffer: Vec<Complex<f32>> = samples[..self.fft_size]
            .iter()
            .zip(&self.window)
            .map(|(&s, &w)| Complex::new(s * w, 0.0))
            .collect();

        // Perform FFT
        let fft = self.planner.plan_fft_forward(self.fft_size);
        fft.process(&mut buffer);

        // Frequency bin calculation:
        // bin_freq = k * sample_rate / fft_size
        // With 48000Hz and 2048 bins, bin_width is 23.4375 Hz.
        // 20Hz - 80Hz corresponds roughly to bins 1..=4.
        let bin_width = self.sample_rate / (self.fft_size as f32);
        let start_bin = ((20.0 / bin_width).floor() as usize).max(1);
        let end_bin = ((80.0 / bin_width).ceil() as usize).min(self.fft_size / 2);

        let mut sum_energy = 0.0;
        let mut count = 0;
        for item in &buffer[start_bin..=end_bin] {
            let magnitude = item.norm();
            sum_energy += magnitude * magnitude;
            count += 1;
        }


        let raw_rms = if count > 0 {
            (sum_energy / count as f32).sqrt()
        } else {
            0.0
        };

        // Normalize and scale: multiply by 0.8 as specified
        let raw_bass = (raw_rms * 2.5 * 0.8).clamp(0.0, 1.0);

        // Attack & Decay smoothing:
        // Snappy attack: 40ms time constant
        // Velvety decay: 280ms time constant
        let attack_alpha = 1.0 - (-dt / 0.040).exp();
        let decay_alpha = 1.0 - (-dt / 0.280).exp();

        if raw_bass > self.smoothed_energy {
            self.smoothed_energy += (raw_bass - self.smoothed_energy) * attack_alpha;
        } else {
            self.smoothed_energy += (raw_bass - self.smoothed_energy) * decay_alpha;
        }

        // Combined output incorporating bass amplitude + ethereal breathing
        let combined = if self.smoothed_energy > 0.02 {
            self.smoothed_energy
        } else {
            idle_glow
        };

        combined.clamp(0.0, 1.0)
    }
}
