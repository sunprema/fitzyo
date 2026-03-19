defmodule Fitzyo.Workflow.Nodes.PromptTemplateStep do
  @moduledoc """
  Renders a Liquid/EEx-style template with dynamic variables to produce
  a final prompt string passed to generation nodes.
  """
  use Fitzyo.NodeStep

  node_def do
    kind :prompt_template
    label "Prompt Template"
    category :data
    color :teal
    icon "📝"
    description "Renders a template with variables to produce a generation prompt"

    input :variables, kind: :map, required: false

    output :prompt, kind: :string, doc: "Rendered prompt string ready for a generation node"

    config do
      option :template,
        kind: :string,
        default: "A cinematic {{scene_description}} in {{style}} style"

      option :fallback_prompt,
        kind: :string,
        default: "A cinematic scene"
    end
  end

  def run(arguments, _context, _options) do
    variables = arguments[:variables] || %{}
    template = "A cinematic scene"

    rendered =
      Enum.reduce(variables, template, fn {key, value}, acc ->
        String.replace(acc, "{{#{key}}}", to_string(value))
      end)

    {:ok, %{prompt: rendered}}
  end
end
