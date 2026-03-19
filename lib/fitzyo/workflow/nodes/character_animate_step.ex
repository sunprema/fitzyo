defmodule Fitzyo.Workflow.Nodes.CharacterAnimateStep do
  @moduledoc """
  Animates a character reference image into a video clip using an AI video API.
  Mocked in Slice 2; wired to real API in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :character_animate
    label "Character Animate"
    category :generation
    color :violet
    icon "🧑‍🎤"
    description "Animates a character reference image into a video clip"

    input :character_ref, kind: :s3_ref, required: true
    input :motion_prompt, kind: :string, required: true
    input :duration_seconds, kind: :integer, required: false, default: 5

    output :clip, kind: :s3_ref, doc: "Animated character video clip"
    output :thumbnail, kind: :s3_ref, doc: "First frame of the animated clip"
    output :duration, kind: :float, doc: "Actual clip duration in seconds"

    config do
      option :style,
        kind: :atom,
        values: [:realistic, :animated, :stylised],
        default: :realistic

      option :emotion,
        kind: :atom,
        values: [:neutral, :happy, :serious, :excited],
        default: :neutral
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      clip: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/character_animate.mp4", content_type: "video/mp4", duration_seconds: 5.0},
      thumbnail: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/character_animate_thumb.webp", content_type: "image/webp"},
      duration: 5.0
    }}
  end
end
