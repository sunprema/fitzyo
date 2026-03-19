defmodule Fitzyo.NLP.Generator do
  @moduledoc """
  NL → workflow graph generator.

  In Slice 3 the Claude API call is mocked: `generate/1` and `refine/3`
  return deterministic graphs built from keyword analysis of the prompt.
  The real API call is a one-line swap in `call_api/2`.

  All generated graphs are validated through `GraphValidator` before
  being broadcast to the LiveView — invalid output is never passed to
  the canvas.

  ## Async usage

      # In LiveView handle_event:
      Generator.generate_async(prompt, workflow_id, execution_id)
      # Then handle_info({:graph_generated, graph}) or {:generation_failed, reason}
  """

  alias Fitzyo.Workflow.GraphValidator
  alias Fitzyo.NLP.PromptBuilder

  # ── Public API ───────────────────────────────────────────────────────────────

  @doc """
  Generates a workflow graph from a natural language prompt.

  Returns `{:ok, %{nodes: [...], edges: [...], reasoning: "..."}}` or
  `{:error, reason}`.
  """
  def generate(prompt) do
    system = PromptBuilder.build_system_prompt()

    with {:ok, raw} <- call_api(system, prompt),
         {:ok, graph} <- validate_graph(raw) do
      {:ok, graph}
    end
  end

  @doc """
  Refines an existing graph given a natural language instruction.
  """
  def refine(current_nodes, current_edges, instruction) do
    system = PromptBuilder.build_system_prompt()
    user = PromptBuilder.build_refine_prompt(current_nodes, current_edges, instruction)

    with {:ok, raw} <- call_api(system, user),
         {:ok, graph} <- validate_graph(raw) do
      {:ok, graph}
    end
  end

  @doc """
  Fires `generate/1` asynchronously in a supervised Task.

  Results are broadcast to `"workflow:\#{topic_id}"` as:
  - `{:graph_generated, graph}` on success
  - `{:generation_failed, reason}` on error
  """
  def generate_async(prompt, topic_id) do
    Task.start(fn ->
      result =
        case generate(prompt) do
          {:ok, graph} -> {:graph_generated, graph}
          {:error, reason} -> {:generation_failed, reason}
        end

      Phoenix.PubSub.broadcast(Fitzyo.PubSub, "workflow:#{topic_id}", result)
    end)
  end

  @doc """
  Fires `refine/3` asynchronously. Same PubSub contract as `generate_async/2`.
  """
  def refine_async(current_nodes, current_edges, instruction, topic_id) do
    Task.start(fn ->
      result =
        case refine(current_nodes, current_edges, instruction) do
          {:ok, graph} -> {:graph_generated, graph}
          {:error, reason} -> {:generation_failed, reason}
        end

      Phoenix.PubSub.broadcast(Fitzyo.PubSub, "workflow:#{topic_id}", result)
    end)
  end

  # ── API call (mocked for Slice 3) ────────────────────────────────────────────

  # Real implementation: replace this with an Anthropic API call using
  # structured output (JSON Schema from Fitzyo.NLP.GraphSchema).
  #
  # Example real call:
  #   Req.post("https://api.anthropic.com/v1/messages",
  #     headers: [...],
  #     json: %{
  #       model: "claude-opus-4-6",
  #       system: system,
  #       messages: [%{role: "user", content: user_prompt}],
  #       tools: [%{name: "workflow_graph", input_schema: GraphSchema.json_schema()}],
  #       tool_choice: %{type: "tool", name: "workflow_graph"}
  #     }
  #   )
  defp call_api(_system, user_prompt) do
    # Simulate realistic API latency
    Process.sleep(Enum.random(800..1800))

    {:ok, build_mock_graph(user_prompt)}
  end

  # ── Mock graph builder ────────────────────────────────────────────────────────

  defp build_mock_graph(prompt) do
    lower = String.downcase(prompt)

    # Select node sequence based on keywords
    sequence = determine_node_sequence(lower)

    nodes = build_nodes(sequence)
    edges = build_edges(nodes)
    reasoning = build_reasoning(sequence, prompt)

    %{nodes: nodes, edges: edges, reasoning: reasoning}
  end

  defp determine_node_sequence(prompt) do
    trigger =
      cond do
        has_any?(prompt, ["webhook", "http", "request", "api call", "event"]) ->
          :webhook_trigger

        has_any?(prompt, ["schedule", "cron", "every hour", "daily", "weekly", "recurring"]) ->
          :cron_trigger

        true ->
          nil
      end

    data_nodes =
      []
      |> maybe_add(has_any?(prompt, ["style", "look", "aesthetic", "cinematic", "theme"]), :style_reference)
      |> maybe_add(has_any?(prompt, ["character", "person", "actor", "face", "avatar"]), :character_animate)
      |> maybe_add(has_any?(prompt, ["asset", "image", "background", "reference", "upload"]), :asset_loader)
      |> maybe_add(has_any?(prompt, ["template", "prompt", "text", "caption", "narration"]), :prompt_template)

    generation_nodes =
      []
      |> maybe_add(has_any?(prompt, ["background", "environment", "landscape", "setting"]), :background_gen)
      |> maybe_add(has_any?(prompt, ["effect", "vfx", "overlay", "particle", "fire", "smoke"]), :vfx_overlay)
      |> then(fn nodes ->
        # Always include scene_generator unless we already have something
        if nodes == [], do: [:scene_generator], else: nodes ++ [:scene_generator]
      end)

    control_nodes =
      []
      |> maybe_add(has_any?(prompt, ["parallel", "simultaneously", "at the same time"]), :parallel_merge)
      |> maybe_add(has_any?(prompt, ["if", "condition", "branch", "when", "fallback"]), :conditional)

    assembly_nodes =
      []
      |> maybe_add(has_any?(prompt, ["music", "audio", "sound", "narration", "voice"]), :audio_mixer)
      |> maybe_add(has_any?(prompt, ["trim", "cut", "clip", "shorten", "duration"]), :clip_trimmer)
      |> then(&(&1 ++ [:final_export]))

    [trigger | data_nodes ++ generation_nodes ++ control_nodes ++ assembly_nodes]
    |> Enum.reject(&is_nil/1)
  end

  defp build_nodes(sequence) do
    sequence
    |> Enum.with_index()
    |> Enum.map(fn {kind, i} ->
      %{
        "id" => "#{kind}-#{i + 1}",
        "type" => Atom.to_string(kind),
        "position" => %{"x" => i * 280 + 80, "y" => 200},
        "data" => %{"label" => humanize(kind)}
      }
    end)
  end

  defp build_edges(nodes) do
    nodes
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {[src, tgt], i} ->
      %{
        "id" => "e-#{i + 1}",
        "source" => src["id"],
        "target" => tgt["id"],
        "sourceHandle" => "output",
        "targetHandle" => "input"
      }
    end)
  end

  defp build_reasoning(sequence, prompt) do
    node_list = Enum.map_join(sequence, " → ", &humanize/1)

    """
    For the prompt "#{String.slice(prompt, 0, 80)}#{if String.length(prompt) > 80, do: "…", else: ""}",
    I designed a #{length(sequence)}-node linear pipeline: #{node_list}.

    #{describe_choices(sequence)}

    The nodes connect left-to-right so each step's output feeds the next,
    keeping the execution graph acyclic and easy to reason about.
    """
    |> String.trim()
  end

  defp describe_choices(sequence) do
    sequence
    |> Enum.map(fn
      :webhook_trigger -> "The webhook trigger fires when an HTTP event arrives."
      :cron_trigger -> "The cron trigger runs on a recurring schedule."
      :style_reference -> "Style Reference loads aesthetic constraints to guide generation."
      :character_animate -> "Character Animate handles any person/character in the scene."
      :asset_loader -> "Asset Loader pulls in referenced images or existing assets."
      :prompt_template -> "Prompt Template ensures consistent prompt formatting."
      :background_gen -> "Background Gen creates the environment before the scene."
      :vfx_overlay -> "VFX Overlay composites particle effects over the clip."
      :scene_generator -> "Scene Generator calls the AI video API to produce the core clip."
      :parallel_merge -> "Parallel Merge waits for all concurrent branches before proceeding."
      :conditional -> "Conditional branches execution based on the scene result."
      :audio_mixer -> "Audio Mixer adds music or narration to the clip."
      :clip_trimmer -> "Clip Trimmer ensures the output meets the target duration."
      :final_export -> "Final Export assembles and uploads the finished video to Tigris."
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  # ── Graph validation ──────────────────────────────────────────────────────────

  defp validate_graph(%{nodes: nodes, edges: edges, reasoning: reasoning}) do
    case GraphValidator.validate(nodes, edges) do
      {:ok, _topo} ->
        {:ok, %{nodes: nodes, edges: edges, reasoning: reasoning}}

      {:error, :cycle_detected} ->
        {:error, "Generated graph contains a cycle — this is a bug in the mock builder"}

      {:error, :empty_graph} ->
        {:error, "Generated graph has no nodes"}
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────────────

  defp has_any?(text, keywords), do: Enum.any?(keywords, &String.contains?(text, &1))

  defp maybe_add(list, true, item), do: list ++ [item]
  defp maybe_add(list, false, _item), do: list

  defp humanize(atom) when is_atom(atom) do
    atom
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
