defmodule Fitzyo.Workflow do
  use Ash.Domain

  resources do
    resource Fitzyo.Workflow.Workflow
    resource Fitzyo.Workflow.Node
    resource Fitzyo.Workflow.WorkflowExecution
  end
end
