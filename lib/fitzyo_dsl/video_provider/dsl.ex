defmodule Fitzyo.VideoProvider.Dsl do
  @moduledoc """
  Spark DSL extension for declaring AI video API providers.

  Used via `use Fitzyo.VideoProvider`. Generates `capabilities/0`, `api_base/0`,
  `api_key/0`, model accessors, and a `VerifyHmac` plug submodule when a
  `webhook` block is present.
  """

  @model_entity %Spark.Dsl.Entity{
    name: :model,
    args: [:name],
    target: Fitzyo.VideoProvider.Model,
    schema: [
      name: [type: :string, required: true, doc: "Model identifier (e.g. \"kling-2.6\")"],
      max_duration: [type: :integer, default: 10, doc: "Max clip duration in seconds"],
      cost_per_second_usd: [type: :float, default: 0.0, doc: "Cost in USD per second of video"],
      supports_image_reference: [type: :boolean, default: false],
      supports_audio: [type: :boolean, default: false]
    ]
  }

  @polling_section %Spark.Dsl.Section{
    name: :polling,
    schema: [
      interval_ms: [type: :integer, default: 2_000, doc: "Polling interval in milliseconds"],
      max_attempts: [type: :integer, default: 300, doc: "Max polling attempts before timeout"]
    ]
  }

  @webhook_section %Spark.Dsl.Section{
    name: :webhook,
    schema: [
      signature_header: [type: :string, required: true, doc: "HTTP header carrying the HMAC signature"],
      signature_scheme: [
        type: {:one_of, [:hmac_sha256, :hmac_sha1]},
        default: :hmac_sha256,
        doc: "HMAC algorithm used by the provider"
      ],
      secret_env_key: [type: :string, required: true, doc: "Environment variable holding the webhook secret"]
    ]
  }

  @provider_section %Spark.Dsl.Section{
    name: :provider,
    schema: [
      name: [type: :atom, required: true, doc: "Provider atom identifier (e.g. :kling)"],
      api_base: [type: :string, required: true, doc: "Root URL of the provider's API"],
      env_key: [type: :string, required: true, doc: "Environment variable holding the API key/secret"]
    ],
    entities: [@model_entity],
    sections: [@polling_section, @webhook_section]
  }

  use Spark.Dsl.Extension,
    sections: [@provider_section],
    transformers: [
      Fitzyo.VideoProvider.Transformers.GenerateProviderClient
    ]
end
