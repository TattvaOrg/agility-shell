use crate::render::{RenderContext, SurfaceRenderer};
use crate::wayland::WaylandAppState;
use smithay_client_toolkit::{
    compositor::CompositorState,
    shell::{
        wlr_layer::{Anchor, KeyboardInteractivity, Layer, LayerShell, LayerSurface},
        WaylandSurface,
    },
};
use wayland_client::{protocol::wl_output, Proxy, QueueHandle};

pub struct MonitorSurface {
    pub output: wl_output::WlOutput,
    pub layer_surface: LayerSurface,
    pub renderer: SurfaceRenderer,
    pub width: u32,
    pub height: u32,
    pub scale_factor: i32,
}

impl MonitorSurface {
    pub fn new(
        qh: &QueueHandle<WaylandAppState>,
        output: &wl_output::WlOutput,
        compositor: &CompositorState,
        layer_shell: &LayerShell,
        render_context: &RenderContext,
        display_ptr: *mut std::ffi::c_void,
    ) -> anyhow::Result<Self> {
        // 1. Create Wayland surface
        let surface = compositor.create_surface(qh);

        // 2. Set empty input region so mouse clicks pass through 100% to desktop & windows
        let empty_region = compositor.wl_compositor().create_region(qh, ());
        surface.set_input_region(Some(&empty_region));
        empty_region.destroy();

        // 3. Create Layer Shell overlay surface
        let layer_surface = layer_shell.create_layer_surface(
            qh,
            surface,
            Layer::Overlay,
            Some("niri-vibe-glow"),
            Some(output),
        );

        // 4. Anchor to all four edges for fullscreen ambient edge coverage
        layer_surface.set_anchor(Anchor::TOP | Anchor::BOTTOM | Anchor::LEFT | Anchor::RIGHT);
        layer_surface.set_exclusive_zone(0);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::None);
        layer_surface.commit();

        // 5. Create wgpu surface renderer
        let surface_ptr = layer_surface.wl_surface().id().as_ptr() as *mut std::ffi::c_void;
        let wgpu_surface = render_context.create_surface_for_wayland(display_ptr, surface_ptr)?;
        let renderer = SurfaceRenderer::new(render_context, wgpu_surface, 1920, 1080);

        Ok(Self {
            output: output.clone(),
            layer_surface,
            renderer,
            width: 1920,
            height: 1080,
            scale_factor: 1,
        })
    }

    pub fn resize(&mut self, context: &RenderContext, width: u32, height: u32) {
        if width > 0 && height > 0 {
            self.width = width;
            self.height = height;
            let physical_w = width * (self.scale_factor.max(1) as u32);
            let physical_h = height * (self.scale_factor.max(1) as u32);
            self.renderer.configure(context, physical_w, physical_h);
        }
    }

    pub fn set_scale_factor(&mut self, context: &RenderContext, scale: i32) {
        self.scale_factor = scale.max(1);
        self.resize(context, self.width, self.height);
    }
}
