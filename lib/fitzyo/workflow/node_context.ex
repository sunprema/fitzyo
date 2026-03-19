defmodule Fitzyo.Workflow.NodeContext do
  @moduledoc """
  Public API for reading and writing shared execution context from within NodeSteps.

  Every call is serialised through the ContextServer GenServer — no race conditions
  even with concurrent Reactor steps.

  The `context` argument is the Reactor context map which must contain:
  - `:context_server` — PID of the ContextServer for this execution
  - `:execution_id`   — execution identifier string

  ## Namespace convention (never write outside your namespace):
  - `:scenes`         → SceneGeneratorStep
  - `:characters`     → CharacterReferenceStep
  - `:active_style_pack` → StyleReferenceStep
  - `:approvals`      → HumanApprovalNode
  - `:stats`          → Any node (increment counters)
  """

  alias Fitzyo.Workflow.ContextServer

  @doc "Read a value from shared context. key_path can be an atom or list of atoms."
  def read(context, key_path) do
    ContextServer.read(context.context_server, key_path)
  end

  @doc "Write a value to shared context. Serialised through ContextServer."
  def write(context, key_path, value) do
    ContextServer.write(context.context_server, key_path, value)
  end

  @doc "Deep-merge a map into shared context root."
  def merge(context, map) do
    ContextServer.merge(context.context_server, map)
  end

  @doc "Read a private value namespaced to the given step name."
  def read_private(context, step_name, key) do
    ContextServer.read_private(context.context_server, step_name, key)
  end

  @doc "Write a private value namespaced to the given step name."
  def write_private(context, step_name, key, value) do
    ContextServer.write_private(context.context_server, step_name, key, value)
  end

  @doc "Returns a snapshot of the full execution context (for debugging)."
  def snapshot(context) do
    ContextServer.snapshot(context.context_server)
  end
end
