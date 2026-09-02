defmodule Fitzyo.Catalog.Facets do
  @moduledoc """
  The filter vocabulary of the store: which categories, sizes, colors, brands,
  fits, and activities a shopper (or agent) can filter on.

  Everything here is derived from the catalog so the sidebar and the WebMCP
  filter schema never drift from what is actually sold.
  """

  alias Fitzyo.Catalog
  alias Fitzyo.Catalog.Sizes
  alias Fitzyo.Catalog.Types

  @type t :: %{
          categories: [Catalog.Category.t()],
          brands: [String.t()],
          colors: [%{name: String.t(), hex: String.t() | nil}],
          fits: [String.t()],
          activities: [String.t()]
        }

  @activity_order ~w(travel beach swim hiking casual dinner outdoor running)

  @doc "Loads every facet except sizes, which depend on the chosen category."
  @spec all() :: t()
  def all do
    %{
      categories: Catalog.list_categories!(load: [:product_count]),
      brands: Catalog.list_brands!() |> Enum.map(& &1.brand),
      colors: Catalog.list_colors!() |> Enum.map(&%{name: &1.color, hex: &1.color_hex}),
      fits: Enum.map(Types.Fit.values(), &Atom.to_string/1),
      activities: activities()
    }
  end

  @doc "Sizes stocked in a category, in display order. Empty when no category is chosen."
  @spec sizes_for_category(String.t() | nil) :: [String.t()]
  def sizes_for_category(nil), do: []
  def sizes_for_category(""), do: []

  def sizes_for_category(category) do
    category
    |> Catalog.list_sizes_in_category!()
    |> Enum.map(& &1.size)
    |> Sizes.sort()
  end

  defp activities do
    known = Enum.with_index(@activity_order) |> Map.new()

    Catalog.list_products!(query: [select: [:activities]])
    |> Enum.flat_map(& &1.activities)
    |> Enum.uniq()
    |> Enum.sort_by(&{Map.get(known, &1, 99), &1})
  end
end
