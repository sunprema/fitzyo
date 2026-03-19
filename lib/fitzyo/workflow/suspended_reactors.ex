defmodule Fitzyo.Workflow.SuspendedReactors do
  @moduledoc """
  ETS-backed store for halted Reactor structs and pending step results.

  When a Reactor step halts (to wait for an Oban job), the halted %Reactor{} struct
  is stored here keyed by execution_id. When the Oban job completes, the result is
  stored keyed by step_ref, then the reactor is resumed.

  This module is a plain ETS table — no GenServer needed since the access pattern
  does not have overlapping concurrent writes for a single execution.
  """

  @table :fitzyo_suspended_reactors

  @doc "Create the ETS table. Called once at application startup."
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  end

  # --- Halted reactor storage ---

  @doc "Store a halted reactor struct and its context for later resumption."
  def store_reactor(execution_id, reactor_struct, reactor_context) do
    :ets.insert(@table, {{:reactor, execution_id}, reactor_struct, reactor_context})
    :ok
  end

  @doc "Fetch the halted reactor and context for an execution."
  def get_reactor(execution_id) do
    case :ets.lookup(@table, {:reactor, execution_id}) do
      [{{:reactor, ^execution_id}, reactor, context}] -> {:ok, reactor, context}
      [] -> {:error, :not_found}
    end
  end

  @doc "Delete the stored reactor for an execution (after successful resumption)."
  def delete_reactor(execution_id) do
    :ets.delete(@table, {:reactor, execution_id})
    :ok
  end

  # --- Step result storage ---

  @doc "Store the result of a completed Oban job so the suspended step can pick it up."
  def store_result(step_ref, result) do
    :ets.insert(@table, {{:result, step_ref}, result})
    :ok
  end

  @doc "Fetch and consume a pending result. Returns :not_found if not ready yet."
  def get_result(step_ref) do
    case :ets.lookup(@table, {:result, step_ref}) do
      [{{:result, ^step_ref}, result}] -> {:ok, result}
      [] -> :not_found
    end
  end

  @doc "Delete a consumed result."
  def delete_result(step_ref) do
    :ets.delete(@table, {:result, step_ref})
    :ok
  end
end
