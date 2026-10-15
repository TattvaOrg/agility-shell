use crate::render::pipeline::{GlowPipeline, GlowUniforms};
use anyhow::{Context, Result};
use raw_window_handle::{
    RawDisplayHandle, RawWindowHandle, WaylandDisplayHandle, WaylandWindowHandle,
};
use std::ptr::NonNull;
use std::sync::Arc;
use tracing::info;
use wgpu::util::DeviceExt;

pub struct RenderContext {
    pub instance: wgpu::Instance,
    pub adapter: wgpu::Adapter,
    pub device: Arc<wgpu::Device>,
    pub queue: Arc<wgpu::Queue>,
    pub pipeline: GlowPipeline,
    pub surface_format: wgpu::TextureFormat,
}

impl RenderContext {
    pub fn new() -> Result<Self> {
        let instance = wgpu::Instance::new(wgpu::InstanceDescriptor {
            backends: wgpu::Backends::all(),
            ..Default::default()
        });

        // Request high performance or default adapter
        let adapter = pollster::block_on(instance.request_adapter(&wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::LowPower,
            compatible_surface: None,
            force_fallback_adapter: false,
        }))
        .context("Failed to find suitable GPU adapter for wgpu")?;

        info!("Selected GPU adapter: {:?}", adapter.get_info().name);

        let (device, queue) = pollster::block_on(adapter.request_device(
            &wgpu::DeviceDescriptor {
                label: Some("niri-vibe-device"),
                required_features: wgpu::Features::empty(),
                required_limits: wgpu::Limits::default(),
            },
            None,
        ))
        .context("Failed to initialize wgpu device")?;

        let surface_format = wgpu::TextureFormat::Bgra8UnormSrgb;
        let pipeline = GlowPipeline::new(&device, surface_format);

        Ok(Self {
            instance,
            adapter,
            device: Arc::new(device),
            queue: Arc::new(queue),
            pipeline,
            surface_format,
        })
    }

    pub fn create_surface_for_wayland(
        &self,
        display_ptr: *mut std::ffi::c_void,
        surface_ptr: *mut std::ffi::c_void,
    ) -> Result<wgpu::Surface<'static>> {
        let raw_display_handle = RawDisplayHandle::Wayland(WaylandDisplayHandle::new(
            NonNull::new(display_ptr).context("Wayland display pointer is null")?,
        ));
        let raw_window_handle = RawWindowHandle::Wayland(WaylandWindowHandle::new(
            NonNull::new(surface_ptr).context("Wayland surface pointer is null")?,
        ));

        let surface = unsafe {
            self.instance
                .create_surface_unsafe(wgpu::SurfaceTargetUnsafe::RawHandle {
                    raw_display_handle,
                    raw_window_handle,
                })?
        };

        Ok(surface)
    }
}

pub struct SurfaceRenderer {
    pub surface: wgpu::Surface<'static>,
    pub uniform_buffer: wgpu::Buffer,
    pub bind_group: wgpu::BindGroup,
    pub width: u32,
    pub height: u32,
    pub configured: bool,
}

impl SurfaceRenderer {
    pub fn new(
        context: &RenderContext,
        surface: wgpu::Surface<'static>,
        width: u32,
        height: u32,
    ) -> Self {
        let initial_uniforms = GlowUniforms {
            resolution: [width as f32, height as f32],
            thickness: 40.0,
            intensity: 0.7,
            primary_color: [1.0, 0.23, 0.188, 1.0],
            secondary_color: [0.92, 0.45, 0.72, 1.0],
            time: 0.0,
            speed: 1.0,
            corner_radius: 12.0,
            direction: 1.0,
        };

        let uniform_buffer = context
            .device
            .create_buffer_init(&wgpu::util::BufferInitDescriptor {
                label: Some("surface-glow-uniform-buffer"),
                contents: bytemuck::cast_slice(&[initial_uniforms]),
                usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
            });

        let bind_group = context
            .device
            .create_bind_group(&wgpu::BindGroupDescriptor {
                label: Some("surface-glow-bind-group"),
                layout: &context.pipeline.bind_group_layout,
                entries: &[wgpu::BindGroupEntry {
                    binding: 0,
                    resource: uniform_buffer.as_entire_binding(),
                }],
            });

        Self {
            surface,
            uniform_buffer,
            bind_group,
            width,
            height,
            configured: false,
        }
    }

    pub fn configure(&mut self, context: &RenderContext, width: u32, height: u32) {
        if width == 0 || height == 0 {
            return;
        }

        self.width = width;
        self.height = height;

        let surface_caps = self.surface.get_capabilities(&context.adapter);
        let format = if surface_caps.formats.contains(&context.surface_format) {
            context.surface_format
        } else {
            surface_caps.formats[0]
        };

        // Prefer PreMultiplied alpha for transparent desktop overlay
        let alpha_mode = if surface_caps
            .alpha_modes
            .contains(&wgpu::CompositeAlphaMode::PreMultiplied)
        {
            wgpu::CompositeAlphaMode::PreMultiplied
        } else if surface_caps
            .alpha_modes
            .contains(&wgpu::CompositeAlphaMode::Auto)
        {
            wgpu::CompositeAlphaMode::Auto
        } else {
            surface_caps.alpha_modes[0]
        };

        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format,
            width,
            height,
            present_mode: wgpu::PresentMode::Fifo, // VSync
            alpha_mode,
            view_formats: vec![],
            desired_maximum_frame_latency: 2,
        };

        self.surface.configure(&context.device, &config);
        self.configured = true;
    }

    pub fn render(&mut self, context: &RenderContext, uniforms: GlowUniforms) -> Result<()> {
        if !self.configured || self.width == 0 || self.height == 0 {
            return Ok(());
        }

        context
            .queue
            .write_buffer(&self.uniform_buffer, 0, bytemuck::cast_slice(&[uniforms]));

        let frame = match self.surface.get_current_texture() {
            Ok(f) => f,
            Err(wgpu::SurfaceError::Lost) => {
                self.configure(context, self.width, self.height);
                return Ok(());
            }
            Err(wgpu::SurfaceError::Outdated) => {
                return Ok(());
            }
            Err(e) => return Err(e.into()),
        };

        let view = frame
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());

        let mut encoder = context
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor {
                label: Some("glow-render-encoder"),
            });

        {
            let mut rpass = encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("glow-render-pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view: &view,
                    resolve_target: None,
                    ops: wgpu::Operations {
                        // Clear to full transparency
                        load: wgpu::LoadOp::Clear(wgpu::Color::TRANSPARENT),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                timestamp_writes: None,
                occlusion_query_set: None,
            });

            rpass.set_pipeline(&context.pipeline.pipeline);
            rpass.set_bind_group(0, &self.bind_group, &[]);
            rpass.draw(0..3, 0..1); // Fullscreen triangle
        }

        context.queue.submit(Some(encoder.finish()));
        frame.present();

        Ok(())
    }
}
