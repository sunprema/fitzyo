defmodule Fitzyo.NodeStep.Input do
  @moduledoc "Represents an input handle declared on a workflow node."
  # __spark_metadata__ is required for all Spark entity target structs
  defstruct name: nil, kind: :any, required: false, default: nil, __spark_metadata__: nil
end

defmodule Fitzyo.NodeStep.Output do
  @moduledoc "Represents an output handle declared on a workflow node."
  defstruct name: nil, kind: :any, doc: "", __spark_metadata__: nil
end

defmodule Fitzyo.NodeStep.Option do
  @moduledoc "Represents a config option declared on a workflow node."
  defstruct name: nil, kind: :any, values: nil, default: nil, __spark_metadata__: nil
end

defmodule Fitzyo.NodeStep.NodeDefinition do
  @moduledoc "Full compile-time metadata for a workflow node type. Not a Spark entity — no __spark_metadata__ needed."
  defstruct kind: nil,
            label: nil,
            category: nil,
            color: :blue,
            icon: "⬜",
            description: "",
            inputs: [],
            outputs: [],
            options: []
end
