defmodule Fitzyo.Workflow.Nodes.ConditionalStep do
  @moduledoc """
  Routes workflow execution down one of two paths based on a condition
  evaluated against the input value. Analogous to an if/else branch.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :conditional
    label "Conditional"
    category :control
    color :gray
    icon "🔀"
    description "Routes to true or false branch based on a condition"

    input :value, kind: :any, required: true

    output :true_branch, kind: :any, doc: "Passes value through when condition is truthy"
    output :false_branch, kind: :any, doc: "Passes value through when condition is falsy"
    output :matched, kind: :boolean, doc: "Whether the condition evaluated to true"

    config do
      option :operator,
        kind: :atom,
        values: [:equals, :not_equals, :greater_than, :less_than, :contains, :exists],
        default: :exists

      option :compare_value,
        kind: :string,
        default: ""
    end
  end

  def run(arguments, _context, _options) do
    value = arguments[:value]
    matched = !!value

    {:ok, %{
      true_branch: (if matched, do: value, else: nil),
      false_branch: (if matched, do: nil, else: value),
      matched: matched
    }}
  end
end
