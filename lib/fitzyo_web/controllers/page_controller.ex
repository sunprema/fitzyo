defmodule FitzyoWeb.PageController do
  use FitzyoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
