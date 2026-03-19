defmodule Fitzyo.VideoProvider.Transformers.GenerateProviderClient do
  @moduledoc """
  Generates `capabilities/0`, `api_base/0`, `api_key/0`, `models/0`, `polling_config/0`,
  and (when a webhook block is present) a `VerifyHmac` submodule plug.
  """
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def before?(_), do: false
  def after?(_), do: false

  def transform(dsl_state) do
    name = Transformer.get_option(dsl_state, [:provider], :name)
    api_base = Transformer.get_option(dsl_state, [:provider], :api_base)
    env_key = Transformer.get_option(dsl_state, [:provider], :env_key)

    models = Transformer.get_entities(dsl_state, [:provider])
    interval_ms = Transformer.get_option(dsl_state, [:provider, :polling], :interval_ms) || 2_000
    max_attempts = Transformer.get_option(dsl_state, [:provider, :polling], :max_attempts) || 300

    webhook_header = Transformer.get_option(dsl_state, [:provider, :webhook], :signature_header)
    webhook_scheme = Transformer.get_option(dsl_state, [:provider, :webhook], :signature_scheme)
    webhook_secret_env = Transformer.get_option(dsl_state, [:provider, :webhook], :secret_env_key)

    polling_config = %Fitzyo.VideoProvider.PollingConfig{
      interval_ms: interval_ms,
      max_attempts: max_attempts
    }

    escaped_models = Macro.escape(models)
    escaped_polling = Macro.escape(polling_config)

    capabilities =
      models
      |> Enum.flat_map(fn m ->
        base = [:text_to_video]
        base = if m.supports_image_reference, do: [:image_reference | base], else: base
        if m.supports_audio, do: [:audio | base], else: base
      end)
      |> Enum.uniq()

    escaped_capabilities = Macro.escape(capabilities)

    current_module = Transformer.get_persisted(dsl_state, :module)

    webhook_code =
      if webhook_header do
        module_name = Module.concat([current_module, :VerifyHmac])
        escaped_module = Macro.escape(module_name)
        scheme_fn = if webhook_scheme == :hmac_sha1, do: :sha, else: :sha256

        quote do
          defmodule unquote(escaped_module) do
            @moduledoc "Auto-generated HMAC verification plug for #{unquote(name)} webhooks."
            @behaviour Plug

            import Plug.Conn

            def init(opts), do: opts

            def call(conn, _opts) do
              secret = System.get_env(unquote(webhook_secret_env)) || ""
              sig_header = String.downcase(unquote(webhook_header))

              with [signature] <- get_req_header(conn, sig_header),
                   {:ok, body, conn} <- read_body(conn),
                   expected <- Base.encode16(:crypto.mac(:hmac, unquote(scheme_fn), secret, body), case: :lower),
                   true <- Plug.Crypto.secure_compare(expected, signature) do
                put_private(conn, :raw_body, body)
              else
                _ ->
                  conn
                  |> send_resp(400, "Invalid signature")
                  |> halt()
              end
            end
          end
        end
      else
        quote do
        end
      end

    code =
      quote do
        unquote(webhook_code)

        @doc "Returns the provider atom identifier."
        def provider_name, do: unquote(name)

        @doc "Returns the API base URL for this provider."
        def api_base, do: unquote(api_base)

        @doc "Returns the API key from the environment."
        def api_key, do: System.get_env(unquote(env_key)) || raise("Missing env var: #{unquote(env_key)}")

        @doc "Returns all declared model structs."
        def models, do: unquote(escaped_models)

        @doc "Returns polling configuration for this provider."
        def polling_config, do: unquote(escaped_polling)

        @doc "Returns capability atoms supported by any model in this provider."
        def capabilities, do: unquote(escaped_capabilities)
      end

    {:ok, Transformer.eval(dsl_state, [], code)}
  end
end
