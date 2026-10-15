use crate::audio::fft::BassAnalyzer;
use pipewire as pw;
use pw::{properties::properties, spa};
use spa::param::format::{MediaSubtype, MediaType};
use spa::param::format_utils;
use spa::pod::Pod;
use std::convert::TryInto;
use std::mem;
use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use tracing::{info, warn};

pub const SAMPLE_RATE: f32 = 48000.0;
pub const BUFFER_SIZE: usize = 2048;

pub struct AudioEngine {
    intensity_bits: Arc<AtomicU32>,
    running: Arc<AtomicBool>,
}

struct StreamUserData {
    format: spa::param::audio::AudioInfoRaw,
    samples_ring: Arc<Mutex<Vec<f32>>>,
}

impl Default for AudioEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl AudioEngine {
    pub fn new() -> Self {
        Self {
            intensity_bits: Arc::new(AtomicU32::new(0.0f32.to_bits())),
            running: Arc::new(AtomicBool::new(true)),
        }
    }

    pub fn current_intensity(&self) -> f32 {
        f32::from_bits(self.intensity_bits.load(Ordering::Relaxed))
    }

    pub fn start(&self, idle_breathing: bool) {
        let intensity_bits = Arc::clone(&self.intensity_bits);
        let running = Arc::clone(&self.running);

        thread::spawn(move || {
            info!("Starting PipeWire audio capture engine (48kHz, 2048 samples)...");

            if let Err(e) = run_pipewire_capture(
                Arc::clone(&intensity_bits),
                Arc::clone(&running),
                idle_breathing,
            ) {
                warn!("PipeWire capture failed or unavailable ({e:#}). Falling back to ethereal idle breathing mode.");
                run_fallback_breathing_loop(intensity_bits, running, idle_breathing);
            }
        });
    }

    pub fn stop(&self) {
        self.running.store(false, Ordering::SeqCst);
    }
}

