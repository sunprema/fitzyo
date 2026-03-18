# `/lib/app_web/live/live_svelte.ex`
defmodule FitzyoWeb.SvelteLive do
  use FitzyoWeb, :live_view

  def render(assigns) do
    ~H"""
    <.svelte name="Example" props={%{number: @number}} socket={@socket} />
    """
  end

  def handle_event("set_number", %{"number" => number}, socket) do
    {:noreply, assign(socket, :number, number)}
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, :number, 5)}
  end
end
