defmodule Fitzyo.NodeStep do
  @moduledoc """
  Base module for all workflow node implementations.

  `use Fitzyo.NodeStep` sets up the Spark DSL (`node_def do ... end`), generates
  `node_definition/0` at compile time, and injects `__register__/0` so the node
  is auto-discovered by NodeRegistry at application startup.

  The module must implement `run/3` and optionally override `compensate/4` / `undo/4`.

  ## Example

      defmodule Fitzyo.Workflow.Nodes.MyStep do
        use Fitzyo.NodeStep

        node_def do
          kind     :my_step
          label    "My Step"
          category :generation

          input  :prompt, kind: :string, required: true
          output :result, kind: :string, doc: "The result"
        end

        def run(arguments, _context, _step) do
          {:ok, arguments.prompt}
        end
      end
  """

  use Spark.Dsl, default_extensions: [extensions: [Fitzyo.NodeStep.Dsl]]

  # Inject default no-op compensate/undo into every NodeStep module.
  # Override in steps that have side effects.
  def handle_before_compile(_opts) do
    quote do
      @behaviour Reactor.Step
      def async?(_step), do: true
      def can?(_step, _capability), do: false
      def compensate(_reason, _arguments, _context, _options), do: :ok
      def undo(_value, _arguments, _context, _options), do: :ok
      defoverridable async?: 1, can?: 2, compensate: 4, undo: 4
    end
  end
end
