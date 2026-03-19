defmodule Fitzyo.Workflow.GraphCompiler do
  @moduledoc """
  Compiles a workflow node/edge graph into an executable %Reactor{} struct.

  Slice 2: handles multi-node graphs with edges.
  - Validates the graph is a DAG via GraphValidator (Rust NIF)
  - Maps each edge to a Reactor.Argument.from_result dependency
  - Detects terminal nodes (sinks) and sets the Reactor return value
  """

  alias Fitzyo.Workflow.{ContextServer, GraphValidator, NodeRegistry}

  @doc """
  Compile a node/edge graph and start its ContextServer.

  Validates the graph, then builds the Reactor struct with all step
  dependencies wired from edges.

  Returns `{:ok, reactor, reactor_context}` or `{:error, reason}`.
  """
  def compile(nodes, edges, execution_id) do
    with {:ok, _topo_order} <- GraphValidator.validate(nodes, edges),
         {:ok, context_server} <- ContextServer.start_link(execution_id),
         {:ok, reactor} <- build_reactor(nodes, edges) do
      reactor_context = %{
        execution_id: execution_id,
        context_server: context_server,
        pubsub_topic: "workflow:#{execution_id}"
      }

      {:ok, reactor, reactor_context}
    end
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp build_reactor(nodes, edges) do
    reactor = Reactor.Builder.new()

    # Index edges by target node ID for O(1) lookup during step wiring
    edges_by_target =
      Enum.group_by(edges, fn e -> e["target"] || e[:target] end)

    result =
      Enum.reduce_while(nodes, {:ok, reactor}, fn node, {:ok, acc} ->
        node_id = node["id"] || node[:id]
        node_kind_str = node["type"] || node[:type] || "unknown"

        with {:ok, node_kind} <- safe_to_existing_atom(node_kind_str),
             {:ok, step_module} <- NodeRegistry.get_step_module(node_kind) do
          step_name = String.to_atom(node_id)
          static_args = build_static_args(node)
          dynamic_args = build_dynamic_args(node_id, edges_by_target)

          # Dynamic (edge-wired) args override static data args for the same name
          all_args = merge_args(static_args, dynamic_args)
          step_opts = [context: %{step_name: node_id}]

          case Reactor.Builder.add_step(acc, step_name, step_module, all_args, step_opts) do
            {:ok, new_reactor} -> {:cont, {:ok, new_reactor}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        else
          {:error, :not_existing_atom} ->
            {:halt, {:error, {:unknown_node_type, node_kind_str}}}

          {:error, :not_found} ->
            {:halt, {:error, {:unknown_node_type, node_kind_str}}}
        end
      end)

    case result do
      {:ok, reactor} ->
        terminal_id = find_terminal_node(nodes, edges)
        Reactor.Builder.return(reactor, String.to_atom(terminal_id))

      error ->
        error
    end
  end

  # Static args from node["data"] — same as Slice 1
  defp build_static_args(node) do
    data = node["data"] || node[:data] || %{}

    Enum.map(data, fn {key, value} ->
      arg_name = if is_binary(key), do: String.to_atom(key), else: key
      Reactor.Argument.from_value(arg_name, value)
    end)
  end

  # For each incoming edge, wire the upstream step's output as an argument.
  # Uses Reactor.Argument.from_result/3 with a transform to extract the
  # specific output key named by sourceHandle.
  defp build_dynamic_args(node_id, edges_by_target) do
    incoming = Map.get(edges_by_target, node_id, [])

    Enum.map(incoming, fn edge ->
      source_step = String.to_atom(edge["source"] || edge[:source])
      source_handle = safe_to_atom(edge["sourceHandle"] || edge[:sourceHandle] || "result")
      target_handle = safe_to_atom(edge["targetHandle"] || edge[:targetHandle] || "input")

      # Extract the specific output key from the upstream step's result map
      transform = &Map.get(&1, source_handle)
      Reactor.Argument.from_result(target_handle, source_step, transform)
    end)
  end

  # Merge static and dynamic args — dynamic args win on name collision
  defp merge_args(static_args, dynamic_args) do
    dynamic_names = MapSet.new(dynamic_args, & &1.name)
    filtered_static = Enum.reject(static_args, &MapSet.member?(dynamic_names, &1.name))
    filtered_static ++ dynamic_args
  end

  # The terminal node (return value) is the sink: no outgoing edges.
  # If multiple sinks exist, pick the one with the greatest Y position
  # (visually lowest on the canvas — typically the final assembly node).
  defp find_terminal_node(nodes, edges) do
    source_ids = MapSet.new(edges, fn e -> e["source"] || e[:source] end)

    sinks =
      Enum.reject(nodes, fn n ->
        MapSet.member?(source_ids, n["id"] || n[:id])
      end)

    case sinks do
      [] ->
        node = List.last(nodes)
        node["id"] || node[:id]

      [single] ->
        single["id"] || single[:id]

      multiple ->
        best =
          Enum.max_by(multiple, fn n ->
            pos = n["position"] || n[:position] || %{}
            pos["y"] || pos[:y] || 0
          end)

        best["id"] || best[:id]
    end
  end

  defp safe_to_existing_atom(str) when is_binary(str) do
    {:ok, String.to_existing_atom(str)}
  rescue
    ArgumentError -> {:error, :not_existing_atom}
  end

  defp safe_to_atom(str) when is_binary(str), do: String.to_atom(str)
  defp safe_to_atom(atom) when is_atom(atom), do: atom
end
