defmodule Fitzyo.Workflow.Nodes.StyleReferenceStep do
  @moduledoc """
  Holds a style pack (colour palette, lighting preset, mood board) that
  downstream generation nodes can reference to maintain visual consistency.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :style_reference
    label "Style Reference"
    category :data
    color :teal
    icon "🎨"
    description "Provides a visual style pack to downstream generation nodes"

    input :reference_image, kind: :s3_ref, required: false

    output :style_pack, kind: :map, doc: "Style descriptor passed to generation nodes"
    output :thumbnail, kind: :s3_ref, doc: "Thumbnail of the reference image"

    config do
      option :preset,
        kind: :atom,
        values: [:cinematic, :anime, :documentary, :commercial, :music_video, :custom],
        default: :cinematic

      option :color_grade,
        kind: :atom,
        values: [:warm, :cool, :desaturated, :vibrant, :monochrome],
        default: :cool

      option :lighting,
        kind: :atom,
        values: [:golden_hour, :blue_hour, :studio, :natural, :dramatic],
        default: :natural
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      style_pack: %{
        preset: "cinematic",
        color_grade: "cool",
        lighting: "natural"
      },
      thumbnail: %S3Ref{bucket: "fitzyo-asset-previews", key: "mock/style_thumb.webp", content_type: "image/webp"}
    }}
  end
end
