//! Compiles the spherical video GPU shader for the selected target.

use std::fs;
use std::path::PathBuf;

fn main() {
    let spherical_path =
        PathBuf::from(std::env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR must be set"))
            .join("src/shaders/spherical_video_render.wgsl");
    println!("cargo:rerun-if-changed={}", spherical_path.display());
    let spherical = fs::read_to_string(&spherical_path).unwrap_or_else(|error| {
        panic!(
            "failed to read spherical video shader {}: {error}",
            spherical_path.display()
        )
    });
    shaderloom::build::compile_wgsl_source(
        "spherical_video_render.wgsl",
        &spherical,
        "spherical_video",
    );
}
