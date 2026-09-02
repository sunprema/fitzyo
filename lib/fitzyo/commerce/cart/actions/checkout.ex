defmodule Fitzyo.Commerce.Cart.Actions.Checkout do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  alias Fitzyo.Commerce

  @impl true
  def run(input, _opts, context) do
    cart_id = input.arguments.cart_id
    opts = Ash.Context.to_opts(context)

    load = [:item_count, :subtotal, items: [:line_total, variant: [:product]]]

    with {:ok, cart} <- Commerce.get_cart(cart_id, Keyword.put(opts, :load, load)),
         :ok <- ensure_not_empty(cart),
         order_number = generate_order_number(),
         :ok <- Commerce.clear_cart(cart_id, opts),
         {:ok, _cart} <- record_order(cart, order_number, opts) do
      lines = Enum.map(cart.items, &line/1)

      {:ok,
       %{
         order_number: order_number,
         item_count: cart.item_count,
         subtotal: cart.subtotal,
         lines: lines,
         by_source: by_source(lines)
       }}
    end
  end

  # Provenance travels with every ordered line: who put it in the cart and,
  # for an accepted proposal the human swapped, what the agent had proposed.
  defp line(item) do
    %{
      variant_id: item.variant_id,
      product_id: item.variant.product_id,
      name: item.variant.product.name,
      brand: item.variant.product.brand,
      color: item.variant.color,
      size: item.variant.size,
      quantity: item.quantity,
      label: item.label,
      line_total: item.line_total,
      source: item.source,
      proposed_variant_id: item.proposed_variant_id
    }
  end

  defp by_source(lines) do
    %{
      human: Enum.count(lines, &(&1.source == :human)),
      agent: Enum.count(lines, &(&1.source == :agent)),
      proposal: Enum.count(lines, &(&1.source == :proposal)),
      substituted: Enum.count(lines, &(&1.source == :proposal and &1.proposed_variant_id))
    }
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
