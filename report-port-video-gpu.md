# port-video-gpu — stop-and-report: missing entry point for zero-copy external frames

**Status: stopped per the brief's rule 3** ("If the Cherenkov API at your pins lacks something that zero copy needs, stop and report the exact missing entry point with a proposed signature. Do not work around it with a copy.").

The port cannot produce the required presentation with the APIs available at the pinned revisions. One entry point is missing: **there is no way for a component to install a `cherenkov_gpu::interop::ExternalFrame` as engine layer content**. Everything else needed for zero copy exists at the pins.

## What exists at the pins (verified in source)

- `cherenkov_gpu::interop::ExternalFrame` — `ExternalFrame::yuv(y, uv, FrameColor)` for `R8Uint`/`Rg8Uint` (NV12) and `R16Uint`/`Rg16Uint` (P010) planes, `ExternalFrame::rgb(...)`, validated `FrameColor` (matrix, range, chroma siting, primaries, transfer, reference white, HLG peak). `FrameSync::Metal` GPU-side shared-event wait, Apple-only. (`cherenkov@a7708216`, `gpu/src/interop.rs`)
- `cherenkov_gpu::interop::metal::import_texture(device, raw MTLTexture, format) -> wgpu::Texture` — in-place wgpu-hal import of an `IOSurface`/`CVPixelBuffer` plane, no copy (cherenkov #165, merged at `a7708216`).
- `Engine::external_frame(frame) -> ExternalFrameHandle` and `LayerContent::from(handle)` → `tx[&layer].content(handle)`, which calls `Gpu::set_external_frame` — the layer's content *is* the frame, engine does the YUV→RGB decode and tone mapping (`gpu/src/render/external.rs`, `external.wgsl`), and the layer is promotable under cherenkov #90.
- Android leg at `026b5c7` (branch `feat/166-vulkan-external-frames`, linear descendant of `a7708216`): `FramePlanes::Native(vulkan::Frame)`, `ExternalFrame::native(frame)`, `interop::vulkan::{Device, Ahb, DmaBuf, FrameSource}` — `AHardwareBuffer`/dmabuf import as native planes (#166).
- `GpuRuntime` is reachable from `Environment` (`env.get::<GpuRuntime>()`, shared device instance/adapter/device/queue) and `GpuRuntime::engine()` creates an `Engine<Gpu>` on the shared device — public API.

## The missing entry point

A hosted `GpuContentView` reaches the engine only as a **draw-into-attachment producer**:

1. `GpuContent::render(&mut self, frame: &mut Frame<'_>)` receives only `device`, `queue`, `texture`, `view`, `format`, `width`, `height`, `scale`, `elapsed`, `delta` plus `request_redraw`. There is no engine, surface, layer, or transaction handle. (`waterui-graphics@ad1492299`, `gpu/mod.rs`)
2. The hosted chain is fixed: `GpuContentView` → `take_engine_content` → `cherenkov_gpu::interop::GpuContentBox` → FFI `WuiGpuContent` → `WuiGpuContentState` → `GpuContentRenderer::new(...)`, which does `tx[surface.root()].content(engine.gpu_content(pixels, content))` and presents the retained working texture (`presenter.texture`) to the native view. The root layer's content kind is always `GpuContent`. (`waterui-graphics` `gpu/runtime.rs`, `waterui-ffi` `components/visual/gpu_content.rs`)
3. `Engine::external_frame` + `tx[&layer].content(handle)` requires owning `Engine`/`Surface`/`Layer` — none is exposed to a component. `SceneContent`/`RecordingResources` cannot record external frames either (only `fill`/`stroke`/`shadow`/`glyphs`/`image`/`picture`/`clip`/`transform`/`group`; resources are `font`/`image`/`image16f`/`shader` only). No `ExternalFrameView`, FFI type, or `GpuContent::render -> ExternalFrame` variant exists at `ad1492299` or on any staging ref (`w3-r3`, `review-w3r2`, `review-1325`, `dev`).

## Why the workarounds are all ruled out

- **Draw imported planes into `frame.texture` with a quad**: zero plane copies, but the quad needs a YUV→RGB shader — the engine's decode lives in the private `render::external` module (its `Params` layout and pipeline are `pub(crate)`), so this would mean re-creating `video_yuv.wgsl`, which the maintainer explicitly forbade ("the YUV→RGB conversion happens inside the engine").
- **Nested private engine inside `GpuContent::render`**: `GpuRuntime::engine()` + `Surface<TextureTarget>` + `tx[root].content(external_frame)` is constructible from the env `GpuRuntime`, but the surface's working texture is engine-owned (no target accepts a caller texture), so presenting into `frame.texture` needs a full-screen blit every frame — one intermediate texture the requirement disallows, plus a whole extra engine/surface per view.
- **Component-owned `Engine`+`Surface` as its own native host**: the FFI only presents `GpuContentView` through `GpuContentRenderer`; there is no `NativeView` extensibility for a custom external-frame surface, and `interop::apple::LayerTarget` (system-compositor parent for #90) does not exist yet.

## Proposed signature (smallest addition that fits the existing shape)

Mirror the `GpuContent`/`GpuContentView`/`GpuContentRenderer` trio with an external-frame twin. The cherenkov side needs nothing new for the hosted path — `engine.external_frame` + `tx` already work.

```rust
// waterui_graphics::gpu — sibling of GpuContent
/// A producer of engine external frames for the layer that hosts it
/// (video decoders, camera streams, web content).
pub trait ExternalFrameContent: Send + 'static {
    /// Creates persistent resources once, on the render thread.
    fn setup(&mut self, gpu: &Context<'_>);
    /// Answers the frame the layer samples this pass, called on the
    /// render thread ahead of each engine frame; `None` keeps the
    /// previously installed frame.
    fn next_frame(&mut self) -> Option<cherenkov_gpu::interop::ExternalFrame>;
    fn is_opaque(&self) -> bool { true }
    fn intrinsic_size(&self) -> Option<Size> { None }
    fn measure(&self, proposal: ProposalSize) -> ViewDimensions;
    fn preferred_surface_hdr(&self) -> Option<bool> { None }
}

// GpuContentView twin — same label/value/HDR/input/measure surface,
// consumed by the FFI the same way.
pub struct ExternalFrameView { /* ... */ }

// GpuContentRenderer twin in gpu::runtime: owns engine+surface+presenter;
// per frame drains next_frame() and does
//   surface.update(|tx| tx[root].content(engine.external_frame(f)))
// then engine.render + present — so the layer's content kind is
// ExternalFrames and eligible for cherenkov-#90 promotion.
pub struct ExternalFrameRenderer { /* ... */ }
```

FFI surface: either a `WuiExternalFrameContent` descriptor + `waterui_external_frame_*` entry points, or a content-kind tag on `WuiGpuContent` so `WuiGpuContentState::render_into` picks `ExternalFrameRenderer`. Both are waterui-side changes; backends need the same small hook GpuContentView got.

Alternative (engine-native form, if a component-owned `Surface` should not be required): a producer-install in `cherenkov_gpu::interop` mirroring `GpuContentBox` —

```rust
pub trait ExternalFrameProducer: cherenkov::RenderTransfer + 'static {
    fn next_frame(&mut self) -> Option<ExternalFrame>;
}
pub struct ExternalFrameProducerBox { /* producer + RedrawHandle */ }
// installable as layer content; the engine polls next_frame() on the
// render thread and set_external_frame()s the result on the owning layer.
```

That still needs the thin `ExternalFrameView` → box → FFI bridge in waterui, but moves the frame poll into the engine (nicer for backends that embed GPU content inside their own scene tree, e.g. hydrolysis' retained layers).

## Evidence for the counter once the API lands

`GpuConfig::alloc_diag` and the engine's own texture accounting make the zero-copy claim directly observable; planned check: a test content that imports one NV12 frame and asserts (a) no `copyToTexture`/blit in the pass, (b) exactly one `set_external_frame` per layer, (c) the frame's planes are the IOSurface-backed `wgpu::Texture`s — plus a Metal GPU capture diff on this VM.

## Pins confirmed for the port

- waterui-*: `ad14922997f28686d04f59f79e84239183524bf7` (`refs/staging/w3-int`)
- waterkit-*: `28dddaefcd043a6f72fbf7c175e971377803f8cf`
- shaderloom: `75a4f0d` (replaces both the `[dependencies]` and `[build-dependencies]` entries)
- wgpu-external-frame: `d047b57e6fd8930f95c78b3e4fba7b06cd056b68`
- cherenkov/cherenkov-cpu/cherenkov-gpu/cherenkov-shader/filtrate/filtrate-core/filtrate-derive: `a7708216db67bbf976e1fe36429a6a54cf82ba8a` from waterui's `Cargo.lock` — expressed as `[patch.crates-io]` git pins in video-gpu's manifest (waterui declares them as `"0.0.0"`/`"0.2.x"` version reqs and relies on the consumer's patch table, so video-gpu's `[patch]` is what unifies them)
- cherenkov Android leg: `026b5c7` via `[target.'cfg(target_os = "android")'.patch.crates-io]` (the syntax parses; will verify `cargo tree --target aarch64-linux-android` resolves it)
- vello pins (`vello`, `vello_hybrid`, `vello_common`, `vello_sparse_shaders`, `glifo`) drop entirely; `cargo metadata` must show no vello package.

## What is blocked vs. independent

Blocked on the entry point above: the actual port of `runtime_player.rs`, deleting `copy_surface_planes`/Y/UV textures/`video_yuv.wgsl`, external-frame production from `DecodedVideoFrame` (CVPixelBuffer → `metal::import_texture` → `ExternalFrame::yuv` on Apple; `AHardwareBuffer` → `vulkan::Device`/`ExternalFrame::native` on Android; software frames → one `queue.write_texture` into engine-owned planes → `ExternalFrame::yuv`), `FrameColor` mapping from `VideoColorInfo`, and the `VideoSurface` view realization.

Not blocked (can proceed on request, but commits would not build standalone and are deferred rather than left half-done): the `Cargo.toml` repin described above, vello removal, and the before/after PNG pair generation for the existing snapshot scenes at `origin/dev`.
