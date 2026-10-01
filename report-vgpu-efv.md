# vgpu-efv — video-gpu ported to the Cherenkov ExternalFrameView API

Four repositories, one bundle each. `port-video-gpu` for video-rs/video-gpu issue #34: zero-copy external-frame presentation on the `ExternalFrameView` bridge built at `water-rs/waterui@ab667e569` (`refs/staging/efv-r9`), which is the option-(a) API this session's earlier stop-and-report proposed.

## Repositories and pins

| repo | branch | commit | bundle base |
|---|---|---|---|
| water-rs/video-gpu | `feat/cherenkov-port` | `c4f68918aa1fec77b4637779543bba19f5fef1c6` | `origin/dev` (`01f3d3f`) |
| water-rs/waterkit | `build/efv-frames` | `2f2214bb384e3a54160089ce53eaa9db1387d237` | `origin/dev` (`d266ae5`) |
| water-rs/cherenkov | `fix/external-frame-decode` | `9a8d81d` | `8d00976e` |
| water-rs/waterui | `build/vgpu-efv-pin` | `6402e80c6` | `ab667e569` |

Pins inside `video-gpu/Cargo.toml`: waterui-* `ab667e569f65a96ba675b9228b84516646c0ee6b`, waterkit-* `2f2214bb384e3a54160089ce53eaa9db1387d237`, cherenkov/cherenkov-*/filtrate* `8d00976e5a68f3ac2e99d9265d3246b1a7c29ad6` (`[patch.crates-io]`), wgpu `30.0.1`, wgpu-external-frame `d047b57e6fd8930f95c78b3e4fba7b06cd056b68`, shaderloom `84c37c8`, hydrolysis `2da1ec9`, hydrolysis-m3 `f04ec61`, nami `f1db501`. **Android leg:** `cherenkov/cherenkov-gpu` are pinned to `026b5c7` (branch `feat/166-vulkan-external-frames`) under `[target.'cfg(target_os = "android")'.patch.crates-io]` — the AHardwareBuffer import of cherenkov #166; a linear descendant of `8d00976e`, so the graph still has exactly one copy of each engine crate per target.

## What changed and why

### water-rs/video-gpu (`feat/cherenkov-port`, one commit `c4f68918`)

- `src/runtime_player.rs` — the decoder drain now hands every decoded frame to `waterkit_codec::frame::gpu::DecodedFrameUploader` and presents the resulting `ExternalFrame` through `FrameOutput::present`. The frame's colour space, range, chroma siting, primaries, transfer, reference white and HLG peak travel inside `FrameColor`; the engine does the YUV→RGB decode and tone mapping in its own pipeline. Deleted: the player's Y/UV textures, the `copy_surface_planes` copy, and `video_yuv.wgsl`.
- `ExternalFramePresenter` implements `ExternalFrameSource` (`start(FrameOutput)`, `is_opaque`, `intrinsic_size`, `measure`, `preferred_surface_hdr` for HDR content). Retired outputs are detected via `is_retired()`/`RetiredOutput`; the presenter reseats on the next `start` after a rebuild or device loss.
- The video is a plain external-frame layer produced by `ExternalFrameView::new(...)` — no non-default blend, no backdrop effect, no clip the system layer cannot express, so it stays promotion-eligible under cherenkov #90. Controls/overlays remain ordinary WaterUI views in sibling layers. The Android decoder video plane (`android_video_surface.rs`) keeps its role for protected content. No component-side compositor path.
- Spherical/equirectangular playback keeps a `GpuContentView` leg: equirect projection is a view transform, not a frame conversion, so it renders through the private `ExternalFrameRenderer` host with the ported `spherical_video_render.wgsl`.
- Vello and the retired `GpuContext`/`GpuSurface`/`GpuView`/`GpuFrame` API are gone from source and resolved metadata; `vello*`/`glifo` pins dropped.
- `#[cfg(test)] plane_counters()` exposes the uploader's `(imported, uploaded)` counters.

### water-rs/waterkit (`build/efv-frames`, `2f2214b` on top of `origin/dev` wgpu-30)

- `multimedia/codec/src/frame/gpu.rs` — `DecodedFrameUploader` gained `imported_frames`/`uploaded_frames` counters with `pub const fn` accessors. Hardware arm → `imported += 1` after the in-place native import (Apple: IOSurface → `CVMetalTextureCache` → `metal::import_texture`, zero copy); Software arm → `uploaded += 1` after exactly one `queue.write_texture` per plane into engine-owned textures. These counters are the zero-copy witness the video-gpu test asserts.

### water-rs/cherenkov (`fix/external-frame-decode`, `9a8d81d` on `8d00976e`)

Three decode bugs the snapshot PNGs exposed (cherenkov AGENTS.md: consumer-found engine bugs become engine changes, not consumer workarounds):

