defmodule Fitzyo.CatalogFixtures do
  @moduledoc """
  Builders for catalog records in tests. Every id is globally unique so
  async tests never collide on primary keys.
  """

  alias Fitzyo.Catalog

  def unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  def category_fixture(attrs \\ %{}) do
    id = attrs[:id] || unique_id("cat")

    Catalog.create_category!(
      Map.merge(%{id: id, name: String.capitalize(id), position: 0}, attrs)
    )
  end

  def product_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    category_id = attrs[:category_id] || category_fixture().id

    Catalog.create_product!(
      Map.merge(
        %{
          id: unique_id("prod"),
          name: "Test Shirt",
          brand: "Columbia",
          category_id: category_id,
          price: Decimal.new("49.99"),
          gender: :men,
          fit: :regular,
          stretch: :low,
          activities: ["casual"]
        },
        attrs
      )
    )
  end

  @doc """
  Creates one variant per `{color, size}` pair. `stock` may be an integer or a
  function `fn color, size -> integer end`.
  """
  def variants_fixture(product, colors, sizes, stock \\ 10) do
    for {color, ci} <- Enum.with_index(colors), {size, si} <- Enum.with_index(sizes) do
      quantity = if is_function(stock, 2), do: stock.(color, size), else: stock

      Catalog.create_variant!(%{
        id: "#{product.id}_#{color}_#{String.downcase(size)}",
        product_id: product.id,
        size: size,
        color: color,
        price: product.price,
        inventory_quantity: quantity,
        position: ci * 100 + si
      })
    end
  end

  def size_guide_fixture(product, rows) do
    rows
    |> Enum.with_index()
    |> Enum.map(fn {row, index} ->
      Catalog.create_size_guide_entry!(
        Map.merge(%{product_id: product.id, position: index}, Map.new(row))
      )
    end)
  end
end
