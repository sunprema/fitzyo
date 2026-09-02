defmodule Fitzyo.Commerce.CartItem.Actions.Add do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Fitzyo.Catalog
  alias Fitzyo.Commerce.CartItem

  @impl true
  def run(input, _opts, context) do
    cart_id = Ash.ActionInput.get_argument(input, :cart_id)
    variant_id = Ash.ActionInput.get_argument(input, :variant_id)
    quantity = Ash.ActionInput.get_argument(input, :quantity) || 1
    label = Ash.ActionInput.get_argument(input, :label)
    source = Ash.ActionInput.get_argument(input, :source) || :human
    proposed = Ash.ActionInput.get_argument(input, :proposed_variant_id)

    opts = Ash.Context.to_opts(context)

    with {:ok, variant} <- fetch_variant(variant_id),
         :ok <- ensure_in_stock(variant, quantity),
         {:ok, existing} <- fetch_existing(cart_id, variant_id, opts) do
      upsert(existing, cart_id, variant, quantity, label, {source, proposed}, opts)
    end
  end

  defp fetch_variant(variant_id) do
    case Catalog.get_variant(variant_id, load: [:available, product: [:name]]) do
      {:ok, variant} ->
        {:ok, variant}

      {:error, _} ->
        {:error, invalid(:variant_id, variant_id, "VARIANT_NOT_FOUND: no variant #{variant_id}")}
    end
  end

  defp ensure_in_stock(%{available: false, id: id}, _quantity) do
    {:error, invalid(:variant_id, id, "VARIANT_UNAVAILABLE: #{id} is out of stock")}
  end

  defp ensure_in_stock(%{inventory_quantity: stock, id: id}, quantity) when quantity > stock do
    {:error, invalid(:quantity, quantity, "INSUFFICIENT_STOCK: only #{stock} of #{id} available")}
  end

  defp ensure_in_stock(_variant, _quantity), do: :ok

  defp fetch_existing(cart_id, variant_id, opts) do
    CartItem
    |> Ash.Query.filter(cart_id == ^cart_id and variant_id == ^variant_id)
    |> Ash.read_one(opts)
  end

  defp upsert(nil, cart_id, variant, quantity, label, {source, proposed}, opts) do
    CartItem
    |> Ash.Changeset.for_create(
      :create,
      %{
        cart_id: cart_id,
        variant_id: variant.id,
        quantity: quantity,
        label: label,
        unit_price: variant.price,
        source: source,
        proposed_variant_id: proposed
      },
      opts
    )
    |> Ash.create()
  end

  defp upsert(existing, _cart_id, variant, quantity, label, _provenance, opts) do
    if existing.quantity + quantity > variant.inventory_quantity do
      {:error,
       invalid(
         :quantity,
         quantity,
         "INSUFFICIENT_STOCK: only #{variant.inventory_quantity} of #{variant.id} available"
       )}
    else
      existing
      |> Ash.Changeset.for_update(:increment, %{by: quantity}, opts)
      |> maybe_set_label(label)
      |> Ash.update()
    end
  end

  defp maybe_set_label(changeset, nil), do: changeset

  defp maybe_set_label(changeset, label),
    do: Ash.Changeset.force_change_attribute(changeset, :label, label)

  defp invalid(field, value, message) do
    Ash.Error.Changes.InvalidArgument.exception(field: field, value: value, message: message)
  end
end
