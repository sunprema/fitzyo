defmodule Fitzyo.Video.ModelRouter do
  @moduledoc """
  Routes video generation requests to the cheapest available provider model
  that satisfies the required capability and duration.

  All providers are discovered at runtime via `Fitzyo.VideoProvider.Info`.
  """

  alias Fitzyo.VideoProvider.Info

  @doc """
  Submits a generation request, routing to the best matching provider.

  ## Params
  - `:prompt` — required
  - `:duration` — integer seconds (default 5)
  - `:image_reference_url` — optional image reference S3 presigned URL
  - `:capability` — atom, default `:text_to_video`
  """
  def submit(params) do
    capability = Map.get(params, :capability, :text_to_video)
    duration = Map.get(params, :duration, 5)

    case Info.cheapest_model_for(capability, duration) do
      nil ->
        {:error, {:no_provider, capability, duration}}

      {provider_mod, model} ->
        merged = Map.put(params, :model, model.name)

        case provider_mod.submit(merged) do
          {:ok, task_id} -> {:ok, provider_mod, task_id}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Polls a task on the given provider module.
  Returns `{:ok, :pending}`, `{:ok, {:done, url}}`, or `{:error, reason}`.
  """
  def poll(provider_mod, task_id) do
    provider_mod.poll(task_id)
  end

  @doc """
  Cancels a task on the given provider module.
  """
  def cancel(provider_mod, task_id) do
    provider_mod.cancel(task_id)
  end
end
