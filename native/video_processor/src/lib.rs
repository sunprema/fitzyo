/// VideoProcessor NIFs for Fitzyo.
///
/// Slice 1: extract_thumbnail/3 is a stub returning a minimal WebP placeholder.
/// Real FFmpeg-based extraction is wired in Slice 4 via the `ffmpeg-next` crate.
///
/// All heavy NIFs run on the DirtyCpu scheduler so they never block the BEAM.

mod atoms {
    rustler::atoms! {
        ok,
        error
    }
}

/// Minimal valid 1×1 white RIFF/WebP image (Lossless VP8L).
const PLACEHOLDER_WEBP: &[u8] = &[
    0x52, 0x49, 0x46, 0x46, // "RIFF"
    0x24, 0x00, 0x00, 0x00, // file size - 8  (36 bytes total)
    0x57, 0x45, 0x42, 0x50, // "WEBP"
    0x56, 0x50, 0x38, 0x4C, // "VP8L" chunk
    0x07, 0x00, 0x00, 0x00, // VP8L chunk size = 7 bytes
    0x2F, 0x00, 0x00, 0x00, // VP8L bitstream header (1×1, no alpha)
    0x00, 0x00, 0x00, // colour data
    0x00, 0x00, 0x00, 0x00, // padding
];

/// Extract a thumbnail frame from a video binary at `offset_ms` milliseconds.
/// Returns `{:ok, webp_binary}`.
///
/// Slice 1: always returns `PLACEHOLDER_WEBP` regardless of input.
/// Slice 4: real FFmpeg frame extraction.
#[rustler::nif(schedule = "DirtyCpu")]
fn extract_thumbnail<'a>(
    env: rustler::Env<'a>,
    _video_binary: rustler::Binary<'a>,
    _offset_ms: u64,
    _max_width: u32,
) -> (rustler::Atom, rustler::Binary<'a>) {
    let mut new_bin = rustler::NewBinary::new(env, PLACEHOLDER_WEBP.len());
    new_bin.as_mut_slice().copy_from_slice(PLACEHOLDER_WEBP);
    (atoms::ok(), new_bin.into())
}

/// Probe basic metadata from a video binary.
/// Returns `{:ok, json_binary}` where the JSON has keys: duration_s, width, height, codec.
///
/// Slice 4 stub: returns a fixed metadata JSON.
/// Real implementation: parse MP4/WebM headers or call ffprobe.
#[rustler::nif(schedule = "DirtyCpu")]
fn probe_video_metadata<'a>(
    env: rustler::Env<'a>,
    _video_binary: rustler::Binary<'a>,
) -> (rustler::Atom, rustler::Binary<'a>) {
    let placeholder = b"{\"duration_s\":5.0,\"width\":1280,\"height\":720,\"codec\":\"h264\"}";
    let mut out = rustler::NewBinary::new(env, placeholder.len());
    out.as_mut_slice().copy_from_slice(placeholder);
    (atoms::ok(), out.into())
}

/// Generate a waveform amplitude array from audio in a video binary.
/// Returns `{:ok, json_binary}` where the JSON is an array of floats in [0, 1].
///
/// Slice 4 stub: returns a 10-point flat waveform.
#[rustler::nif(schedule = "DirtyCpu")]
fn generate_waveform<'a>(
    env: rustler::Env<'a>,
    _video_binary: rustler::Binary<'a>,
    _num_points: u32,
) -> (rustler::Atom, rustler::Binary<'a>) {
    let placeholder = b"[0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5,0.5]";
    let mut out = rustler::NewBinary::new(env, placeholder.len());
    out.as_mut_slice().copy_from_slice(placeholder);
    (atoms::ok(), out.into())
}

rustler::init!("Elixir.Fitzyo.Video.FrameProcessor.Native");
