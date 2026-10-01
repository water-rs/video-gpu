// Video warp shader: draws a linear RGBA16F video frame (sRGB primaries,
// 203-nit reference white, produced by the codec's `LinearRgbaConverter`)
// either through the equirectangular spherical projection or through the
// aspect-fill crop window, and emits linear Display P3, the engine's
// working space.

struct WarpParams {
    crop: vec4<f32>,
    yaw_radians: f32,
    pitch_radians: f32,
    vertical_field_of_view_radians: f32,
    stereo_layout: u32,
    surface_aspect_ratio: f32,
    mode: u32,
    _padding0: u32,
    _padding1: u32,
}

@group(0) @binding(0) var warp_frame: texture_2d<f32>;
@group(0) @binding(1) var warp_sampler: sampler;
@group(0) @binding(2) var<uniform> warp: WarpParams;

const WARP_FILL: u32 = 0u;
const WARP_SPHERICAL: u32 = 1u;
const SPHERICAL_MONO: u32 = 0u;
const SPHERICAL_TOP_BOTTOM: u32 = 1u;
const SPHERICAL_LEFT_RIGHT: u32 = 2u;
const PI: f32 = 3.141592653589793;
const TAU: f32 = 6.283185307179586;

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

fn spherical_sample_coordinates(screen_uv: vec2<f32>) -> vec2<f32> {
    var eye_index = 0u;
    var eye_uv = screen_uv;
    var eye_aspect_ratio = warp.surface_aspect_ratio;
    if warp.stereo_layout != SPHERICAL_MONO {
        eye_index = select(0u, 1u, screen_uv.x >= 0.5);
        eye_uv.x = fract(screen_uv.x * 2.0);
        eye_aspect_ratio *= 0.5;
    }

    let tangent = tan(warp.vertical_field_of_view_radians * 0.5);
    let screen = vec2<f32>(eye_uv.x * 2.0 - 1.0, 1.0 - eye_uv.y * 2.0);
    let camera_ray = normalize(vec3<f32>(
        screen.x * tangent * eye_aspect_ratio,
        screen.y * tangent,
        -1.0,
    ));

    let pitch_sine = sin(warp.pitch_radians);
    let pitch_cosine = cos(warp.pitch_radians);
    let pitched = vec3<f32>(
        camera_ray.x,
        camera_ray.y * pitch_cosine - camera_ray.z * pitch_sine,
        camera_ray.y * pitch_sine + camera_ray.z * pitch_cosine,
    );
    let yaw_sine = sin(warp.yaw_radians);
    let yaw_cosine = cos(warp.yaw_radians);
    let world_ray = vec3<f32>(
        pitched.x * yaw_cosine + pitched.z * yaw_sine,
        pitched.y,
        -pitched.x * yaw_sine + pitched.z * yaw_cosine,
    );

    let longitude = atan2(world_ray.x, -world_ray.z);
    let latitude = asin(clamp(world_ray.y, -1.0, 1.0));
    var source_uv = vec2<f32>(0.5 + longitude / TAU, 0.5 - latitude / PI);
    if warp.stereo_layout == SPHERICAL_TOP_BOTTOM {
        source_uv.y = source_uv.y * 0.5 + f32(eye_index) * 0.5;
    } else if warp.stereo_layout == SPHERICAL_LEFT_RIGHT {
        source_uv.x = source_uv.x * 0.5 + f32(eye_index) * 0.5;
    }
    return source_uv;
}

fn srgb_to_p3(linear_rgb: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(
        0.822478 * linear_rgb.r + 0.177389 * linear_rgb.g + 0.000134 * linear_rgb.b,
        0.033153 * linear_rgb.r + 0.966929 * linear_rgb.g - 0.000082 * linear_rgb.b,
        0.017125 * linear_rgb.r + 0.072380 * linear_rgb.g + 0.910495 * linear_rgb.b,
    );
}

@vertex
fn vs_warp(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    var positions = array<vec2<f32>, 6>(
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(-1.0, 1.0),
        vec2<f32>(-1.0, 1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(1.0, 1.0),
    );
    let position = positions[vertex_index];
    var output: VertexOutput;
    output.position = vec4<f32>(position, 0.0, 1.0);
    output.uv = vec2<f32>(position.x * 0.5 + 0.5, 0.5 - position.y * 0.5);
    return output;
}

@fragment
fn fs_warp(input: VertexOutput) -> @location(0) vec4<f32> {
    var sample_uv = input.uv;
    if warp.mode == WARP_FILL {
        sample_uv = input.uv * warp.crop.zw + warp.crop.xy;
    } else {
        sample_uv = spherical_sample_coordinates(input.uv);
    }
    let sample = textureSample(warp_frame, warp_sampler, sample_uv);
    return vec4<f32>(srgb_to_p3(sample.rgb), sample.a);
}
