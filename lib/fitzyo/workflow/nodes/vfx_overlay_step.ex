defmodule Fitzyo.Workflow.Nodes.VfxOverlayStep do
  @moduledoc """
  Composites a VFX overlay (particles, light leaks, lens flares) onto a video clip.
  Mocked in Slice 2; real compositing via FFmpeg NIF in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :vfx_overlay
    label "VFX Overlay"
    category :generation
    color :violet
    icon "✨"
    description "Composites a VFX overlay onto a video clip"

    input :clip, kind: :s3_ref, required: true
    input :overlay_asset, kind: :s3_ref, required: false

    output :clip, kind: :s3_ref, doc: "Video clip with VFX composited"
    output :thumbnail, kind: :s3_ref, doc: "Thumbnail of the composited clip"

    config do
      option :effect,
        kind: :atom,
        values: [:particles, :light_leak, :lens_flare, :film_grain, :chromatic_aberration],
        default: :particles

      option :blend_mode,
        kind: :atom,
        values: [:screen, :add, :multiply, :overlay],
        default: :screen

      option :intensity,
        kind: :atom,
        values: [:subtle, :medium, :strong],
        default: :medium
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      clip: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/vfx_overlay.mp4", content_type: "video/mp4", duration_seconds: 5.0},
      thumbnail: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/vfx_overlay_thumb.webp", content_type: "image/webp"}
    }}
  end
end
