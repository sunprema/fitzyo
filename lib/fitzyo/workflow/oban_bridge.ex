defmodule Fitzyo.Workflow.ObanBridge do
  @moduledoc """
  Bridges Reactor step execution with Oban workers for long-running operations.

  ## The suspend/resume contract

  A NodeStep calls `suspend_for_oban/4` from its `run/3` callback and returns
  the result directly:

      def run(arguments, context, step) do
        suspend_for_oban(context, step, Fitzyo.Workers.SceneGenerationWorker, %{
          "prompt" => arguments.prompt
        })
      end

  On the first call, the step gets `{:halt, step_ref}` — Reactor halts.
  The caller (WorkflowLive) stores `{reactor_struct, context}` via `store_halted/3`.

  When the Oban worker completes, it calls `resume_reactor/3`. This stores the
  result, fetches the halted reactor, and calls `Reactor.run/4` again.
  On the second pass through the step, `suspend_for_oban/4` finds the result and
  returns `{:ok, result}`.
  """

  alias Fitzyo.Workflow.SuspendedReactors

  @doc """
  Called by a NodeStep's run/3. Returns `{:halt, step_ref}` on first invocation
  (suspending Reactor), or `{:ok, result}` on resumption.
  """
  def suspend_for_oban(context, step_name, worker_module, job_args) do
    step_ref = step_ref(context.execution_id, step_name)

    case SuspendedReactors.get_result(step_ref) do
      {:ok, result} ->
        SuspendedReactors.delete_result(step_ref)
        {:ok, result}

      :not_found ->
        args = Map.merge(job_args, %{"execution_id" => context.execution_id, "step_ref" => step_ref})
        {:ok, _job} = Oban.insert(worker_module.new(args))
        {:halt, step_ref}
    end
  end

  @doc "Store a halted reactor with its context. Called by WorkflowLive after Reactor.run returns {:halted, reactor}."
  def store_halted(execution_id, reactor_struct, reactor_context) do
    SuspendedReactors.store_reactor(execution_id, reactor_struct, reactor_context)
  end

  @doc """
  Called by Oban workers when a job completes. Stores the result and resumes
  the halted Reactor, broadcasting progress via PubSub.
  """
  def resume_reactor(execution_id, step_ref, result) do
    SuspendedReactors.store_result(step_ref, result)

    case SuspendedReactors.get_reactor(execution_id) do
      {:ok, reactor_struct, reactor_context} ->
        SuspendedReactors.delete_reactor(execution_id)
        do_resume(execution_id, reactor_struct, reactor_context)

      {:error, :not_found} ->
        {:error, :reactor_not_found}
    end
  end

  defp do_resume(execution_id, reactor_struct, context) do
    case Reactor.run(reactor_struct, %{}, context) do
      {:ok, result} ->
        Phoenix.PubSub.broadcast(
          Fitzyo.PubSub,
          "workflow:#{execution_id}",
          {:workflow_complete, result}
        )

        {:ok, result}

      {:halted, new_reactor} ->
        # Another step suspended — store updated reactor state
        SuspendedReactors.store_reactor(execution_id, new_reactor, context)
        {:halted, execution_id}

      {:error, reason} ->
        Phoenix.PubSub.broadcast(
          Fitzyo.PubSub,
          "workflow:#{execution_id}",
          {:workflow_failed, reason}
        )

        {:error, reason}
    end
  end

  defp step_ref(execution_id, step_name), do: "#{execution_id}:#{step_name}"
end
