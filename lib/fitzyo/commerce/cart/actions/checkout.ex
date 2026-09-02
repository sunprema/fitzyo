defmodule Fitzyo.Commerce.Cart.Actions.Checkout do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Fitzyo.Commerce

  @impl true
  def run(input, _opts, context) do
    cart_id = input.arguments.cart_id
    opts = Ash.Context.to_opts(context)

    with {:ok, cart} <-
           Commerce.get_cart(cart_id, Keyword.put(opts, :load, [:item_count, :subtotal])),
         :ok <- ensure_not_empty(cart),
         order_number = generate_order_number(),
         :ok <- Commerce.clear_cart(cart_id, opts),
         {:ok, _cart} <- record_order(cart, order_number, opts) do
      {:ok, %{order_number: order_number, item_count: cart.item_count, subtotal: cart.subtotal}}
    end
  end

  defp ensure_not_empty(%{item_count: count}) when count > 0, do: :ok

  defp ensure_not_empty(_cart) do
    {:error,
     Ash.Error.Changes.InvalidArgument.exception(
       field: :cart_id,
       message: "CART_EMPTY: there is nothing to check out"
     )}
  end

  defp record_order(cart, order_number, opts) do
    cart
    |> Ash.Changeset.new()
    |> Ash.Changeset.for_update(:record_order, %{last_order_number: order_number}, opts)
    |> Ash.update()
  end

  defp generate_order_number do
    suffix = :crypto.strong_rand_bytes(3) |> Base.encode16()
    "FZ-#{suffix}"
  end
end
