defmodule FitzyoWeb.XYFlowLive do
  use FitzyoWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <.svelte name="XYFlowExample" socket={@socket} />
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :number, 5)}
  end
end
