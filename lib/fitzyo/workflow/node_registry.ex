defmodule Fitzyo.Workflow.NodeRegistry do
  @moduledoc """
  ETS-backed registry of all node types in the system.

  Populated at application startup by calling `__register__/0` on every compiled
  module that exposes it (injected by the `RegisterInNodeRegistry` DSL transformer).
  Never add nodes to this registry manually.
  """
  use GenServer

  @table :fitzyo_node_registry

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Register a node module with its definition. Called by each node's __register__/0."
  def register(module, %Fitzyo.NodeStep.NodeDefinition{} = definition) do
    :ets.insert(@table, {definition.kind, module, definition})
    :ok
  end

  @doc "Returns all registered node definitions."
  def all_nodes do
    :ets.tab2list(@table)
    |> Enum.map(fn {_type, _module, definition} -> definition end)
  end

  @doc "Returns all registered {type, module, definition} tuples."
  def all_entries do
    :ets.tab2list(@table)
  end

  @doc "Looks up a node definition by type atom."
  def get_node(type) do
    case :ets.lookup(@table, type) do
      [{^type, _module, definition}] -> {:ok, definition}
      [] -> {:error, :not_found}
    end
  end

  @doc "Returns the step module for a given node type atom."
  def get_step_module(type) do
    case :ets.lookup(@table, type) do
      [{^type, module, _definition}] -> {:ok, module}
      [] -> {:error, :not_found}
    end
  end

  # --- GenServer callbacks ---

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    discover_and_register()
    {:ok, nil}
  end

  # Discover and register all node modules synchronously during init so that
  # the ETS table is fully populated before the GenServer is considered started.
  # This prevents race conditions where ETS reads (which bypass the GenServer)
  # could see an empty table while handle_continue is still running.
  defp discover_and_register do
    :fitzyo
    |> Application.spec(:modules)
    |> Enum.each(fn mod ->
      # Modules in the .app spec are not necessarily loaded into memory yet.
      # ensure_loaded/1 forces the module to be available before function_exported? check.
      :code.ensure_loaded(mod)

      if function_exported?(mod, :__register__, 0) do
        mod.__register__()
      end
    end)
  end
end
