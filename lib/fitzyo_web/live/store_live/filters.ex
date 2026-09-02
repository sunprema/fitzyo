defmodule FitzyoWeb.StoreLive.Filters do
  @moduledoc """
  The store's search-and-filter state, round-tripped through the URL query
  string so that a human, an agent, and the browser history all see one
  canonical state (AGENTS.md §14).

  Query parameters: `q`, `category`, `gender`, `size[]`, `color[]`, `brand[]`,
  `fit[]`, `activity[]`, `min`, `max`.
  """

  alias Fitzyo.Catalog.Types

  @type t :: %__MODULE__{}

  defstruct query: nil,
            category: nil,
            gender: nil,
            sizes: [],
            colors: [],
            brands: [],
            fits: [],
            activities: [],
            price_min: nil,
            price_max: nil

  @list_facets %{
    "size" => :sizes,
    "color" => :colors,
    "brand" => :brands,
    "fit" => :fits,
    "activity" => :activities
  }

  @valid_fits Enum.map(Types.Fit.values(), &Atom.to_string/1)
  @valid_genders Enum.map(Types.Gender.values(), &Atom.to_string/1)

  @doc "The shopper groups a catalog can be narrowed to."
  def genders, do: @valid_genders

  @doc "Builds filters from LiveView params. Unknown or malformed values are dropped, never raised."
  @spec from_params(map()) :: t()
  def from_params(params) when is_map(params) do
    %__MODULE__{
      query: blank_to_nil(params["q"]),
      category: blank_to_nil(params["category"]),
      gender: gender(params["gender"]),
      sizes: list(params["size"]),
      colors: list(params["color"]),
      brands: list(params["brand"]),
      fits: params["fit"] |> list() |> Enum.filter(&(&1 in @valid_fits)),
      activities: list(params["activity"]),
      price_min: decimal(params["min"]),
      price_max: decimal(params["max"])
    }
  end

  @doc "Encodes filters as query params for `push_patch`. Empty values are omitted."
  @spec to_params(t()) :: map()
  def to_params(%__MODULE__{} = filters) do
    %{
      "q" => filters.query,
      "category" => filters.category,
      "gender" => filters.gender,
      "size" => filters.sizes,
      "color" => filters.colors,
      "brand" => filters.brands,
      "fit" => filters.fits,
      "activity" => filters.activities,
      "min" => filters.price_min && Decimal.to_string(filters.price_min, :normal),
      "max" => filters.price_max && Decimal.to_string(filters.price_max, :normal)
    }
    |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
    |> Map.new()
  end

  @doc "Arguments for `Fitzyo.Catalog.filter_products/2`."
  @spec to_browse_args(t()) :: map()
  def to_browse_args(%__MODULE__{} = filters) do
    %{
      query: filters.query,
      category: filters.category,
      gender: filters.gender,
      sizes: filters.sizes,
      colors: filters.colors,
      brands: filters.brands,
      fits: filters.fits,
      activities: filters.activities,
      price_min: filters.price_min,
      price_max: filters.price_max
    }
  end

  @doc "Toggles a value in a list facet (`\"size\"`, `\"color\"`, `\"brand\"`, `\"fit\"`, `\"activity\"`)."
  @spec toggle(t(), String.t(), String.t()) :: t()
  def toggle(%__MODULE__{} = filters, facet, value) when is_map_key(@list_facets, facet) do
    key = Map.fetch!(@list_facets, facet)
    current = Map.fetch!(filters, key)

    next =
      if value in current, do: List.delete(current, value), else: current ++ [value]

    Map.put(filters, key, next)
  end

  @doc "Selects a category, or clears it when it is already selected. Sizes are category-specific, so they reset."
  @spec toggle_category(t(), String.t()) :: t()
  def toggle_category(%__MODULE__{category: current} = filters, category) do
    next = if current == category, do: nil, else: category
    %{filters | category: next, sizes: []}
  end

  @doc "Selects a shopper group, or clears it when already selected."
  @spec toggle_gender(t(), String.t()) :: t()
  def toggle_gender(%__MODULE__{gender: current} = filters, gender) do
    %{filters | gender: if(current == gender, do: nil, else: gender(gender))}
  end

  @spec put_query(t(), String.t() | nil) :: t()
  def put_query(%__MODULE__{} = filters, query), do: %{filters | query: blank_to_nil(query)}

  @spec put_price(t(), String.t() | nil, String.t() | nil) :: t()
  def put_price(%__MODULE__{} = filters, min, max) do
    %{filters | price_min: decimal(min), price_max: decimal(max)}
  end

  @doc "Removes one active constraint, as used by the 'Active:' chips."
  @spec remove(t(), String.t(), String.t() | nil) :: t()
  def remove(filters, "category", _), do: %{filters | category: nil, sizes: []}
  def remove(filters, "q", _), do: %{filters | query: nil}
  def remove(filters, "gender", _), do: %{filters | gender: nil}
  def remove(filters, "min", _), do: %{filters | price_min: nil}
  def remove(filters, "max", _), do: %{filters | price_max: nil}

  def remove(filters, facet, value) when is_map_key(@list_facets, facet),
    do: toggle(filters, facet, value)

  @spec clear(t()) :: t()
  def clear(%__MODULE__{}), do: %__MODULE__{}

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{} = filters), do: filters != %__MODULE__{}

  @doc """
  The active constraints as `%{facet, value, label}` chips, in display order.
  Category chips carry the raw id; callers may relabel with the category name.
  """
  @spec chips(t()) :: [%{facet: String.t(), value: String.t() | nil, label: String.t()}]
  def chips(%__MODULE__{} = f) do
    [
      f.query && %{facet: "q", value: nil, label: ~s("#{f.query}")},
      f.category && %{facet: "category", value: f.category, label: f.category},
      f.gender && %{facet: "gender", value: f.gender, label: gender_label(f.gender)},
      Enum.map(f.sizes, &%{facet: "size", value: &1, label: &1}),
      Enum.map(f.colors, &%{facet: "color", value: &1, label: String.capitalize(&1)}),
      Enum.map(f.brands, &%{facet: "brand", value: &1, label: &1}),
      Enum.map(f.fits, &%{facet: "fit", value: &1, label: String.capitalize(&1)}),
      Enum.map(f.activities, &%{facet: "activity", value: &1, label: String.capitalize(&1)}),
      f.price_min &&
        %{facet: "min", value: nil, label: "Over $#{Decimal.to_string(f.price_min, :normal)}"},
      f.price_max &&
        %{facet: "max", value: nil, label: "Under $#{Decimal.to_string(f.price_max, :normal)}"}
    ]
    |> List.flatten()
    |> Enum.reject(&(&1 in [nil, false]))
  end

  @doc "Display label for a shopper group."
  def gender_label("men"), do: "Men"
  def gender_label("women"), do: "Women"
  def gender_label("boys"), do: "Boys"
  def gender_label("girls"), do: "Girls"
  def gender_label("unisex"), do: "Unisex"
  def gender_label(other), do: to_string(other)

  defp gender(value) when is_binary(value) do
    value = value |> String.trim() |> String.downcase()
    if value in @valid_genders, do: value, else: nil
  end

  defp gender(_), do: nil

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp list(nil), do: []
  defp list(value) when is_binary(value), do: list([value])

  defp list(values) when is_list(values) do
    values
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp list(_), do: []

  defp decimal(nil), do: nil

  defp decimal(value) when is_binary(value) do
    case Decimal.parse(String.trim(value)) do
      {decimal, ""} -> if Decimal.negative?(decimal), do: nil, else: decimal
      _ -> nil
    end
  end

  defp decimal(_), do: nil
end
