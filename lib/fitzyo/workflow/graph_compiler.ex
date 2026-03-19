defmodule Fitzyo.Workflow.GraphCompiler do
  @moduledoc """
  Compiles a workflow node/edge graph into an executable %Reactor{} struct.

  For Slice 1: handles single-node graphs only.
  Multi-node support with edges and argument wiring is added in Slice 2.
  """

  alias Fitzyo.Workflow.{ContextServer, NodeRegistry}

  @doc """
  Compile a node/edge graph and start its ContextServer.

  Returns `{:ok, reactor, reactor_context}` where `reactor_context` is the map
  to pass as the third argument to `Reactor.run/4`.
  """
  def compile(nodes, _edges, execution_id) do
    with {:ok, context_server} <- ContextServer.start_link(execution_id),
         {:ok, reactor} <- build_reactor(nodes, execution_id) do
      reactor_context = %{
        execution_id: execution_id,
        context_server: context_server,
        pubsub_topic: "workflow:#{execution_id}"
      }

      {:ok, reactor, reactor_context}
    end
  end

  defp build_reactor(nodes, _execution_id) do
    reactor = Reactor.Builder.new()

    Enum.reduce_while(nodes, {:ok, reactor}, fn node, {:ok, acc} ->
      node_type = String.to_existing_atom(node["type"] || node[:type] || "unknown")

      case NodeRegistry.get_step_module(node_type) do
        {:ok, step_module} ->
          step_name = String.to_atom(node["id"] || node[:id])
          step_args = build_step_args(node)

          step_opts = [context: %{step_name: to_string(step_name)}]

          case Reactor.Builder.add_step(acc, step_name, step_module, step_args, step_opts) do
            {:ok, new_reactor} -> {:cont, {:ok, new_reactor}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        {:error, :not_found} ->
          {:halt, {:error, {:unknown_node_type, node_type}}}
      end
    end)
    |> case do
      {:ok, reactor} ->
        # For single-node graphs, use the only step as return
        case reactor.steps do
          [step | _] -> Reactor.Builder.return(reactor, step.name)
          [] -> {:error, :empty_graph}
        end

      error ->
        error
    end
  end

  # Build Reactor.Argument list for a node based on its data map.
  # For Slice 1 all arguments are passed as static values from node data.
  defp build_step_args(node) do
    data = node["data"] || node[:data] || %{}

    Enum.map(data, fn {key, value} ->
      arg_name = if is_binary(key), do: String.to_atom(key), else: key
      Reactor.Argument.from_value(arg_name, value)
    end)
  end
end
