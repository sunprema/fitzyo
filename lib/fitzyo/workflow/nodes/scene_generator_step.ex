defmodule Fitzyo.Workflow.Nodes.SceneGeneratorStep do
  @moduledoc """
  Generates a video scene using an AI video API.

  In Slice 1, run/3 suspends for an Oban worker that mocks the generation with
  a 5-second delay and returns a fixed S3Ref. Real API calls are wired in Slice 4.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Workflow.ObanBridge

  node_def do
    kind :scene_generator
    label("Scene Generator")
    category(:generation)
    color(:violet)
    icon("🎬")
    description "Generates a video scene using an AI video API"

    input :prompt, kind: :string, required: true
    input :duration_seconds, kind: :integer, required: false, default: 5

    output(:clip, kind: :s3_ref, doc: "Generated video clip stored in Tigris")
    output(:thumbnail, kind: :s3_ref, doc: "First frame of the clip")
    output(:duration, kind: :float, doc: "Actual clip duration in seconds")

    config do
      option(:camera_move,
        kind: :atom,
        values: [:static, :dolly_in, :pan_left, :pan_right, :crane_up, :handheld],
        default: :static
      )
    end
  end

  def run(arguments, context, _options) do
    step_name = Map.get(context, :step_name, "unknown")

    ObanBridge.suspend_for_oban(context, step_name, Fitzyo.Workers.SceneGenerationWorker, %{
      "prompt" => arguments[:prompt],
      "duration_seconds" => arguments[:duration_seconds] || 5,
      "step_name" => step_name
    })
  end

  def compensate(_reason, _arguments, _context, _options) do
    # TODO Slice 4: cancel in-flight Kling/Runway job
    :ok
  end
end
