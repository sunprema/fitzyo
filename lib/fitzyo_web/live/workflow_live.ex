defmodule FitzyoWeb.WorkflowLive do
  use FitzyoWeb, :live_view

  alias Fitzyo.Workflow.{GraphCompiler, ObanBridge}

  @hardcoded_nodes [
    %{
      "id" => "scene-1",
      "type" => "scene_generator",
      "position" => %{"x" => 280, "y" => 150},
      "data" => %{"label" => "Scene Generator", "prompt" => "A cinematic sunrise over mountains"}
    }
  ]

  @hardcoded_edges []

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Fitzyo.PubSub, "workflow:demo")
    end

    {:ok,
     socket
     |> assign(:nodes, @hardcoded_nodes)
     |> assign(:edges, @hardcoded_edges)
     |> assign(:last_pong, nil)
     |> assign(:execution_id, nil)
     |> assign(:node_states, %{})}
  end

  def handle_event("ping", _params, socket) do
    title = "Demo Workflow #{System.unique_integer([:positive])}"

    workflow =
      Fitzyo.Workflow.Workflow
      |> Ash.Changeset.for_create(:create, %{title: title})
      |> Ash.create!(domain: Fitzyo.Workflow, authorize?: false)

    Phoenix.PubSub.broadcast(Fitzyo.PubSub, "workflow:demo", {:pong, workflow.id})

    {:noreply, socket}
  end

  def handle_event("execute_workflow", _params, socket) do
    execution_id = "exec-#{System.unique_integer([:positive])}"

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Fitzyo.PubSub, "workflow:#{execution_id}")
    end

    # Build the initial node_states map — all nodes start as pending
    node_states =
      Map.new(@hardcoded_nodes, fn node ->
        {node["id"], %{status: "pending", progress: 0, thumbnail_url: nil}}
      end)

    case GraphCompiler.compile(@hardcoded_nodes, @hardcoded_edges, execution_id) do
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

  def handle_info({:pong, record_id}, socket) do
    {:noreply, assign(socket, :last_pong, record_id)}
  end

  def handle_info({:scene_progress, step_name, percent}, socket) do
    node_id = step_name_to_node_id(step_name)

    node_states =
      Map.update(socket.assigns.node_states, node_id, %{status: "generating", progress: percent, thumbnail_url: nil}, fn state ->
        %{state | status: "generating", progress: percent}
      end)

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

  def handle_info({:workflow_complete, _result}, socket) do
    {:noreply, socket}
  end

  def handle_info({:workflow_failed, _reason}, socket) do
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.workflow flash={@flash}>
      <.svelte
        name="WorkflowCanvas"
        props={%{
          nodes: @nodes,
          edges: @edges,
          last_pong: @last_pong,
          node_states: @node_states
        }}
        socket={@socket}
      />
    </Layouts.workflow>
    """
  end

  # The step name in the Oban worker is the node ID converted to atom,
  # so we reverse it back to the string node ID.
  defp step_name_to_node_id(step_name) when is_atom(step_name), do: Atom.to_string(step_name)
  defp step_name_to_node_id(step_name) when is_binary(step_name), do: step_name
end
