defmodule Fitzyo.Workflow.ContextServer do
  @moduledoc """
  ETS-backed GenServer that owns the mutable shared execution context for one
  workflow execution. Started by GraphCompiler; its PID is injected into the
  Reactor context map so all NodeSteps can reach it.

  All writes are serialised through this GenServer — no race conditions even when
  Reactor runs steps concurrently in separate processes.
  """
  use GenServer

  alias Fitzyo.Workflow.ExecutionContext

  # --- Public API ---

  def start_link(execution_id) do
    GenServer.start_link(__MODULE__, execution_id)
  end

  @doc "Read a value from shared context by key path (list or single atom)."
  def read(server, key_path) do
    GenServer.call(server, {:read, List.wrap(key_path)})
  end

  @doc "Write a value into shared context at key_path. Deep-merges maps."
  def write(server, key_path, value) do
    GenServer.call(server, {:write, List.wrap(key_path), value})
  end

  @doc "Deep-merge a map into the shared context root."
  def merge(server, map) when is_map(map) do
    GenServer.call(server, {:merge, map})
  end

  @doc "Read a private (step-namespaced) value."
  def read_private(server, step_name, key) do
    GenServer.call(server, {:read_private, step_name, key})
  end

  @doc "Write a private (step-namespaced) value."
  def write_private(server, step_name, key, value) do
    GenServer.call(server, {:write_private, step_name, key, value})
  end

  @doc "Returns a snapshot of the full execution context."
  def snapshot(server) do
    GenServer.call(server, :snapshot)
  end

  # --- GenServer callbacks ---

  @impl true
  def init(execution_id) do
    {:ok, %ExecutionContext{execution_id: execution_id}}
  end

  @impl true
  def handle_call({:read, key_path}, _from, state) do
    value = get_in(state.shared, key_path)
    {:reply, value, state}
  end

  @impl true
  def handle_call({:write, key_path, value}, _from, state) do
    new_shared = put_in(state.shared, key_path, value)
    new_state = %{state | shared: new_shared}

    Phoenix.PubSub.broadcast(
      Fitzyo.PubSub,
      "execution:#{state.execution_id}:context",
      {:context_updated, key_path, value}
    )

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call({:merge, map}, _from, state) do
    new_shared = deep_merge(state.shared, map)
    {:reply, :ok, %{state | shared: new_shared}}
  end

  @impl true
  def handle_call({:read_private, step_name, key}, _from, state) do
    value = get_in(state.private, [step_name, key])
    {:reply, value, state}
  end

  @impl true
  def handle_call({:write_private, step_name, key, value}, _from, state) do
    new_private =
      state.private
      |> Map.put_new(step_name, %{})
      |> put_in([step_name, key], value)

    {:reply, :ok, %{state | private: new_private}}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, state, state}
  end

  defp deep_merge(base, override) when is_map(base) and is_map(override) do
    Map.merge(base, override, fn _key, left, right ->
      deep_merge(left, right)
    end)
  end

  defp deep_merge(_base, override), do: override
end
