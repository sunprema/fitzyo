defmodule FitzyoWeb.WorkflowLive do
  use FitzyoWeb, :live_view

  alias Fitzyo.Workflow.{GraphCompiler, ObanBridge, Workflow}
  alias Fitzyo.NLP.Generator

  # Fallback graph used when creating a new workflow
  @default_nodes [
    %{
      "id" => "scene-1",
      "type" => "scene_generator",
      "position" => %{"x" => 280, "y" => 150},
      "data" => %{"label" => "Scene Generator", "prompt" => "A cinematic sunrise over mountains"}
    }
  ]

  @default_edges []

  def mount(params, _session, socket) do
    {workflow, nodes, edges} = load_or_create_workflow(params, socket)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Fitzyo.PubSub, "workflow:#{workflow.id}")
    end

    node_states =
      Map.new(nodes, fn node ->
        {node["id"], %{status: "idle", progress: 0, thumbnail_url: nil}}
      end)

    node_registry = build_node_registry()

    {:ok,
     socket
     |> assign(:workflow, workflow)
     |> assign(:nodes, nodes)
     |> assign(:edges, edges)
     |> assign(:node_states, node_states)
     |> assign(:node_registry, node_registry)
     |> assign(:last_pong, nil)
     |> assign(:execution_id, nil)
     |> assign(:chat_messages, [])
     |> assign(:generating, false)
     |> assign(:reasoning, nil)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    case Ash.get(Workflow, id, domain: Fitzyo.Workflow, authorize?: false) do
      {:ok, workflow} ->
        node_states =
          Map.new(workflow.nodes, fn node ->
            {node["id"], %{status: "idle", progress: 0, thumbnail_url: nil}}
          end)

        {:noreply,
         socket
         |> assign(:workflow, workflow)
         |> assign(:nodes, workflow.nodes)
         |> assign(:edges, workflow.edges)
         |> assign(:node_states, node_states)}

      {:error, _} ->
        {:noreply, push_navigate(socket, to: "/workflow")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  # ── Canvas events ─────────────────────────────────────────────────────────────

  def handle_event("save_graph", %{"nodes" => nodes, "edges" => edges}, socket) do
    workflow = socket.assigns.workflow

    socket =
      case Ash.update(workflow, %{nodes: nodes, edges: edges},
             action: :save_graph,
             domain: Fitzyo.Workflow,
             authorize?: false
           ) do
        {:ok, updated} ->
          node_states =
            Map.new(nodes, fn node ->
              existing =
                Map.get(socket.assigns.node_states, node["id"], %{
                  status: "idle",
                  progress: 0,
                  thumbnail_url: nil
                })

              {node["id"], existing}
            end)

          socket
          |> assign(:workflow, updated)
          |> assign(:nodes, nodes)
          |> assign(:edges, edges)
          |> assign(:node_states, node_states)

        {:error, _reason} ->
          put_flash(socket, :error, "Failed to save workflow")
      end

    {:noreply, socket}
  end

  def handle_event("execute_workflow", _params, socket) do
    nodes = socket.assigns.nodes
    edges = socket.assigns.edges
    execution_id = "exec-#{System.unique_integer([:positive])}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Fitzyo.PubSub, "workflow:#{execution_id}")
    end

    node_states =
      Map.new(nodes, fn node ->
        {node["id"], %{status: "pending", progress: 0, thumbnail_url: nil}}
      end)

    case GraphCompiler.compile(nodes, edges, execution_id) do
      {:ok, reactor, reactor_context} ->
        case Reactor.run(reactor, %{}, reactor_context) do
          {:ok, result} ->
            Phoenix.PubSub.broadcast(
              Fitzyo.PubSub,
              "workflow:#{execution_id}",
              {:workflow_complete, result}
            )

            {:noreply,
             socket
             |> assign(:execution_id, execution_id)
             |> assign(:node_states, node_states)}

          {:halted, reactor_struct} ->
            ObanBridge.store_halted(execution_id, reactor_struct, reactor_context)

            {:noreply,
             socket
             |> assign(:execution_id, execution_id)
             |> assign(:node_states, node_states)}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Execution failed: #{inspect(reason)}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Compile failed: #{inspect(reason)}")}
    end
  end

  # ── NL generation events ──────────────────────────────────────────────────────

  def handle_event("nl_generate", %{"prompt" => prompt}, socket)
      when byte_size(prompt) > 0 do
    workflow_id = socket.assigns.workflow.id

    # Add user message to chat history immediately
    user_msg = %{id: System.unique_integer([:positive]), role: "user", content: prompt}
    messages = socket.assigns.chat_messages ++ [user_msg]

    Generator.generate_async(prompt, workflow_id)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:generating, true)
     |> assign(:reasoning, nil)}
  end

  def handle_event("nl_generate", _params, socket), do: {:noreply, socket}

  def handle_event("nl_refine", %{"instruction" => instruction}, socket)
      when byte_size(instruction) > 0 do
    workflow_id = socket.assigns.workflow.id
    nodes = socket.assigns.nodes
    edges = socket.assigns.edges

    user_msg = %{id: System.unique_integer([:positive]), role: "user", content: instruction}
    messages = socket.assigns.chat_messages ++ [user_msg]

    Generator.refine_async(nodes, edges, instruction, workflow_id)

    {:noreply,
     socket
     |> assign(:chat_messages, messages)
     |> assign(:generating, true)
     |> assign(:reasoning, nil)}
  end

  def handle_event("nl_refine", _params, socket), do: {:noreply, socket}

  # ── PubSub handlers ───────────────────────────────────────────────────────────

  def handle_info({:graph_generated, %{nodes: nodes, edges: edges, reasoning: reasoning}}, socket) do
    workflow = socket.assigns.workflow

    # Auto-save the generated graph
    _ =
      Ash.update(workflow, %{nodes: nodes, edges: edges},
        action: :save_graph,
        domain: Fitzyo.Workflow,
        authorize?: false
      )

    node_states =
      Map.new(nodes, fn node ->
        {node["id"], %{status: "idle", progress: 0, thumbnail_url: nil}}
      end)

    assistant_msg = %{
      id: System.unique_integer([:positive]),
      role: "assistant",
      content: "Generated a #{length(nodes)}-node workflow.",
      reasoning: reasoning
    }

    messages = socket.assigns.chat_messages ++ [assistant_msg]

    {:noreply,
     socket
     |> assign(:nodes, nodes)
     |> assign(:edges, edges)
     |> assign(:node_states, node_states)
     |> assign(:generating, false)
     |> assign(:reasoning, reasoning)
     |> assign(:chat_messages, messages)}
  end

  def handle_info({:generation_failed, reason}, socket) do
    error_msg = %{
      id: System.unique_integer([:positive]),
      role: "assistant",
      content: "Generation failed: #{inspect(reason)}",
      error: true
    }

    messages = socket.assigns.chat_messages ++ [error_msg]

    {:noreply,
     socket
     |> assign(:generating, false)
     |> assign(:chat_messages, messages)}
  end

  def handle_info({:scene_started, node_id}, socket) do
    node_states =
      Map.update(
        socket.assigns.node_states,
        node_id,
        %{status: "generating", progress: 0, thumbnail_url: nil},
        fn state -> %{state | status: "generating", progress: 0} end
      )

    {:noreply, assign(socket, :node_states, node_states)}
  end

  def handle_info({:scene_complete, node_id, clip_ref}, socket) do
    thumbnail_url =
      try do
        case Fitzyo.Video.S3Ref.presigned_url(clip_ref) do
          {:ok, url} -> url
          _ -> nil
        end
      rescue
        _ -> nil
      end

    node_states =
      Map.update(
        socket.assigns.node_states,
        node_id,
        %{status: "complete", progress: 100, thumbnail_url: thumbnail_url},
        fn state -> %{state | status: "complete", progress: 100, thumbnail_url: thumbnail_url} end
      )

    {:noreply, assign(socket, :node_states, node_states)}
  end

  def handle_info({:scene_failed, node_id, reason}, socket) do
    node_states =
      Map.update(
        socket.assigns.node_states,
        node_id,
        %{status: "failed", progress: 0, thumbnail_url: nil, error: reason},
        fn state -> %{state | status: "failed", error: reason} end
      )

    {:noreply, assign(socket, :node_states, node_states)}
  end

  def handle_info({:pong, record_id}, socket) do
    {:noreply, assign(socket, :last_pong, record_id)}
  end

  def handle_info({:scene_progress, step_name, percent}, socket) do
    node_id = step_name_to_node_id(step_name)

    node_states =
      Map.update(
        socket.assigns.node_states,
        node_id,
        %{status: "generating", progress: percent, thumbnail_url: nil},
        fn state -> %{state | status: "generating", progress: percent} end
      )

    {:noreply, assign(socket, :node_states, node_states)}
  end

  def handle_info({:step_complete, step_name, result}, socket) do
    node_id = step_name_to_node_id(step_name)

    thumbnail_url =
      case result do
        %{preview_url: url} when is_binary(url) ->
          url

        %{thumbnail: thumbnail_ref} ->
          try do
            case Fitzyo.Video.S3Ref.presigned_url(thumbnail_ref) do
              {:ok, url} -> url
              _ -> nil
            end
          rescue
            _ -> nil
          end

        _ ->
          nil
      end

    node_states =
      Map.update(socket.assigns.node_states, node_id, %{}, fn state ->
        %{state | status: "complete", progress: 100, thumbnail_url: thumbnail_url}
      end)

    {:noreply, assign(socket, :node_states, node_states)}
  end

  def handle_info({:workflow_complete, _result}, socket), do: {:noreply, socket}
  def handle_info({:workflow_failed, _reason}, socket), do: {:noreply, socket}

  # ── Render ────────────────────────────────────────────────────────────────────

  def render(assigns) do
    ~H"""
    <Layouts.workflow flash={@flash}>
      <.svelte
        name="WorkflowCanvas"
        props={%{
          nodes: @nodes,
          edges: @edges,
          last_pong: @last_pong,
          node_states: @node_states,
          node_registry: @node_registry,
          workflow_id: @workflow.id,
          chat_messages: @chat_messages,
          generating: @generating,
          reasoning: @reasoning
        }}
        socket={@socket}
      />
    </Layouts.workflow>
    """
  end

  # ── Private ───────────────────────────────────────────────────────────────────

  defp load_or_create_workflow(%{"id" => id}, _socket) do
    case Ash.get(Workflow, id, domain: Fitzyo.Workflow, authorize?: false) do
      {:ok, workflow} -> {workflow, workflow.nodes, workflow.edges}
      {:error, _} -> create_new_workflow()
    end
  end

  defp load_or_create_workflow(_params, _socket), do: create_new_workflow()

  defp create_new_workflow do
    workflow =
      Workflow
      |> Ash.Changeset.for_create(:create, %{title: "Untitled Workflow"})
      |> Ash.create!(domain: Fitzyo.Workflow, authorize?: false)

    {workflow, @default_nodes, @default_edges}
  end

  defp build_node_registry do
    Fitzyo.Workflow.NodeRegistry.all_nodes()
    |> Enum.map(fn node_def ->
      %{
        kind: node_def.kind,
        label: node_def.label,
        category: node_def.category,
        color: node_def.color,
        icon: node_def.icon,
        description: node_def.description,
        inputs: Enum.map(node_def.inputs, &%{name: &1.name, kind: &1.kind, required: &1.required}),
        outputs: Enum.map(node_def.outputs, &%{name: &1.name, kind: &1.kind, doc: &1.doc})
      }
    end)
  end

  defp step_name_to_node_id(step_name) when is_atom(step_name), do: Atom.to_string(step_name)
  defp step_name_to_node_id(step_name) when is_binary(step_name), do: step_name
end
