//! Self-drawn GPU realization for `WaterUI` video components.

#[cfg(target_os = "android")]
mod android_video_surface;
mod decoder_worker;
mod latest_channel;
mod runtime_player;

use shaderloom::CompiledShader;
// `include_compiled_spirv!` names `wgpu` at the expansion site on non-Apple,
// non-wasm targets; the re-export keeps it resolving without a direct `wgpu`
// dependency.
#[cfg(all(not(target_vendor = "apple"), not(target_arch = "wasm32")))]
use waterui_graphics::gpu::wgpu;

const SPHERICAL_VIDEO_SHADER: CompiledShader =
    include!(concat!(env!("OUT_DIR"), "/spherical_video.rs"));

#[cfg(target_os = "android")]
#[doc(hidden)]
pub use android_video_surface::{AndroidVideoSurfaceBridge, AndroidVideoSurfaceHost};

use waterkit_audio::{AudioDevice, AudioOutput, PlayerError};
use waterkit_video::{AnyLicenseServer, LicenseServer, ZenwaveLicenseServer};
use waterui_core::{Binding, binding};

/// Configuration for self-drawn video playback.
///
/// An application inserts it into the environment; without it the player
/// follows the platform's default audio route and license server.
#[derive(Debug, Clone)]
pub struct VideoGpuOptions {
    pub(crate) audio_output: AudioOutput,
    pub(crate) skip_silence: Binding<bool>,
    pub(crate) license_server: AnyLicenseServer,
}

impl VideoGpuOptions {
    /// Creates options that follow the platform's default audio route.
    #[must_use]
    pub fn new() -> Self {
        Self {
            audio_output: AudioOutput::system_default(),
            skip_silence: binding(false),
            license_server: AnyLicenseServer::new(ZenwaveLicenseServer),
        }
    }

    /// Routes video audio through the selected `WaterKit` output.
    #[must_use]
    pub fn audio_output(mut self, output: AudioOutput) -> Self {
        self.audio_output = output;
        self
    }

    /// Binds sustained-silence shortening for decoded PCM playback.
    ///
    /// The audio presentation clock advances across removed samples, so both
    /// progressive and segmented video remain synchronized while silence is skipped.
    #[must_use]
    pub fn skip_silence(mut self, enabled: &Binding<bool>) -> Self {
        self.skip_silence = enabled.clone();
        self
    }

    /// Replaces the platform-CDM challenge transport.
    ///
    /// The default implementation sends bounded requests exclusively through
    /// Zenwave. A custom server can add application authentication or route
    /// challenges through an application-owned service.
    #[must_use]
    pub fn license_server(mut self, server: impl LicenseServer) -> Self {
        self.license_server = AnyLicenseServer::new(server);
        self
    }
}

impl Default for VideoGpuOptions {
    fn default() -> Self {
        Self::new()
    }
}

/// Enumerates audio outputs supported by the self-drawn player.
///
/// # Errors
///
/// Returns an error when enumeration is unavailable or fails. On iOS, apps
/// select external routes through the system route picker instead.
#[cfg_attr(
    target_os = "ios",
    expect(
        clippy::missing_const_for_fn,
        reason = "the cross-platform API must keep identical constness where other targets enumerate devices at runtime"
    )
)]
pub fn audio_output_devices() -> Result<Vec<AudioDevice>, PlayerError> {
    AudioDevice::list()
}

pub use runtime_player::{video, video_player};
