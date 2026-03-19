defmodule Fitzyo.NodeStep.Verifiers.TriggerNodesHaveNoRequiredInputs do
  @moduledoc "Compile error if a trigger node declares required inputs — triggers must be self-starting."
  use Spark.Dsl.Verifier

  def verify(dsl_state) do
    category = Spark.Dsl.Verifier.get_option(dsl_state, [:node_def], :category)

    if category == :trigger do
      entities = Spark.Dsl.Verifier.get_entities(dsl_state, [:node_def])
      required_inputs = Enum.filter(entities, &is_struct(&1, Fitzyo.NodeStep.Input) && &1.required)

      if Enum.any?(required_inputs) do
        module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
        names = Enum.map(required_inputs, & &1.name)

        {:error,
         Spark.Error.DslError.exception(
           module: module,
           message:
             "Trigger nodes cannot have required inputs. " <>
               "Mark these inputs as `required: false` or remove them: #{inspect(names)}",
           path: [:node_def]
         )}
      else
        :ok
      end
    else
      :ok
    end
  end
end
