defmodule Fitzyo.NodeStep.Dsl do
  @moduledoc """
  Spark DSL extension for declaring workflow node types.

  Used via `use Fitzyo.NodeStep`. Generates `node_definition/0` and
  auto-registers the node in `NodeRegistry` when the module loads.
  """

  @option_entity %Spark.Dsl.Entity{
    name: :option,
    args: [:name],
    target: Fitzyo.NodeStep.Option,
    schema: [
      name: [type: :atom, required: true],
      kind: [type: :atom, default: :any],
      values: [type: {:list, :atom}, required: false],
      default: [type: :any, required: false]
    ]
  }

  @config_section %Spark.Dsl.Section{
    name: :config,
    entities: [@option_entity]
  }

  @input_entity %Spark.Dsl.Entity{
    name: :input,
    args: [:name],
    target: Fitzyo.NodeStep.Input,
    schema: [
      name: [type: :atom, required: true],
      kind: [type: :atom, default: :any],
      required: [type: :boolean, default: false],
      default: [type: :any, required: false]
    ]
  }

  @output_entity %Spark.Dsl.Entity{
    name: :output,
    args: [:name],
    target: Fitzyo.NodeStep.Output,
    schema: [
      name: [type: :atom, required: true],
      kind: [type: :atom, default: :any],
      doc: [type: :string, default: ""]
    ]
  }

  @node_section %Spark.Dsl.Section{
    name: :node_def,
    schema: [
      kind: [type: :atom, required: true, doc: "Unique atom identifying this node type"],
      label: [type: :string, required: true, doc: "Human-readable display name"],
      category: [
        type: {:one_of, [:generation, :trigger, :assembly, :data, :control]},
        required: true,
        doc: "Node category (controls palette grouping and default color)"
      ],
      color: [
        type: {:one_of, [:violet, :amber, :blue, :teal, :gray]},
        default: :blue,
        doc: "Accent color for the node in the canvas"
      ],
      icon: [type: :string, default: "⬜", doc: "Emoji or icon identifier"],
      description: [type: :string, default: "", doc: "Short description shown in palette"]
    ],
    entities: [@input_entity, @output_entity],
    sections: [@config_section]
  }

  use Spark.Dsl.Extension,
    sections: [@node_section],
    transformers: [
      Fitzyo.NodeStep.Transformers.GenerateNodeDefinition,
      Fitzyo.NodeStep.Transformers.RegisterInNodeRegistry
    ],
    verifiers: [
      Fitzyo.NodeStep.Verifiers.RequireAtLeastOneOutput,
      Fitzyo.NodeStep.Verifiers.TriggerNodesHaveNoRequiredInputs
    ]
end
