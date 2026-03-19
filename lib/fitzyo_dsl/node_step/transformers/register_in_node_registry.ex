defmodule Fitzyo.NodeStep.Transformers.RegisterInNodeRegistry do
  @moduledoc """
  Injects `__register__/0` into the node module. At runtime, NodeRegistry calls this
  on every module that exports it, populating the registry after the app starts.
  """
  use Spark.Dsl.Transformer

  def before?(_), do: false

  def after?(Fitzyo.NodeStep.Transformers.GenerateNodeDefinition), do: true
  def after?(_), do: false

  def transform(dsl_state) do
    code =
      quote do
        @doc false
        def __register__ do
          Fitzyo.Workflow.NodeRegistry.register(__MODULE__, node_definition())
        end
      end

    {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], code)}
  end
end
