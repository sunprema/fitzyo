defmodule Fitzyo.Workers.SceneGenerationWorker do
  @moduledoc """
  Oban worker for AI video scene generation.

  Lifecycle:
  1. Receives job args with `workflow_id`, `execution_id`, `node_id`, and generation params.
  2. Submits to the best provider via `ModelRouter.submit/1`.
  3. Polls until the video is ready (or fails/times out).
  4. Downloads the video URL and stores it in Tigris, returning an `S3Ref`.
  5. Broadcasts the result on PubSub so `WorkflowLive` can update the UI.

  Compensation on failure: broadcasts `:scene_failed` and marks execution node as failed.
  """

  use Oban.Worker,
    queue: :video_generation,
    max_attempts: 3,
    unique: [period: 60]

  alias Fitzyo.Video.{ModelRouter, S3Store}
  alias Phoenix.PubSub

  require Logger

  @poll_sleep_ms 3_000

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    execution_id = args["execution_id"]
    node_id = args["node_id"]

    params = %{
      prompt: args["prompt"],
      duration: args["duration"] || 5,
      capability: :text_to_video,
      image_reference_url: args["image_reference_url"]
    }

    broadcast(execution_id, {:scene_started, node_id})

    with {:ok, provider_mod, task_id} <- ModelRouter.submit(params),
         {:ok, video_url} <- poll_until_done(provider_mod, task_id, execution_id, node_id),
         {:ok, clip_ref} <- store_video(video_url, execution_id, node_id) do
      broadcast(execution_id, {:scene_complete, node_id, clip_ref})
      :ok
    else
      {:error, reason} ->
        Logger.error("[SceneGenerationWorker] node=#{node_id} failed: #{inspect(reason)}")
        broadcast(execution_id, {:scene_failed, node_id, inspect(reason)})
        {:error, reason}
    end
  end

  # ── Polling loop ─────────────────────────────────────────────────────────

  defp poll_until_done(provider_mod, task_id, execution_id, node_id, attempt \\ 0) do
    max = provider_mod.polling_config().max_attempts

    cond do
      attempt >= max ->
        {:error, :polling_timeout}

      true ->
        case ModelRouter.poll(provider_mod, task_id) do
          {:ok, {:done, url}} ->
            {:ok, url}

          {:ok, :pending} ->
            broadcast(execution_id, {:scene_progress, node_id, trunc(attempt / max * 100)})
            Process.sleep(@poll_sleep_ms)
            poll_until_done(provider_mod, task_id, execution_id, node_id, attempt + 1)

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  # ── Storage ───────────────────────────────────────────────────────────────

  defp store_video(video_url, execution_id, node_id) do
    key = "workflows/executions/#{execution_id}/#{node_id}/scene.mp4"
    S3Store.store_from_url(video_url, key, content_type: "video/mp4")
  end

  # ── PubSub helpers ────────────────────────────────────────────────────────

  defp broadcast(workflow_id, event) do
    PubSub.broadcast(Fitzyo.PubSub, "workflow:#{workflow_id}", event)
  end
end
