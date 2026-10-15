// niri-vibe Lumn-style ambient edge glow shader
// Fullscreen pass-through with dual-tone perimeter wave drift,
// 4-corner rounded-box SDF blending, dual-pass bloom & radiant core,
// and hardware-accelerated premultiplied alpha.

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
};

struct GlowUniforms {
    resolution: vec2<f32>,
    thickness: f32,
    intensity: f32,
    primary_color: vec4<f32>,
    secondary_color: vec4<f32>,
    time: f32,
    speed: f32,
    corner_radius: f32,
    direction: f32,
};

@group(0) @binding(0)
var<uniform> uniforms: GlowUniforms;

@vertex
fn vs_main(@builtin(vertex_index) in_vertex_index: u32) -> VertexOutput {
    var out: VertexOutput;
    // Generate fullscreen triangle covering NDC [-1.0, 1.0]
    let x = f32(i32(in_vertex_index & 1u) * 4 - 1);
    let y = f32(i32(in_vertex_index & 2u) * 2 - 1);
    out.position = vec4<f32>(x, y, 0.0, 1.0);
    out.uv = vec2<f32>((x + 1.0) * 0.5, (1.0 - y) * 0.5);
    return out;
}

// Compute inward distance from the rounded rectangle screen boundary
fn rounded_box_inward_distance(p: vec2<f32>, size: vec2<f32>, r: f32) -> f32 {
    let d_edges = min(min(p.x, size.x - p.x), min(p.y, size.y - p.y));

    // Check four corners
    let is_tl = p.x < r && p.y < r;
    let is_tr = p.x > (size.x - r) && p.y < r;
    let is_bl = p.x < r && p.y > (size.y - r);
    let is_br = p.x > (size.x - r) && p.y > (size.y - r);

    if (is_tl) {
        return r - length(vec2<f32>(r - p.x, r - p.y));
    }
    if (is_tr) {
        return r - length(vec2<f32>(p.x - (size.x - r), r - p.y));
    }
    if (is_bl) {
        return r - length(vec2<f32>(r - p.x, p.y - (size.y - r)));
    }
    if (is_br) {
        return r - length(vec2<f32>(p.x - (size.x - r), p.y - (size.y - r)));
    }

    return d_edges;
}

// Normalized perimeter coordinate [0.0, 1.0] for traveling wave drift
fn perimeter_coord(p: vec2<f32>, size: vec2<f32>) -> f32 {
    let w = size.x;
    let h = size.y;
    let total_perim = 2.0 * (w + h);

    let d_top = p.y;
    let d_right = size.x - p.x;
    let d_bottom = size.y - p.y;
    let d_left = p.x;

    let min_d = min(min(d_top, d_right), min(d_bottom, d_left));

    if (min_d == d_top) {
        return p.x / total_perim;
    } else if (min_d == d_right) {
        return (w + p.y) / total_perim;
    } else if (min_d == d_bottom) {
        return (w + h + (w - p.x)) / total_perim;
    } else {
        return (2.0 * w + h + (h - p.y)) / total_perim;
    }
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let p = in.position.xy;
    let size = uniforms.resolution;
    let r = uniforms.corner_radius;

    let dist = rounded_box_inward_distance(p, size, r);

    // Dynamic bloom expansion on heavy bass
    let max_bloom_depth = uniforms.thickness * (1.0 + uniforms.intensity * 0.55);

    // Center screen interior: completely transparent (zero GPU cost)
    if (dist > max_bloom_depth || dist < 0.0) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }

    // Normalized perimeter coordinate and continuous dual-tone wave drift
    let s = perimeter_coord(p, size);
    let wave_phase = fract(s * uniforms.direction + uniforms.time * uniforms.speed * 0.15);
    let wave_factor = (cos(wave_phase * 6.2831853) + 1.0) * 0.5;

    // Smooth dual-tone color interpolation
    let edge_color = mix(uniforms.secondary_color.rgb, uniforms.primary_color.rgb, wave_factor);

    // ===== PASS 1: Atmospheric Bloom Spill (deep soft inward wash) =====
    let t_bloom = clamp(dist / max_bloom_depth, 0.0, 1.0);
    let bloom = pow(1.0 - t_bloom, 2.2) * 0.70;

    // ===== PASS 2: Luminous Radiant Core (rich, vibrant luminescence hugging border) =====
    let core_depth = max_bloom_depth * 0.38;
    let t_core = clamp(dist / core_depth, 0.0, 1.0);
    let core = pow(1.0 - t_core, 1.5) * 0.90;

    // Composite total luminescence scaled by real-time bass intensity
    let total_lum = (bloom + core) * clamp(uniforms.intensity, 0.0, 1.0);
    let alpha = clamp(total_lum, 0.0, 1.0);

    // Premultiplied alpha output for compositor composition
    return vec4<f32>(edge_color * alpha, alpha);
}
