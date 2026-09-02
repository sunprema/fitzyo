defmodule Fitzyo.Catalog.Product.Preparations.ApplyBrowseFilters do
  @moduledoc """
  Turns the arguments of `Product.browse` into a filter.

  Semantics (WEBMCP_SPEC §15):

    * AND between facets, OR within a facet.
    * `sizes` and `colors` must be satisfied by the same in-stock variant.
    * Text matching is case-insensitive; every whitespace-separated term of
      `query` must appear in the name, brand, or description.
  """

  use Ash.Resource.Preparation
  require Ash.Query

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> filter_query(arg(query, :query))
    |> filter_category(arg(query, :category))
    |> filter_brands(downcase_all(arg(query, :brands)))
    |> filter_fits(arg(query, :fits))
    |> filter_activities(downcase_all(arg(query, :activities)))
    |> filter_gender(arg(query, :gender))
    |> filter_price_min(arg(query, :price_min))
    |> filter_price_max(arg(query, :price_max))
    |> filter_variants(downcase_all(arg(query, :sizes)), downcase_all(arg(query, :colors)))
    |> filter_in_stock(arg(query, :in_stock_only))
  end

  defp arg(query, name), do: Ash.Query.get_argument(query, name)

  defp downcase_all(nil), do: []
  defp downcase_all(values), do: Enum.map(values, &(&1 |> String.trim() |> String.downcase()))

  defp filter_query(query, nil), do: query

  defp filter_query(query, text) do
    text
    |> String.downcase()
    |> String.split()
    |> Enum.reduce(query, fn term, query ->
      Ash.Query.filter(
        query,
        contains(string_downcase(name), ^term) or
          contains(string_downcase(brand), ^term) or
          contains(string_downcase(description), ^term)
      )
    end)
  end

  defp filter_category(query, nil), do: query
  defp filter_category(query, ""), do: query
  defp filter_category(query, category), do: Ash.Query.filter(query, category_id == ^category)

  defp filter_brands(query, []), do: query

  defp filter_brands(query, brands),
    do: Ash.Query.filter(query, string_downcase(brand) in ^brands)

  defp filter_fits(query, nil), do: query
  defp filter_fits(query, []), do: query
  defp filter_fits(query, fits), do: Ash.Query.filter(query, fit in ^fits)

  defp filter_activities(query, []), do: query

  defp filter_activities(query, activities),
    do: Ash.Query.filter(query, intersects(activities, ^activities))

  defp filter_gender(query, nil), do: query

  # Unisex products belong to every shopper group of their age group, so
  # "men" also finds unisex adult items and "boys" finds unisex youth items.
  defp filter_gender(query, gender) do
    age_group = Fitzyo.Catalog.Types.Gender.age_group(gender)

    Ash.Query.filter(
      query,
      gender == ^gender or (gender == :unisex and age_group == ^age_group)
    )
  end

  defp filter_price_min(query, nil), do: query
  defp filter_price_min(query, min), do: Ash.Query.filter(query, price >= ^min)

  defp filter_price_max(query, nil), do: query
  defp filter_price_max(query, max), do: Ash.Query.filter(query, price <= ^max)

  defp filter_variants(query, [], []), do: query

  defp filter_variants(query, sizes, []) do
    Ash.Query.filter(
      query,
      exists(variants, string_downcase(size) in ^sizes and inventory_quantity > 0)
    )
  end

  defp filter_variants(query, [], colors) do
    Ash.Query.filter(
      query,
      exists(variants, string_downcase(color) in ^colors and inventory_quantity > 0)
    )
  end

  defp filter_variants(query, sizes, colors) do
    Ash.Query.filter(
      query,
      exists(
        variants,
        string_downcase(size) in ^sizes and string_downcase(color) in ^colors and
          inventory_quantity > 0
      )
    )
  end

  defp filter_in_stock(query, true),
    do: Ash.Query.filter(query, exists(variants, inventory_quantity > 0))

  defp filter_in_stock(query, _), do: query
end
