defmodule Fitzyo.Workflow.Nodes.CronTriggerStep do
  @moduledoc """
  Trigger node that fires a workflow on a cron schedule via Oban's cron plugin.
  Real scheduling is wired in Slice 5.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :cron_trigger
    label "Cron Trigger"
    category :trigger
    color :amber
    icon "⏰"
    description "Fires the workflow on a recurring schedule"

    output :triggered_at, kind: :string, doc: "ISO8601 timestamp of the trigger"
    output :run_number, kind: :integer, doc: "Monotonically increasing run counter"

    config do
      option :schedule,
        kind: :string,
        default: "0 9 * * 1-5"

      option :timezone,
        kind: :string,
        default: "UTC"
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      triggered_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      run_number: System.unique_integer([:positive, :monotonic])
    }}
  end
end
