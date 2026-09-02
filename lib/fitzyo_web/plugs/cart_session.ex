defmodule FitzyoWeb.Plugs.CartSession do
  @moduledoc """
  Gives every browser session a stable cart id.

  The id lives in the signed session cookie; the cart row itself is created
  lazily by `FitzyoWeb.StoreLive`. This is the only identity the retailer
  keeps for a shopper.
  """

  import Plug.Conn

  @session_key "cart_id"

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      nil -> put_session(conn, @session_key, Ash.UUID.generate())
      _id -> conn
    end
  end

  @doc "The session key under which the cart id is stored."
  def session_key, do: @session_key
end
