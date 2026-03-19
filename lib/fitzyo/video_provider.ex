defmodule Fitzyo.VideoProvider do
  @moduledoc """
  Base module for all AI video API provider implementations.

  `use Fitzyo.VideoProvider` sets up the `provider do ... end` Spark DSL block and
  generates `capabilities/0`, `api_base/0`, `api_key/0`, `models/0`,
  `polling_config/0`, and (when a `webhook` block is present) a `VerifyHmac`
  submodule plug.

  ## Callbacks

  - `submit/2` — Submit a generation task. Returns `{:ok, task_id}` or `{:error, reason}`.
  - `poll/1` — Check job status. Returns `{:ok, :pending}`, `{:ok, {:done, url}}`, or `{:error, reason}`.
  - `cancel/1` — Cancel a running job. Returns `:ok` or `{:error, reason}`.
  """

  use Spark.Dsl, default_extensions: [extensions: [Fitzyo.VideoProvider.Dsl]]

  def handle_before_compile(_opts) do
    quote do
      @behaviour Fitzyo.VideoProvider
    end
  end

  @callback submit(params :: map(), opts :: keyword()) ::
              {:ok, task_id :: String.t()} | {:error, reason :: term()}

  @callback poll(task_id :: String.t()) ::
              {:ok, :pending} | {:ok, {:done, video_url :: String.t()}} | {:error, reason :: term()}

  @callback cancel(task_id :: String.t()) :: :ok | {:error, reason :: term()}
end
