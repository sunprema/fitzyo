defmodule FitzyoWeb.StoreLive.State do
  @moduledoc """
  The one canonical application state (AGENTS.md §14) and the operations
  that change it:

      filters · results · selected product · selected variant · comparison · cart

  Both the human UI (`FitzyoWeb.StoreLive` events) and the agent
  (`FitzyoWeb.StoreLive.AgentTools`) go through these functions, so there is
  never a separate "agent state". Everything here takes and returns the
  socket; nothing renders.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]
  import Phoenix.LiveView

  require Ash.Query

  alias Fitzyo.Catalog
  alias Fitzyo.Catalog.Facets
  alias Fitzyo.Commerce
  alias FitzyoWeb.StoreComponents
  alias FitzyoWeb.StoreLive.Filters

  use Phoenix.VerifiedRoutes,
    endpoint: FitzyoWeb.Endpoint,
    router: FitzyoWeb.Router,
    statics: FitzyoWeb.static_paths()

  @variant_query Ash.Query.sort(Catalog.Variant, position: :asc)
  @product_load [:category, :available, :size_guide_entries, variants: @variant_query]
  @results_load [:available, variants: @variant_query]
  @cart_load [:item_count, :subtotal, items: [:line_total, variant: [:available, :product]]]
  @activity_limit 40

  @type activity_entry :: %{call: String.t(), result: String.t(), status: :ok | :error}

  # ---------------------------------------------------------------- setup

  @doc "Assigns the initial state for a session's cart."
  def initial(socket, cart_id) do
    Commerce.ensure_cart!(cart_id)

    socket
    |> assign(
      cart_id: cart_id,
      facets: Facets.all(),
      filters: %Filters{},
      sizes: [],
      results_count: 0,
      product: nil,
      selected_color: nil,
      selected_size: nil,
      comparison: [],
      activity: [],
      agent_connected: false
    )
    |> stream_configure(:products, dom_id: &"product-#{&1.id}")
    |> stream(:products, [])
    |> load_cart()
  end

  # ---------------------------------------------------------------- filters & results

  @doc "Stores the filters and the category-dependent size facet."
  def put_filters(socket, %Filters{} = filters) do
    assign(socket, filters: filters, sizes: Facets.sizes_for_category(filters.category))
  end

  @doc "Runs the catalog query for `filters`."
  def fetch_results(%Filters{} = filters) do
    filters
    |> Filters.to_browse_args()
    |> Catalog.filter_products!(load: @results_load)
  end

  @doc "Refreshes the results stream from the current filters."
  def load_results(socket) do
    products = fetch_results(socket.assigns.filters)

    socket
    |> assign(results_count: length(products))
    |> stream(:products, products, reset: true)
  end

  @doc "Navigates to the results page with `filters` applied; `handle_params` reloads."
  def patch_filters(socket, %Filters{} = filters) do
    push_patch(socket, to: index_path(filters))
  end

  def index_path(%Filters{} = filters), do: ~p"/?#{Filters.to_params(filters)}"

  def product_path(id, %Filters{} = filters),
    do: ~p"/products/#{id}?#{Filters.to_params(filters)}"

  def results_heading(facets, %Filters{} = filters) do
    cond do
      filters.category -> category_name(facets, filters.category)
      filters.query -> ~s(Results for "#{filters.query}")
      true -> "All Products"
    end
  end

  def category_name(facets, id) do
    case Enum.find(facets.categories, &(&1.id == id)) do
      nil -> id
      category -> category.name
    end
  end

  # ---------------------------------------------------------------- product & variant

  @doc "Loads a product with everything the detail page and tools need."
  def fetch_product(id), do: Catalog.get_product(id, load: @product_load)

  @doc """
  Makes `id` the selected product. Keeps the current color/size selection when
  the product offers it. Returns `{:error, socket}` (with a flash and a patch
  back to results) when the product does not exist.
  """
  def load_product(socket, id) do
    case fetch_product(id) do
      {:ok, product} ->
        {:ok,
         socket
         |> assign(product: product, page_title: product.name)
         |> select_variant(socket.assigns.selected_color, socket.assigns.selected_size)}

      {:error, _} ->
        {:error,
         socket
         |> put_flash(:error, "We couldn't find that product.")
         |> push_patch(to: index_path(socket.assigns.filters))}
    end
  end

  @doc """
  Sets the selected color and size for the current product, falling back to
  the first color with stock and the first in-stock size of that color.
  A chosen size that exists but is sold out is kept, so the UI can say so.
  """
  def select_variant(%{assigns: %{product: nil}} = socket, _color, _size), do: socket

  def select_variant(socket, color, size) do
    product = socket.assigns.product
    colors = StoreComponents.color_options(product)

    color =
      cond do
        Enum.any?(colors, &(&1.name == color)) -> color
        first = Enum.find(colors, & &1.available) -> first.name
        first = List.first(colors) -> first.name
        true -> nil
      end

    variants = StoreComponents.variants_in_color(product, color)

    size =
      cond do
        Enum.any?(variants, &(&1.size == size)) -> size
        first = Enum.find(variants, &(&1.inventory_quantity > 0)) -> first.size
        true -> nil
      end

    assign(socket, selected_color: color, selected_size: size)
  end

  @doc "The variant matching the current color/size selection, if any."
  def selected_variant(%{assigns: %{product: nil}}), do: nil

  def selected_variant(%{assigns: assigns}) do
    Enum.find(
      assigns.product.variants,
      &(&1.color == assigns.selected_color and &1.size == assigns.selected_size)
    )
  end

  # ---------------------------------------------------------------- comparison

  @doc "Replaces the comparison set with the given products (max 4, in order)."
  def compare(socket, products) when is_list(products) do
    assign(socket, comparison: Enum.take(products, 4))
  end

  def add_to_comparison(socket, product) do
    comparison = Enum.reject(socket.assigns.comparison, &(&1.id == product.id))
    compare(socket, comparison ++ [product])
  end

  def remove_from_comparison(socket, product_id) do
    assign(socket, comparison: Enum.reject(socket.assigns.comparison, &(&1.id == product_id)))
  end

  def clear_comparison(socket), do: assign(socket, comparison: [])

  # ---------------------------------------------------------------- cart

  @doc "Reloads the session cart with totals and item details."
  def load_cart(socket) do
    assign(socket, cart: Commerce.get_cart!(socket.assigns.cart_id, load: @cart_load))
  end

  # ---------------------------------------------------------------- agent activity & focus

  @doc "Appends a high-level entry to the agent activity log (newest first)."
  def log_activity(socket, call, result, status \\ :ok) do
    entry = %{call: call, result: result, status: status, at: DateTime.utc_now()}

    socket
    |> assign(agent_connected: true)
    |> update(:activity, &Enum.take([entry | &1], @activity_limit))
  end

  @doc "Asks the browser to scroll a DOM element into view and highlight it briefly."
  def focus_element(socket, dom_id) when is_binary(dom_id) do
    push_event(socket, "fz:focus", %{id: dom_id})
  end
end