fn run_pipewire_capture(
    intensity_bits: Arc<AtomicU32>,
    running: Arc<AtomicBool>,
    idle_breathing: bool,
) -> Result<(), pw::Error> {
    pw::init();

    let mainloop = pw::main_loop::MainLoopRc::new(None)?;
    let context = pw::context::ContextRc::new(&mainloop, None)?;
    let core = context.connect_rc(None)?;

    let samples_ring = Arc::new(Mutex::new(Vec::with_capacity(BUFFER_SIZE * 2)));
    let user_data = StreamUserData {
        format: Default::default(),
        samples_ring: Arc::clone(&samples_ring),
    };

    let props = properties! {
        *pw::keys::MEDIA_TYPE => "Audio",
        *pw::keys::MEDIA_CATEGORY => "Capture",
        *pw::keys::MEDIA_ROLE => "DSP",
        *pw::keys::STREAM_CAPTURE_SINK => "true",
    };

    let stream = pw::stream::StreamBox::new(&core, "niri-vibe-capture", props)?;

    let _listener = stream
        .add_local_listener_with_user_data(user_data)
        .param_changed(|_, user_data, id, param| {
            let Some(param) = param else {
                return;
            };
            if id != pw::spa::param::ParamType::Format.as_raw() {
                return;
            }

            let (media_type, media_subtype) = match format_utils::parse_format(param) {
                Ok(v) => v,
                Err(_) => return,
            };

            if media_type != MediaType::Audio || media_subtype != MediaSubtype::Raw {
                return;
            }

            let _ = user_data.format.parse(param);
        })
        .process(|stream, user_data| {
            if let Some(mut buffer) = stream.dequeue_buffer() {
                let datas = buffer.datas_mut();
                if datas.is_empty() {
                    return;
                }

                let data = &mut datas[0];
                let n_channels = user_data.format.channels().max(1);
                let n_samples = data.chunk().size() / (mem::size_of::<f32>() as u32);

                if let Some(samples) = data.data() {
                    let mut downmixed = Vec::with_capacity((n_samples / n_channels) as usize);
                    let sample_count = n_samples / n_channels;

                    for i in 0..sample_count {
                        let mut sum = 0.0f32;
                        for c in 0..n_channels {
                            let idx = ((i * n_channels + c) as usize) * mem::size_of::<f32>();
                            if idx + mem::size_of::<f32>() <= samples.len() {
                                let slice = &samples[idx..idx + mem::size_of::<f32>()];
                                if let Ok(bytes) = slice.try_into() {
                                    sum += f32::from_le_bytes(bytes);
                                }
                            }
                        }
                        downmixed.push(sum / n_channels as f32);
                    }

                    if let Ok(mut ring) = user_data.samples_ring.lock() {
                        ring.extend(downmixed);
                        if ring.len() > BUFFER_SIZE * 4 {
                            let excess = ring.len() - BUFFER_SIZE * 2;
                            ring.drain(0..excess);
                        }
                    }
                }
            }
        })
        .register()?;

    let mut audio_info = spa::param::audio::AudioInfoRaw::new();
    audio_info.set_format(spa::param::audio::AudioFormat::F32LE);
    audio_info.set_rate(SAMPLE_RATE as u32);

    let obj = pw::spa::pod::Object {
        type_: pw::spa::utils::SpaTypes::ObjectParamFormat.as_raw(),
        id: pw::spa::param::ParamType::EnumFormat.as_raw(),
        properties: audio_info.into(),
    };
    let values: Vec<u8> = pw::spa::pod::serialize::PodSerializer::serialize(
        std::io::Cursor::new(Vec::new()),
        &pw::spa::pod::Value::Object(obj),
    )
    .unwrap()
    .0
    .into_inner();

    let mut params = [Pod::from_bytes(&values).unwrap()];

    stream.connect(
        spa::utils::Direction::Input,
        None,
        pw::stream::StreamFlags::AUTOCONNECT
            | pw::stream::StreamFlags::MAP_BUFFERS
            | pw::stream::StreamFlags::RT_PROCESS,
        &mut params,
    )?;

    // Spawn FFT processing thread that drains from samples_ring and computes bass intensity
    let ring_for_fft = Arc::clone(&samples_ring);
    let intensity_for_fft = Arc::clone(&intensity_bits);
    let running_for_fft = Arc::clone(&running);

    thread::spawn(move || {
        let mut analyzer = BassAnalyzer::new(BUFFER_SIZE, SAMPLE_RATE);
        let mut local_buf = Vec::with_capacity(BUFFER_SIZE);

        while running_for_fft.load(Ordering::Relaxed) {
            {
                if let Ok(mut ring) = ring_for_fft.lock() {
                    if ring.len() >= BUFFER_SIZE {
                        local_buf.clear();
                        local_buf.extend(ring.drain(0..BUFFER_SIZE));
                    }
                }
            }

            let intensity = analyzer.process(&local_buf, idle_breathing);
            intensity_for_fft.store(intensity.to_bits(), Ordering::Relaxed);

            // Run analysis at ~60Hz intervals (every 16ms)
            thread::sleep(Duration::from_millis(16));
        }
    });

    info!("PipeWire capture stream connected and active.");

    while running.load(Ordering::Relaxed) {
        mainloop.loop_().iterate(Duration::from_millis(10));
    }

    Ok(())
}

fn run_fallback_breathing_loop(
    intensity_bits: Arc<AtomicU32>,
    running: Arc<AtomicBool>,
    idle_breathing: bool,
) {
    let mut phase = 0.0f32;
    while running.load(Ordering::Relaxed) {
        phase = (phase + 0.02) % (std::f32::consts::PI * 2.0);
        let val = if idle_breathing {
            (phase.sin() * 0.5 + 0.5) * 0.08 + 0.06
        } else {
            0.0
        };
        intensity_bits.store(val.to_bits(), Ordering::Relaxed);
        thread::sleep(Duration::from_millis(16));
    }
}
