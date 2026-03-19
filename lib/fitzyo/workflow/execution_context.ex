defmodule Fitzyo.Workflow.ExecutionContext do
  @moduledoc """
  Struct representing the mutable shared state for a single workflow execution.

  - `shared` — readable/writable by any node via NodeContext API
  - `private` — namespaced per step, not broadcast to LiveView
  """
  defstruct execution_id: nil,
            shared: %{},
            private: %{}
end
