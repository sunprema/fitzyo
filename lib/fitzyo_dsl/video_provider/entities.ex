defmodule Fitzyo.VideoProvider.Model do
  @moduledoc "Compile-time struct for a model declared inside `provider do ... model ... end`."
  defstruct [
    :name,
    :max_duration,
    :cost_per_second_usd,
    supports_image_reference: false,
    supports_audio: false
  ]
end

defmodule Fitzyo.VideoProvider.PollingConfig do
  @moduledoc "Compile-time struct for `polling do ... end` block."
  defstruct interval_ms: 2_000, max_attempts: 300
end

defmodule Fitzyo.VideoProvider.WebhookConfig do
  @moduledoc "Compile-time struct for `webhook do ... end` block."
  defstruct [:signature_header, :signature_scheme, :secret_env_key]
end

defmodule Fitzyo.VideoProvider.ProviderConfig do
  @moduledoc "Top-level compile-time struct for an entire provider declaration."
  defstruct [
    :name,
    :api_base,
    :env_key,
    models: [],
    polling: nil,
    webhook: nil
  ]
end
