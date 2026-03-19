defmodule Fitzyo.Workflow.Nodes.ParallelMergeStep do
  @moduledoc """
  Waits for all upstream parallel branches to complete and collects their
  outputs into a list, then passes it to downstream nodes.
  Reactor handles the parallel scheduling automatically.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :parallel_merge
    label "Parallel Merge"
    category :control
    color :gray
    icon "⇒"
    description "Collects outputs from parallel branches into a list"

    input :branch_a, kind: :any, required: true
    input :branch_b, kind: :any, required: true
    input :branch_c, kind: :any, required: false
    input :branch_d, kind: :any, required: false

    output :results, kind: :list, doc: "List of all branch outputs in completion order"
    output :count, kind: :integer, doc: "Number of branches that completed"

    config do
      option :merge_strategy,
        kind: :atom,
        values: [:collect_all, :first_wins, :fastest],
        default: :collect_all
    end
  end

  def run(arguments, _context, _options) do
    branches = [
      arguments[:branch_a],
      arguments[:branch_b],
      arguments[:branch_c],
      arguments[:branch_d]
    ]

    results = Enum.reject(branches, &is_nil/1)

    {:ok, %{results: results, count: length(results)}}
  end
end
