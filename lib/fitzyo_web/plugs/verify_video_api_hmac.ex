defmodule FitzyoWeb.Plugs.VerifyVideoApiHmac do
  @moduledoc """
  Routes incoming video provider webhooks to the provider-specific HMAC
  verification plug based on the `:provider` assign set by the router.

  The auto-generated `VerifyHmac` submodule for each provider (e.g.
  `Fitzyo.Video.Providers.Kling.VerifyHmac`) is called rather than any
  hand-written verification plug.
  """
  @behaviour Plug

  def init(opts), do: opts

  def call(conn, opts) do
    provider_str = conn.path_params["provider"] || conn.params["provider"]

    case provider_str && String.to_existing_atom(provider_str) do
      nil ->
        conn
        |> Plug.Conn.send_resp(400, "Missing provider in path")
        |> Plug.Conn.halt()

      provider ->
        case resolve_plug(provider) do
          {:ok, verify_plug} ->
            verify_plug.call(conn, verify_plug.init(opts))

          :error ->
            conn
            |> Plug.Conn.send_resp(400, "Unknown video provider: #{provider}")
            |> Plug.Conn.halt()
        end
    end
  rescue
    ArgumentError ->
      conn
      |> Plug.Conn.send_resp(400, "Invalid provider")
      |> Plug.Conn.halt()
  end

  defp resolve_plug(:kling) do
    mod = Fitzyo.Video.Providers.Kling.VerifyHmac
    if Code.ensure_loaded?(mod), do: {:ok, mod}, else: :error
  end

  defp resolve_plug(_), do: :error
end
