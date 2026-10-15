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

            if let Ok(_info) = user_data.format.parse(param) {
                info!(
                    "PipeWire capture stream format: rate={}, channels={}",
                    user_data.format.rate(),
                    user_data.format.channels()
                );
            }
        })
        .process(|stream, user_data| {
            if let Some(mut buffer) = stream.dequeue_buffer() {
                let datas = buffer.datas_mut();
                if datas.is_empty() {
                    return;
                }

                if datas.len() >= 2 {
                    // Planar audio: datas[0] is Left, datas[1] is Right
                    let chunk0_size = datas[0].chunk().size() as usize;
                    let chunk1_size = datas[1].chunk().size() as usize;
                    let (first, rest) = datas.split_at_mut(1);
                    if let (Some(ch0), Some(ch1)) = (first[0].data(), rest[0].data()) {
                        let sample_bytes = mem::size_of::<f32>();
                        let len0 = if chunk0_size > 0 {
                            chunk0_size.min(ch0.len())
                        } else {
                            ch0.len()
                        };
                        let len1 = if chunk1_size > 0 {
                            chunk1_size.min(ch1.len())
                        } else {
                            ch1.len()
                        };
                        let n_floats = len0.min(len1) / sample_bytes;
                        let mut downmixed = Vec::with_capacity(n_floats);
                        for i in 0..n_floats {
                            let off = i * sample_bytes;
                            if off + 4 <= ch0.len() && off + 4 <= ch1.len() {
                                let s0 = f32::from_le_bytes(
                                    ch0[off..off + 4].try_into().unwrap_or([0; 4]),
                                );
                                let s1 = f32::from_le_bytes(
                                    ch1[off..off + 4].try_into().unwrap_or([0; 4]),
                                );
                                downmixed.push((s0 + s1) * 0.5);
                            }
                        }
                        if let Ok(mut ring) = user_data.samples_ring.lock() {
                            ring.extend(downmixed);
                            if ring.len() > BUFFER_SIZE * 4 {
                                let excess = ring.len() - BUFFER_SIZE * 2;
                                ring.drain(0..excess);
                            }
                        }
                    }
                } else if !datas.is_empty() {
                    // Interleaved audio: datas[0] contains L, R, L, R...
                    let chunk_size = datas[0].chunk().size() as usize;
                    if let Some(samples) = datas[0].data() {
                        let sample_bytes = mem::size_of::<f32>();
                        let total_bytes = if chunk_size > 0 {
                            chunk_size.min(samples.len())
                        } else {
                            samples.len()
                        };
                        let n_channels = user_data.format.channels().max(1) as usize;
                        let total_floats = total_bytes / sample_bytes;
                        let frames = total_floats / n_channels;
                        let mut downmixed = Vec::with_capacity(frames);
                        for f in 0..frames {
                            let mut sum = 0.0f32;
                            for c in 0..n_channels {
                                let off = (f * n_channels + c) * sample_bytes;
                                if off + 4 <= samples.len() {
                                    let s = f32::from_le_bytes(
                                        samples[off..off + 4].try_into().unwrap_or([0; 4]),
                                    );
                                    sum += s;
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
            }
        })
        .register()?;

    let mut audio_info = spa::param::audio::AudioInfoRaw::new();
    audio_info.set_format(spa::param::audio::AudioFormat::F32LE);
    audio_info.set_rate(SAMPLE_RATE as u32);
    audio_info.set_channels(2);

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
