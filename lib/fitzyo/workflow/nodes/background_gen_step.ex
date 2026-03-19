defmodule Fitzyo.Workflow.Nodes.BackgroundGenStep do
  @moduledoc """
  Generates a background image or looping video using an AI image/video API.
  Mocked in Slice 2; wired to real API in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :background_gen
    label "Background Gen"
    category :generation
    color :violet
    icon "🖼️"
    description "Generates a background image or looping video"

    input :prompt, kind: :string, required: true
    input :style_reference, kind: :s3_ref, required: false

    output :background, kind: :s3_ref, doc: "Generated background asset"
    output :thumbnail, kind: :s3_ref, doc: "Preview thumbnail"

    config do
      option :output_format,
        kind: :atom,
        values: [:image, :looping_video],
        default: :image

      option :aspect_ratio,
        kind: :atom,
        values: [:widescreen_16_9, :vertical_9_16, :square_1_1],
        default: :widescreen_16_9

      option :style,
        kind: :atom,
        values: [:photorealistic, :illustrated, :cinematic, :abstract],
        default: :photorealistic
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      background: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/background.jpg", content_type: "image/jpeg"},
      thumbnail: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/background_thumb.webp", content_type: "image/webp"}
    }}
  end
end
