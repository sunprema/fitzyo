defmodule Fitzyo.NodeStep.Verifiers.RequireAtLeastOneOutput do
  @moduledoc "Compile error if a node type declares no output handles."
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    entities = Spark.Dsl.Verifier.get_entities(dsl_state, [:node_def])
    outputs = Enum.filter(entities, &is_struct(&1, Fitzyo.NodeStep.Output))

    if Enum.empty?(outputs) do
      module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

      {:error,
       Spark.Error.DslError.exception(
         module: module,
         message: "NodeStep requires at least one `output` declaration in the `node` block.",
         path: [:node_def]
       )}
    else
      :ok
    end
  end
end
