defmodule Fitzyo.Workflow.Nodes.WaitStep do
  @moduledoc """
  Pauses workflow execution for a fixed duration using an Oban scheduled job.
  Real delay scheduling is wired in Slice 5.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :wait
    label "Wait"
    category :trigger
    color :amber
    icon "⏳"
    description "Pauses execution for a fixed duration before continuing"

    output :resumed_at, kind: :string, doc: "ISO8601 timestamp when the wait ended"

    config do
      option :duration_seconds,
        kind: :integer,
        default: 60

      option :label,
        kind: :string,
        default: "Wait"
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{resumed_at: DateTime.utc_now() |> DateTime.to_iso8601()}}
  end
end
