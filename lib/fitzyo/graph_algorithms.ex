defmodule Fitzyo.GraphAlgorithms do
  @moduledoc """
  Rustler NIF wrapper for graph algorithm operations.

  All heavy graph work (cycle detection, topological sort, critical path)
  runs in the DirtyCpu scheduler — never blocks the BEAM scheduler.

  Use `Fitzyo.Workflow.GraphValidator` for the public API.
  """
  use Rustler, otp_app: :fitzyo, crate: "graph_algorithms"

  # Proof-of-life from Slice 0
  def hello, do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Validates a node/edge graph is a DAG (no cycles).

  - `node_ids`: list of node ID strings
  - `edges`: list of `{source_id, target_id}` tuples

  Returns `{:ok, topo_order}` or `{:error, "cycle_detected"}`.
  """
  def validate_dag(_node_ids, _edges), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Groups nodes by execution depth (longest path from any source).

  Returns `{:ok, [[node_id]]}` where each inner list contains nodes
  that can run in parallel at that depth level.
  """
  def find_parallel_groups(_node_ids, _edges), do: :erlang.nif_error(:nif_not_loaded)

  @doc """
  Returns the critical path (longest chain) through the DAG as an
  ordered list of node IDs.
  """
  def find_critical_path(_node_ids, _edges), do: :erlang.nif_error(:nif_not_loaded)
end
