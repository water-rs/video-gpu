# Changelog

All notable changes to `waterui-video-gpu` are documented in this file.

## [Unreleased]

## [0.5.0](https://github.com/water-rs/video-gpu/compare/v0.4.0...v0.5.0) - 2026-11-14

### Added

- port to the render-target-neutral recording contract
- [**breaking**] port the video player to Cherenkov external frames

### Fixed

- *(android)* read the playback policy through its accessors
- *(player)* a failure ends buffering without BufferingEnded
- adapt to waterkit async picture-in-picture enter
- *(deps)* repin waterui at the passthrough-shader device fix
- *(lint)* gate macOS-only test helpers
- *(deps)* repin waterkit to dev and use software-decode
- use mem::take for consume-self TrackCatalog updates; pin all waterkit crates
- migrate gated runtime_player signal reads; repin to unified migration heads
- *(ci)* make the MSRV job build with the declared floor ([#30](https://github.com/water-rs/video-gpu/pull/30))

### Other

- *(deps)* point migrated Batch 2 git dependencies to main ([#69](https://github.com/water-rs/video-gpu/pull/69))
- update release-plz rev for Rust 1.100 compatibility
- release from main and retire dev ([#64](https://github.com/water-rs/video-gpu/pull/64))
- restore the Hydrolysis test fonts from the Actions cache ([#63](https://github.com/water-rs/video-gpu/pull/63))
- *(deps)* point migrated Batch 1 git dependencies to main ([#60](https://github.com/water-rs/video-gpu/pull/60)) ([#61](https://github.com/water-rs/video-gpu/pull/61))
- *(android)* take the NDK location from the runner image
- import frames through waterui_graphics::gpu
- follow waterui dev again
- resolve gpu-allocator against the windows version wgpu-hal uses
- lock the wgpu fork at the revision the framework builds DX12 with
- build frame times with FrameTime::now
- follow waterui dev's toolchain floor and windows resolution
- read waterui structs through their accessors
- match the non-exhaustive PlaybackPowerPolicy with a failing wildcard
- consume the framework and image from their dev branches
- lock waterkit 0.2 and the migrated framework
- [**breaking**] move to waterkit 0.2
- consume the framework from its dev branch
- lock the framework at its rebased nami 0.13 head
- [**breaking**] move to nami 0.13 and the migrated framework
- name the pinned framework revision in the patch table's comment
- pin the framework at 60aecf054
- a Fit picture keeps its source's aspect through fit_video
- move to shaderloom 0.2.1 for the explicit Metal target
- pass the release pull request's gate without CI
- follow the fallible renderer constructors and frame-timed present
- [**breaking**] move the patch table to nami 0.12
- require nami 0.12
- install Hydrolysis test fonts before tests
- target the engine's Apple deployment floor
- name the framework's patch table as the wgpu fork's source
- *(deps)* drop patch entries nothing in the graph uses
- link the GPU engine unconditionally
- restore the cross-platform spherical video visual
- *(deps)* bump hydrolysis pin to a833de9
- pin cherenkov to 52236561
- install SPIRV-Tools through the shared Linux deps action
- install SPIRV-Tools for cherenkov-gpu's shader build on non-Apple legs
- refresh Cargo.lock to the manifest's git pins
- *(deps)* pin waterui and hydrolysis-m3 at their delivered heads
- *(deps)* pin hydrolysis at its final head
- *(deps)* pin hydrolysis-m3 at its final head
- *(deps)* repin the chain at the rewritten waterui and cherenkov fd1e3666
- *(deps)* pin waterui and hydrolysis-m3 at the merge-fix revs
- *(deps)* pin m3's self-consistent head and the merged waterui head
- *(deps)* pin cherenkov at the self-contained testing fix
- *(deps)* pin waterui at the merged-branch head
- *(deps)* repin the graph at cherenkov dev f2209fb4 and merged waterui
- repin the vello fork to the glifo canonical-location fix
- repin water-rs dependencies to merged dev heads
- repin water-rs dependencies to unified migration heads
- repin water-rs dependencies to unified migration heads
- repin hydrolysis to accessibility import fix
- refresh lockfile for final branch revs
- repin migrated dependency branch heads
- rustfmt on migrated files
- pin hydrolysis-m3 to the migrated branch
- [**breaking**] migrate to nami snapshot API
- consume the 0.5.0 framework wave from crates.io ([#29](https://github.com/water-rs/video-gpu/pull/29))

## [0.3.1](https://github.com/water-rs/video-gpu/compare/v0.3.0...v0.3.1) - 2026-09-11

### Added

- *(testing)* [**breaking**] quiescence-driven waits, virtual frame clock, orthogonal theme/mode, panicking interactions

### Fixed

- *(ci)* open the release pull request instead of releasing twice ([#9](https://github.com/water-rs/video-gpu/pull/9))
- *(video)* give the spherical projection uniform its own bind group ([#7](https://github.com/water-rs/video-gpu/pull/7))
- *(ci)* release with the water-rs release-plz fork and the shared Linux deps
- *(ci)* install the same Linux packages for the release preflight
- *(testing)* install self-drawn realizations in the test harness env
- *(release)* verify registry-only package graph
- *(android)* unblock Pixel example execution
- *(ci)* gate the 10-bit visual on adapter capability and unblock two red jobs

### Other

- link the test graph to the waterui 0.4 release commit
- *(deps)* waterui-graphics 0.4 (and waterui-text/-testing 0.4 where used)
- update Linux package matrix and add dxc on Windows
- setup standalone crate files, CI workflows, and release-plz
- ship the licence texts in every published crate
- depend on shaderloom directly, and give the icon codegen its own name
- prepare WaterUI 0.3 release versions
- Fix complete Hydrolysis Web build
- *(video)* [**breaking**] rename the video AspectRatio mode to ContentMode
- *(tests)* [**breaking**] migrate hand-written builder tests to #[waterui::test]
- Fix workspace CI failures
- Fix Android runtime and device workflows
- Remove premature heap allocations
- Make reactivity precise across renderers
- upgrade workspace dependencies
- Add cross-platform shader AOT with Shaderloom
- deliver modular cross-platform video player

## [0.3.0] - 2026-08-25

- Added the portable GPU video realization with WaterKit demuxing, codecs, audio, and streaming integration.
