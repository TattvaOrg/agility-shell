use crate::audio::AudioEngine;
use crate::config::Config;
use crate::mpris::MprisManager;
use crate::render::{GlowUniforms, RenderContext};
use crate::wayland::surface::MonitorSurface;
use smithay_client_toolkit::{
    compositor::{CompositorHandler, CompositorState},
    delegate_compositor, delegate_layer, delegate_output, delegate_registry,
    output::{OutputHandler, OutputState},
    registry::{ProvidesRegistryState, RegistryState},
    registry_handlers,
    shell::{
        wlr_layer::{LayerShell, LayerShellHandler, LayerSurface, LayerSurfaceConfigure},
        WaylandSurface,
    },
};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;
use tracing::{debug, error, info};

use wayland_client::{
    protocol::{wl_output, wl_surface},
    Connection, Proxy, QueueHandle,
};

pub struct WaylandAppState {
    pub registry_state: RegistryState,
    pub compositor_state: CompositorState,
    pub output_state: OutputState,
    pub layer_shell: LayerShell,

    pub render_context: Arc<RenderContext>,
    pub surfaces: Vec<MonitorSurface>,
    pub display_ptr: *mut std::ffi::c_void,

    pub config: Config,
    pub audio_engine: Arc<AudioEngine>,
    pub mpris_manager: Arc<MprisManager>,
    pub is_locked: Arc<AtomicBool>,
    pub start_time: Instant,
    pub exit: bool,
}

impl WaylandAppState {
    pub fn new(
        registry_state: RegistryState,
        compositor_state: CompositorState,
        output_state: OutputState,
        layer_shell: LayerShell,
        render_context: Arc<RenderContext>,
        display_ptr: *mut std::ffi::c_void,
        config: Config,
        audio_engine: Arc<AudioEngine>,
        mpris_manager: Arc<MprisManager>,
        is_locked: Arc<AtomicBool>,
    ) -> Self {
        Self {
            registry_state,
            compositor_state,
            output_state,
            layer_shell,
            render_context,
            surfaces: Vec::new(),
            display_ptr,
            config,
            audio_engine,
            mpris_manager,
            is_locked,
            start_time: Instant::now(),
            exit: false,
        }
    }

    pub fn render_frame(&mut self) {
        let time = self.start_time.elapsed().as_secs_f32();
        let bass_intensity = self.audio_engine.current_intensity();
        let palette = self.mpris_manager.current_palette();
        let locked = self.is_locked.load(Ordering::Relaxed);

        // When locked, provide calm ethereal lock pulsing
        let active_intensity = if locked {
            ((time * 0.8).sin() * 0.5 + 0.5) * 0.35 + 0.15
        } else {
            bass_intensity * self.config.glow.intensity
        };

        let direction_mult = if self.config.glow.direction == "counter_clockwise" {
            -1.0
        } else {
            1.0
        };

        for surface in &mut self.surfaces {
            let physical_w = surface.width * (surface.scale_factor.max(1) as u32);
            let physical_h = surface.height * (surface.scale_factor.max(1) as u32);

            let uniforms = GlowUniforms {
                resolution: [physical_w as f32, physical_h as f32],
                thickness: self.config.glow.thickness_px as f32 * surface.scale_factor.max(1) as f32,
                intensity: active_intensity,
                primary_color: palette.primary.to_array(),
                secondary_color: palette.secondary.to_array(),
                time,
                speed: self.config.glow.speed,
                corner_radius: self.config.glow.corner_radius_px as f32 * surface.scale_factor.max(1) as f32,
                direction: direction_mult,
            };

            if let Err(e) = surface.renderer.render(&self.render_context, uniforms) {
                debug!("Surface render notice: {:?}", e);
            }
        }
    }
}

impl CompositorHandler for WaylandAppState {
    fn scale_factor_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        surface: &wl_surface::WlSurface,
        new_factor: i32,
    ) {
        for s in &mut self.surfaces {
            if s.layer_surface.wl_surface() == surface {
                s.set_scale_factor(&self.render_context, new_factor);
                break;
            }
        }
    }

    fn transform_changed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _new_transform: wl_output::Transform,
    ) {
    }

    fn frame(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _time: u32,
    ) {
    }

    fn surface_enter(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }

    fn surface_leave(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _surface: &wl_surface::WlSurface,
        _output: &wl_output::WlOutput,
    ) {
    }
}

impl OutputHandler for WaylandAppState {
    fn output_state(&mut self) -> &mut OutputState {
        &mut self.output_state
    }

    fn new_output(
        &mut self,
        _conn: &Connection,
        qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        info!("Discovered new Wayland output: {:?}", output.id());
        match MonitorSurface::new(
            qh,
            &output,
            &self.compositor_state,
            &self.layer_shell,
            &self.render_context,
            self.display_ptr,
        ) {
            Ok(surf) => {
                self.surfaces.push(surf);
            }
            Err(e) => {
                error!("Failed to create layer surface for output {:?}: {e:#}", output.id());
            }
        }
    }

    fn update_output(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        _output: wl_output::WlOutput,
    ) {
    }

    fn output_destroyed(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        output: wl_output::WlOutput,
    ) {
        info!("Wayland output removed: {:?}", output.id());
        self.surfaces.retain(|s| s.output != output);
    }
}

impl LayerShellHandler for WaylandAppState {
    fn closed(&mut self, _conn: &Connection, _qh: &QueueHandle<Self>, layer: &LayerSurface) {
        self.surfaces.retain(|s| &s.layer_surface != layer);
    }

    fn configure(
        &mut self,
        _conn: &Connection,
        _qh: &QueueHandle<Self>,
        layer: &LayerSurface,
        configure: LayerSurfaceConfigure,
        _serial: u32,
    ) {
        let (width, height) = configure.new_size;
        for s in &mut self.surfaces {
            if &s.layer_surface == layer {
                s.resize(&self.render_context, width, height);
                s.layer_surface.commit();
                break;
            }
        }
    }
}

impl ProvidesRegistryState for WaylandAppState {
    fn registry(&mut self) -> &mut RegistryState {
        &mut self.registry_state
    }

    registry_handlers![OutputState];
}


impl wayland_client::Dispatch<wayland_client::protocol::wl_region::WlRegion, ()> for WaylandAppState {
    fn event(
        _state: &mut Self,
        _proxy: &wayland_client::protocol::wl_region::WlRegion,
        _event: wayland_client::protocol::wl_region::Event,
        _data: &(),
        _conn: &Connection,
        _qhandle: &QueueHandle<Self>,
    ) {
    }
}

delegate_compositor!(WaylandAppState);
delegate_output!(WaylandAppState);
delegate_layer!(WaylandAppState);
delegate_registry!(WaylandAppState);

