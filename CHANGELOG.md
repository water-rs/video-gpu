# Changelog

All notable changes to `waterui-video-gpu` are documented in this file.

## [Unreleased]

## [0.4.0](https://github.com/water-rs/video-gpu/compare/v0.3.0...v0.4.0) - 2026-09-11

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
