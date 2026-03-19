defmodule Fitzyo.Workflow.Nodes.AudioMixerStep do
  @moduledoc """
  Mixes a background music track with voiceover and/or scene audio.
  Real mixing via FFmpeg in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :audio_mixer
    label "Audio Mixer"
    category :assembly
    color :blue
    icon "🎚️"
    description "Mixes music, voiceover, and scene audio tracks"

    input :music_track, kind: :s3_ref, required: false
    input :voiceover, kind: :s3_ref, required: false
    input :scene_audio, kind: :s3_ref, required: false

    output :mixed_audio, kind: :s3_ref, doc: "Final mixed audio track"
    output :duration, kind: :float, doc: "Duration of the mixed track in seconds"

    config do
      option :music_volume,
        kind: :integer,
        default: 30

      option :voiceover_volume,
        kind: :integer,
        default: 100

      option :fade_in_ms,
        kind: :integer,
        default: 500

      option :fade_out_ms,
        kind: :integer,
        default: 1000
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      mixed_audio: %S3Ref{bucket: "fitzyo-video-clips", key: "mock/mixed_audio.aac", content_type: "audio/aac"},
      duration: 15.0
    }}
  end
end
