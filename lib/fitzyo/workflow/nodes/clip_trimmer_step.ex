defmodule Fitzyo.Workflow.Nodes.ClipTrimmerStep do
  @moduledoc """
  Trims a video clip to a specific time range and optionally applies speed adjustment.
  Real trimming via FFmpeg in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :clip_trimmer
    label "Clip Trimmer"
    category :assembly
    color :blue
    icon "✂️"
    description "Trims a clip to a time range with optional speed adjustment"

    input :clip, kind: :s3_ref, required: true

    output :clip, kind: :s3_ref, doc: "Trimmed video clip"
    output :thumbnail, kind: :s3_ref, doc: "Thumbnail from the trimmed clip"
    output :duration, kind: :float, doc: "Duration of the trimmed clip in seconds"

    config do
      option :start_ms,
        kind: :integer,
        default: 0

      option :end_ms,
        kind: :integer,
        default: 5000

      option :speed,
        kind: :atom,
        values: [:half, :normal, :double],
        default: :normal
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      clip: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/clip_trimmed.mp4", content_type: "video/mp4", duration_seconds: 5.0},
      thumbnail: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/clip_trimmed_thumb.webp", content_type: "image/webp"},
      duration: 5.0
    }}
  end
end
