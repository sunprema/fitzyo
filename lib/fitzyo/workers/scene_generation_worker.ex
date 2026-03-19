defmodule Fitzyo.Workers.SceneGenerationWorker do
  @moduledoc """
  Oban worker that drives scene generation.

  Slice 1: mocked — sleeps 5 seconds broadcasting progress, then returns a
  fixed S3Ref. Real Kling/Runway API calls are added in Slice 4.
  """
  use Oban.Worker, queue: :video_generation, max_attempts: 3

  alias Fitzyo.Workflow.ObanBridge
  alias Fitzyo.Video.S3Ref

  @mock_clip_duration 5.0

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{
          "execution_id" => execution_id,
          "step_ref" => step_ref,
          "step_name" => step_name
        }
      }) do
    topic = "workflow:#{execution_id}"

    # Broadcast progress at ~1s intervals over 5 seconds
    for percent <- [10, 30, 50, 70, 90] do
      Process.sleep(1_000)

      Phoenix.PubSub.broadcast(Fitzyo.PubSub, topic, {
        :scene_progress,
        step_name,
        percent
      })
    end

    # Return mocked S3Refs (no real file written for Slice 1).
    # preview_url is a real image for dev UI — replaced by real thumbnail in Slice 4.
    result = %{
      clip: %S3Ref{
        bucket: "fitzyo-video-clips",
        key: "workflows/mock/clips/#{step_name}.mp4",
        content_type: "video/mp4",
        duration_seconds: @mock_clip_duration
      },
      thumbnail: %S3Ref{
        bucket: "fitzyo-video-clips",
        key: "workflows/mock/thumbnails/#{step_name}.webp",
        content_type: "image/webp"
      },
      preview_url: "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=320&q=80",
      duration: @mock_clip_duration
    }

    Phoenix.PubSub.broadcast(Fitzyo.PubSub, topic, {:step_complete, step_name, result})

    ObanBridge.resume_reactor(execution_id, step_ref, result)

    :ok
  end
end
