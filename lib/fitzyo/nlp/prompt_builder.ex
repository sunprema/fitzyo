defmodule Fitzyo.NLP.PromptBuilder do
  @moduledoc """
  Builds the system prompt for NL → workflow generation.

  Serialises the live NodeRegistry into a compact, token-efficient
  representation so the LLM understands every available node type,
  its handles, and the DAG rules it must follow.
  """

  alias Fitzyo.Workflow.NodeRegistry

  @dag_rules """
  RULES:
  - Output ONLY valid JSON matching the provided schema. No markdown, no code fences.
  - Every node `id` must be unique within the graph.
  - Every edge `source` and `target` must reference a valid node `id`.
  - The graph must be a DAG — no cycles.
  - Connect outputs to inputs that are type-compatible (or use :any).
  - Trigger nodes (category: trigger) have no required inputs — place them first.
  - Assign sequential x positions (250px spacing) and center nodes vertically (y=200).
  - Use the `reasoning` field to explain your architectural decisions.
  """

  @doc """
  Builds the system prompt used for `generate/1` calls.

  Fetches the live NodeRegistry and serialises each node type with its
  category, inputs, outputs, and description into a compact JSON block.
  """
  def build_system_prompt do
    node_docs = build_node_docs()

    """
    You are a workflow graph architect for Fitzyo, an AI video production platform.
    Given a user's description, you design a workflow as a directed acyclic graph (DAG)
    using the node types listed below.

    AVAILABLE NODES:
    #{node_docs}

    #{@dag_rules}
    """
  end

  @doc """
  Builds a compact prompt suffix for graph refinement.

  Includes the current graph state so the LLM can make targeted modifications.
  """
  def build_refine_prompt(current_nodes, current_edges, instruction) do
    current_graph = Jason.encode!(%{nodes: current_nodes, edges: current_edges})

    """
    CURRENT GRAPH:
    #{current_graph}

    REFINEMENT INSTRUCTION:
    #{instruction}

    Return the full updated graph JSON. Preserve unchanged nodes exactly.
    Only modify nodes/edges needed to fulfil the instruction.
    """
  end

  # ── Private ──────────────────────────────────────────────────────────────────

  defp build_node_docs do
    NodeRegistry.all_nodes()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {cat, _} -> category_order(cat) end)
    |> Enum.map_join("\n", fn {category, nodes} ->
      header = "## #{category |> Atom.to_string() |> String.upcase()}"

      node_lines =
        Enum.map_join(nodes, "\n", fn node_def ->
          inputs = format_handles(node_def.inputs)
          outputs = format_handles(node_def.outputs)

          """
          - type: #{node_def.kind}
            label: "#{node_def.label}"
            description: #{node_def.description}
            inputs: #{inputs}
            outputs: #{outputs}\
          """
        end)

      "#{header}\n#{node_lines}"
    end)
  end

  defp format_handles([]), do: "none"

  defp format_handles(handles) do
    Enum.map_join(handles, ", ", fn h ->
      req = if Map.get(h, :required, false), do: " (required)", else: ""
      "#{h.name}:#{h.kind}#{req}"
    end)
  end

  defp category_order(:trigger), do: 0
  defp category_order(:generation), do: 1
  defp category_order(:assembly), do: 2
  defp category_order(:data), do: 3
  defp category_order(:control), do: 4
  defp category_order(_), do: 99
end
