defmodule Fitzyo.NLP.GraphSchema do
  @moduledoc """
  Generates a JSON Schema for the LLM's workflow graph output.

  Built dynamically from the live NodeRegistry so the LLM can only emit
  node types that actually exist — hallucinated types are structurally
  impossible to produce.

  The schema enforces:
  - `nodes`  — array of node objects with valid `type` enum
  - `edges`  — array of connection objects
  - `reasoning` — free-text explanation of the graph design
  """

  alias Fitzyo.Workflow.NodeRegistry

  @doc """
  Returns the JSON Schema map for the `generate` endpoint.

  Call this at request time (not compile time) so it always reflects
  whatever nodes are currently registered.
  """
  def json_schema do
    valid_types =
      NodeRegistry.all_nodes()
      |> Enum.map(fn def -> Atom.to_string(def.kind) end)
      |> Enum.sort()

    %{
      "type" => "object",
      "required" => ["nodes", "edges", "reasoning"],
      "additionalProperties" => false,
      "properties" => %{
        "reasoning" => %{
          "type" => "string",
          "description" =>
            "Explain your graph design decisions: which node types you chose and why, how data flows between them, and any trade-offs."
        },
        "nodes" => %{
          "type" => "array",
          "minItems" => 1,
          "items" => %{
            "type" => "object",
            "required" => ["id", "type", "position", "data"],
            "additionalProperties" => false,
            "properties" => %{
              "id" => %{
                "type" => "string",
                "description" => "Unique node ID within this graph, e.g. \"node-1\""
              },
              "type" => %{
                "type" => "string",
                "enum" => valid_types,
                "description" => "Node type — must be one of the registered types"
              },
              "position" => %{
                "type" => "object",
                "required" => ["x", "y"],
                "additionalProperties" => false,
                "properties" => %{
                  "x" => %{"type" => "number"},
                  "y" => %{"type" => "number"}
                }
              },
              "data" => %{
                "type" => "object",
                "required" => ["label"],
                "properties" => %{
                  "label" => %{"type" => "string"}
                }
              }
            }
          }
        },
        "edges" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["id", "source", "target"],
            "additionalProperties" => false,
            "properties" => %{
              "id" => %{"type" => "string"},
              "source" => %{"type" => "string"},
              "target" => %{"type" => "string"},
              "sourceHandle" => %{"type" => "string"},
              "targetHandle" => %{"type" => "string"}
            }
          }
        }
      }
    }
  end
end
