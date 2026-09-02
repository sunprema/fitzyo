defmodule Fitzyo.Catalog.Variant.Preparations.ApplyMatchConstraints do
  @moduledoc """
  Turns the arguments of `Variant.matching` into a filter.

  Variant-level constraints (sizes, colors, exclusions, price, stock) apply directly;
  product-level constraints (category, brand, fit, activities, gender) are
  applied through the `product` relationship.
  """

  use Ash.Resource.Preparation
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> filter_product_id(arg(query, :product_id))
    |> filter_category(arg(query, :category))
    |> filter_sizes(sizes(arg(query, :size), arg(query, :sizes)))
    |> filter_colors(downcase_all(arg(query, :colors)))
    |> exclude_colors(downcase_all(arg(query, :exclude_colors)))
    |> filter_brands(downcase_all(arg(query, :brands)))
    |> exclude_brands(downcase_all(arg(query, :exclude_brands)))
    |> filter_fit(arg(query, :fit))
    |> filter_activities(downcase_all(arg(query, :activities)))
    |> filter_gender(arg(query, :gender))
    |> filter_price_max(arg(query, :price_max))
    |> filter_in_stock(arg(query, :in_stock_only))
  end

  defp arg(query, name), do: Ash.Query.get_argument(query, name)

  defp downcase(nil), do: nil
  defp downcase(value), do: value |> String.trim() |> String.downcase()

  defp downcase_all(nil), do: []
  defp downcase_all(values), do: Enum.map(values, &downcase/1)

  defp filter_product_id(query, nil), do: query
  defp filter_product_id(query, id), do: Ash.Query.filter(query, product_id == ^id)

  defp filter_category(query, nil), do: query
  defp filter_category(query, ""), do: query
  defp filter_category(query, cat), do: Ash.Query.filter(query, product.category_id == ^cat)

  defp sizes(size, sizes) do
    [size | List.wrap(sizes)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> downcase_all()
    |> Enum.uniq()
  end

  defp filter_sizes(query, []), do: query
  defp filter_sizes(query, sizes), do: Ash.Query.filter(query, string_downcase(size) in ^sizes)

  defp filter_colors(query, []), do: query

  defp filter_colors(query, colors),
    do: Ash.Query.filter(query, string_downcase(color) in ^colors)

  defp exclude_colors(query, []), do: query

  defp exclude_colors(query, colors),
    do: Ash.Query.filter(query, string_downcase(color) not in ^colors)

  defp filter_brands(query, []), do: query

  defp filter_brands(query, brands),
    do: Ash.Query.filter(query, string_downcase(product.brand) in ^brands)

  defp exclude_brands(query, []), do: query

  defp exclude_brands(query, brands),
    do: Ash.Query.filter(query, string_downcase(product.brand) not in ^brands)

  defp filter_fit(query, nil), do: query
  defp filter_fit(query, fit), do: Ash.Query.filter(query, product.fit == ^fit)

  defp filter_activities(query, []), do: query

  defp filter_activities(query, activities),
    do: Ash.Query.filter(query, intersects(product.activities, ^activities))

  defp filter_gender(query, nil), do: query

  defp filter_gender(query, gender) do
    age_group = Fitzyo.Catalog.Types.Gender.age_group(gender)

    Ash.Query.filter(
      query,
      product.gender == ^gender or
        (product.gender == :unisex and product.age_group == ^age_group)
    )
  end

  defp filter_price_max(query, nil), do: query
  defp filter_price_max(query, max), do: Ash.Query.filter(query, price <= ^max)

  defp filter_in_stock(query, true), do: Ash.Query.filter(query, inventory_quantity > 0)
  defp filter_in_stock(query, _), do: query
end