1. `gpu/src/render/external.wgsl` — `box_shape` centres emitted quads so `in.local` spans `[-w/2, w/2]`, but the luma/chroma/RGB arms sampled `[0, w]` → left-half smear on every external frame. Now `let frag = in.local + params.dims.xy * 0.5;` (chroma arm additionally `frag * 0.5 + 0.25 - site * 0.5` for siting).
2. Same file — P010 lanes arrive as `code << 6`; the decode multiplied by the shift instead of dividing (`f32(y4.x) / shift`). Also wrong at dev head `e36e0dd`.
3. `gpu/src/render/external.rs` — PQ `value_scale` used the wrong scaling; now `Transfer::Pq => 10_000.0 / color.reference_white` (already fixed at dev head; backported so the `8d00976e` pin renders PQ correctly).

### water-rs/waterui (`build/vgpu-efv-pin`, `6402e80c` on `ab667e569`)

- `Cargo.toml`/`Cargo.lock` — `waterui-video-gpu` pin moved to `c4f68918`; `wgpu-external-frame` repinned to git `d047b57` (the crates.io 0.1.1 release still builds against wgpu 29 and left `waterui-browser-cef` mixing two wgpu versions — an upstream incoherence at this base that blocked the header expansion).
- `ffi/waterui.h` — regenerated with the CI-pinned `nightly-2026-09-09` via `ffi/generator` (all four expansion targets provisioned per `.github/actions/ffi-header/provision-cross-target-deps.sh`). The retired `GpuContext`/`GpuSurface`/`GpuView` exports are replaced by the `WuiExternalFrame` surface (`waterui_external_frame_id`, `waterui_external_frame_create`, `waterui_force_as_external_frame`).

## Zero-copy evidence (this VM's Metal GPU)

`DecodedFrameUploader` counts in-place imports vs texture uploads. The GPU test decodes one VideoToolbox frame (hardware path on this VM) and asserts `imported == 1 && uploaded == 0` — the planes reach the engine as the decoder's IOSurface-backed textures; no `copy_surface_planes`, no intermediate texture, no component Y/UV textures exist in the build at all.

## Gates (all on this VM, stable `rustc 1.98.1`, Metal)

- video-gpu: `cargo check` clean; `cargo clippy` clean; `cargo fmt` clean; lib tests **31/31 pass** against the cherenkov fix branch, including the counter assertions above.
- waterkit-codec: `cargo check` / `cargo clippy --all-targets -- -D warnings` / `cargo fmt` clean.
- cherenkov-gpu: `cargo check` / `cargo clippy` / `cargo test` / `cargo fmt` clean.
- waterui: `cargo check -p waterui-internal --features video-gpu` clean (the pinned port compiles inside the waterui graph); `cargo clippy -p waterui-ffi --features video -- -D warnings` clean; `ffi/waterui.h` regenerated and committed.
- Snapshot PNGs attached (`pngs/`): `nv12_bt709_sdr.after.png` (SDR BT.709), `playback_bt709_sdr.after.png` (mid-playback SDR), `playback_bt2020_pq.after.png` (mid-playback HDR PQ, HDR10→SDR tone-mapped), `p010_bt2020_pq_hdr10_to_sdr.after.png` (P010 10-bit leg), `nv12_equirectangular_mono.after.png` (spherical leg). Each was visually verified: correct colour, no smear after the centered-local fix, no PQ over-brightening.

## Upstream incoherences at this base (not mine, documented for the reviewer)

- `waterui-testing` (hydrolysis `2da1ec9` under the `ab667e569` graph) has compile errors (`AccessibilityActivationPointError`, missing `accessibility_activation_point`), so `tests/e2e_semantics.rs` — which needs `hydrolysis_m3` + `waterui_testing` — cannot build at delivery pins. The manifest keeps the dev-deps declared; the 31 lib tests were verified with the test manifest's dev-deps commented. `cargo test` at delivery pins therefore fails to *build* the e2e target upstream of this port.
- `waterui-browser-cef` needed the `wgpu-external-frame` repin described above (pre-existing wgpu 29/30 mix).

## Device checks for the reviewer (Pixel 9 Pro)

1. Play SDR BT.709 and HDR (PQ/HLG) content: the video appears through the external-frame layer with correct colour/range; overlays stay in sibling layers above it.
2. Attach a GPU trace (or AGI/RenderDoc): a hardware-decoded `AHardwareBuffer` frame reaches the layer with zero texture copies — the cherenkov-#166 import path pinned at `026b5c7`.
3. DRM/protected content: the `android_video_surface.rs` decoder plane still serves it (unchanged).
4. Rotation/resize and overlay toggling: the layer samples the newest mailboxed frame; no stale plane after `RetiredOutput` reseats (leave/return to app or rebuild the view).
