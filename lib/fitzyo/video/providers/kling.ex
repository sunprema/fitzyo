defmodule Fitzyo.Video.Providers.Kling do
  @moduledoc """
  Kling AI video generation provider (https://api.klingai.com).

  Authentication: HMAC-SHA256 signed JWT using access_key + secret_key.
  The `env_key` stores the concatenated "access_key:secret_key" pair.

  Submit: POST /v1/videos/text2video
  Poll:   GET  /v1/videos/text2video/{task_id}
  """

  use Fitzyo.VideoProvider

  provider do
    name :kling
    api_base "https://api.klingai.com"
    env_key "KLING_CREDENTIALS"

    model "kling-v1" do
      max_duration 10
      cost_per_second_usd 0.035
      supports_image_reference true
    end

    model "kling-v1-5" do
      max_duration 10
      cost_per_second_usd 0.045
      supports_image_reference true
      supports_audio false
    end

    polling do
      interval_ms 3_000
      max_attempts 200
    end

    webhook do
      signature_header "X-Kling-Signature"
      signature_scheme :hmac_sha256
      secret_env_key "KLING_WEBHOOK_SECRET"
    end
  end

  # ── Callback implementations ─────────────────────────────────────────────

  @impl Fitzyo.VideoProvider
  def submit(params, _opts \\ []) do
    body = %{
      "model_name" => Map.get(params, :model, "kling-v1-5"),
      "prompt" => Map.fetch!(params, :prompt),
      "negative_prompt" => Map.get(params, :negative_prompt, ""),
      "cfg_scale" => Map.get(params, :cfg_scale, 0.5),
      "mode" => Map.get(params, :mode, "std"),
      "duration" => Map.get(params, :duration, "5")
    }

    body =
      if ref = Map.get(params, :image_reference_url) do
        Map.put(body, "image_url", ref)
      else
        body
      end

    case request(:post, "/v1/videos/text2video", body) do
      {:ok, %{"data" => %{"task_id" => task_id}}} -> {:ok, task_id}
      {:ok, response} -> {:error, {:unexpected_response, response}}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Fitzyo.VideoProvider
  def poll(task_id) do
    case request(:get, "/v1/videos/text2video/#{task_id}", nil) do
      {:ok, %{"data" => %{"task_status" => status} = data}} ->
        case status do
          "submitted" -> {:ok, :pending}
          "processing" -> {:ok, :pending}
          "succeed" ->
            url =
              get_in(data, ["task_result", "videos", Access.at(0), "url"])

            if url, do: {:ok, {:done, url}}, else: {:error, :missing_video_url}

          "failed" ->
            reason = get_in(data, ["task_status_msg"]) || "unknown"
            {:error, {:generation_failed, reason}}
        end

      {:ok, response} ->
        {:error, {:unexpected_response, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Fitzyo.VideoProvider
  def cancel(task_id) do
    case request(:post, "/v1/videos/text2video/#{task_id}/cancel", %{}) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # ── JWT auth ────────────────────────────────────────────────────────────

  defp jwt_token do
    [access_key, secret_key] =
      api_key() |> String.split(":", parts: 2)

    now = System.os_time(:second)
    header = Base.url_encode64(Jason.encode!(%{"alg" => "HS256", "typ" => "JWT"}), padding: false)

    payload =
      Base.url_encode64(
        Jason.encode!(%{"iss" => access_key, "exp" => now + 1800, "nbf" => now - 5}),
        padding: false
      )

    signing_input = "#{header}.#{payload}"

    signature =
      :crypto.mac(:hmac, :sha256, secret_key, signing_input)
      |> Base.url_encode64(padding: false)

    "#{signing_input}.#{signature}"
  end

  # ── HTTP helpers ─────────────────────────────────────────────────────────

  defp request(:get, path, _body) do
    Req.get(api_base() <> path,
      headers: [
        {"Authorization", "Bearer #{jwt_token()}"},
        {"Content-Type", "application/json"}
      ]
    )
    |> parse_response()
  end

  defp request(:post, path, body) do
    Req.post(api_base() <> path,
      headers: [
        {"Authorization", "Bearer #{jwt_token()}"},
        {"Content-Type", "application/json"}
      ],
      json: body
    )
    |> parse_response()
  end

  defp parse_response({:ok, %{status: status, body: body}}) when status in 200..299 do
    {:ok, body}
  end

  defp parse_response({:ok, %{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp parse_response({:error, reason}) do
    {:error, {:request_failed, reason}}
  end
end
