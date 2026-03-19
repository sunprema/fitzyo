defmodule FitzyoWeb.WebhookController do
  @moduledoc """
  Handles inbound webhooks from video generation providers.

  Each provider pipeline verifies the HMAC signature before this controller
  is called — if we reach `video_callback/2`, the request is already trusted.
  """
  use FitzyoWeb, :controller

  alias Fitzyo.Workflow.ObanBridge

  @doc """
  Handles video generation completion callbacks from AI providers.

  Expected path: POST /webhooks/video/:provider
  Expected body (provider-normalised by plug pipeline):
    - `execution_id` — identifies the halted Reactor
    - `step_ref`     — identifies the suspended step
    - `status`       — "succeed" | "failed"
    - `video_url`    — present when status == "succeed"
    - `error`        — present when status == "failed"
  """
  def video_callback(conn, %{"provider" => _provider} = params) do
    execution_id = params["execution_id"]
    step_ref = params["step_ref"]
    status = params["status"]

    result =
      case status do
        "succeed" ->
          {:ok,
           %{
             clip_url: params["video_url"],
             provider: params["provider"]
           }}

        "failed" ->
          {:error, params["error"] || "provider reported failure"}

        _ ->
          {:error, {:unknown_status, status}}
      end

    case ObanBridge.resume_reactor(execution_id, step_ref, result) do
      {:ok, _} ->
        send_resp(conn, 200, "ok")

      {:halted, _} ->
        send_resp(conn, 200, "ok")

      {:error, :reactor_not_found} ->
        send_resp(conn, 404, "execution not found")

      {:error, reason} ->
        send_resp(conn, 500, inspect(reason))
    end
  end
end
