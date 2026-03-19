defmodule Fitzyo.Workflow.Nodes.WebhookTriggerStep do
  @moduledoc """
  Trigger node that fires a workflow when an HTTP POST arrives at its webhook URL.
  Real webhook routing and token auth are wired in Slice 5.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :webhook_trigger
    label "Webhook Trigger"
    category :trigger
    color :amber
    icon "🔗"
    description "Fires when an HTTP POST arrives at the node's webhook URL"

    output :payload, kind: :map, doc: "Raw JSON body of the incoming request"
    output :headers, kind: :map, doc: "HTTP headers from the incoming request"
    output :triggered_at, kind: :string, doc: "ISO8601 timestamp of the trigger"

    config do
      option :method,
        kind: :atom,
        values: [:post, :get, :put],
        default: :post

      option :auth_scheme,
        kind: :atom,
        values: [:token, :hmac, :none],
        default: :token
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      payload: %{"event" => "mock_webhook_event", "data" => %{}},
      headers: %{"content-type" => "application/json"},
      triggered_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }}
  end
end
