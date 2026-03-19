defmodule Fitzyo.Workflow.GraphValidator do
  @moduledoc """
  Public API for validating workflow graphs before compilation or execution.

  Delegates to `Fitzyo.GraphAlgorithms` NIFs running on the DirtyCpu scheduler.
  All functions are safe to call from LiveView event handlers.
  """

  alias Fitzyo.GraphAlgorithms

  @doc """
  Validates a node/edge graph and returns the topological execution order.

  Accepts the same `nodes` and `edges` shapes used by `GraphCompiler` and
  the Svelte canvas (string-keyed maps with `"id"`, `"source"`, `"target"`).

  Returns:
  - `{:ok, topo_order}` — list of node IDs in safe execution order
  - `{:error, :cycle_detected}` — graph has a cycle
  - `{:error, :empty_graph}` — no nodes provided
  """
  def validate(nodes, edges) do
    node_ids = Enum.map(nodes, fn n -> n["id"] || n[:id] end)

    if Enum.empty?(node_ids) do
      {:error, :empty_graph}
    else
      edge_pairs = build_edge_pairs(edges)

      case GraphAlgorithms.validate_dag(node_ids, edge_pairs) do
        {:ok, topo_order} -> {:ok, topo_order}
        {:error, "cycle_detected"} -> {:error, :cycle_detected}
      end
    end
  end

  @doc """
  Groups nodes by execution depth so the UI can show which nodes run in parallel.

  Returns `{:ok, [[node_id]]}` — outer list indexed by depth (0 = sources),
  or `{:error, reason}`.
  """
  def parallel_groups(nodes, edges) do
    node_ids = Enum.map(nodes, fn n -> n["id"] || n[:id] end)
    edge_pairs = build_edge_pairs(edges)
    GraphAlgorithms.find_parallel_groups(node_ids, edge_pairs)
  end

  @doc """
  Returns the critical path (longest chain of nodes from source to sink).

  Useful for ETA estimation and timeline rendering.
  Returns `{:ok, [node_id]}` or `{:error, reason}`.
  """
  def critical_path(nodes, edges) do
    node_ids = Enum.map(nodes, fn n -> n["id"] || n[:id] end)
    edge_pairs = build_edge_pairs(edges)
    GraphAlgorithms.find_critical_path(node_ids, edge_pairs)
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp build_edge_pairs(edges) do
    Enum.map(edges, fn e ->
      source = e["source"] || e[:source]
      target = e["target"] || e[:target]
      {source, target}
    end)
  end
end
