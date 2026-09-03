defmodule FitzyoWeb.StoreLive.Presenter do
  @moduledoc """
  Normalized JSON shapes for WebMCP tool results (WEBMCP_SPEC §9, §10, §22).

  Every map here is what an agent receives, so keys are stable strings-as-atoms
  (encoded by Jason), prices are numbers with a currency, and enum atoms are
  rendered as strings. Nothing personal about the shopper ever appears.
  """

  alias FitzyoWeb.StoreComponents

  @doc "The short product record used in search, filter, and comparison results."
  def product_summary(product) do
    colors = StoreComponents.color_options(product)

    %{
      product_id: product.id,
      name: product.name,
      brand: product.brand,
      category: product.category_id,
      image_url: product.image_url,
      price: price(product.price, product.currency),
      fit: to_string(product.fit),
      gender: to_string(product.gender),
      age_group: to_string(product.age_group),
      activities: product.activities,
      available: product.available,
      colors: Enum.map(colors, & &1.name),
      available_colors: colors |> Enum.filter(& &1.available) |> Enum.map(& &1.name),
      sizes: sizes(product.variants, false),
      available_sizes: sizes(product.variants, true)
    }
  end

  @doc "The full product record for `get_product`."
  def product(product) do
    product
    |> product_summary()
    |> Map.merge(%{
      description: product.description,
      material: product.material,
      fit: %{
        profile: to_string(product.fit),
        stretch: to_string(product.stretch),
        length: product.fit_length,
        cut: product.cut,
        weight: product.weight
      },
      size_system: product.size_system,
      measurement_unit: product.measurement_unit,
      variant_count: length(product.variants),
      has_size_guide: product.size_guide_entries != []
    })
  end

  @doc "A purchasable variant. `variant.product` may be loaded for name/brand."
  def variant(variant) do
    base = %{
      variant_id: variant.id,
      product_id: variant.product_id,
      size: variant.size,
      color: variant.color,
      sku: variant.sku,
      price: price(variant.price, "USD"),
      available: variant.inventory_quantity > 0,
      inventory_status: inventory_status(variant.inventory_quantity)
    }

    case variant do
      %{product: %{name: name, brand: brand}} -> Map.merge(base, %{name: name, brand: brand})
      _ -> base
    end
  end

  @doc "A structured size guide for `get_size_guide`."
  def size_guide(product, entries) do
    %{
      product_id: product.id,
      size_system: product.size_system,
      unit: product.measurement_unit,
      measurements:
        Enum.map(entries, fn entry ->
          entry
          |> Map.take([
            :size,
            :chest_min,
            :chest_max,
            :waist_min,
            :waist_max,
            :hip_min,
            :hip_max,
            :neck,
            :sleeve,
            :inseam
          ])
          |> Enum.reject(fn {_key, value} -> is_nil(value) end)
          |> Map.new(fn {key, value} -> {key, number(value)} end)
        end)
    }
  end

  @doc "The cart for `get_cart`; items need `variant.product` and `line_total` loaded. With members, adds per-label subtotals against budgets."
  def cart(cart, members \\ []) do
    %{
      by_label: by_label(cart.items, members),
      cart_id: cart.id,
      items:
        Enum.map(cart.items, fn item ->
          %{
            cart_item_id: item.id,
            product_id: item.variant.product_id,
            variant_id: item.variant_id,
            name: item.variant.product.name,
            brand: item.variant.product.brand,
            size: item.variant.size,
            color: item.variant.color,
            quantity: item.quantity,
            unit_price: number(item.unit_price),
            line_total: number(item.line_total),
            label: item.label,
            source: to_string(item.source),
            available: item.variant.available
          }
        end),
      item_count: cart.item_count,
      subtotal: number(cart.subtotal),
      currency: "USD"
    }
  end

  @doc """
  Per-label subtotal, budget (from a registered member), and overage. With
  no registered budget both `budget` and `over_by` are nil: "not measured",
  never a confident zero.
  """
  def by_label(items, members) do
    items
    |> Enum.reject(&is_nil(&1.label))
    |> Enum.group_by(& &1.label)
    |> Map.new(fn {label, lines} ->
      subtotal = Enum.reduce(lines, Decimal.new(0), &Decimal.add(&2, &1.line_total))
      budget = FitzyoWeb.StoreLive.Members.budget(members, label)

      over =
        cond do
          is_nil(budget) -> nil
          Decimal.compare(subtotal, budget) == :gt -> Decimal.sub(subtotal, budget)
          true -> Decimal.new(0)
        end

      {label,
       %{
         subtotal: number(subtotal),
         budget: budget && number(budget),
         over_by: over && number(over)
       }}
    end)
  end

  @doc "The compact cart totals returned by write operations."
  def cart_totals(cart) do
    %{item_count: cart.item_count, subtotal: number(cart.subtotal), currency: "USD"}
  end

  @doc "An agent annotation as the agent sees it back in `get_store_state`."
  def annotation(a) do
    %{
      label: a.label,
      product_id: a.product_id,
      variant_id: a.variant_id,
      source: to_string(a.source),
      match: a.match,
      match_score: a.score,
      reason: a.reason
    }
  end

  @doc "The human's current view, for agents to observe overrides (§14, §31)."
  def state(assigns, variant) do
    %{
      view: if(assigns.product, do: "product", else: "results"),
      search_query: assigns.filters.query,
      filters: FitzyoWeb.StoreLive.Filters.to_params(assigns.filters),
      filter_origins: FitzyoWeb.StoreLive.State.filter_origin_summary(assigns.filter_origins),
      excluded_by: assigns.excluded_by,
      removed_by_human:
        Enum.map(assigns.removed_by_human, fn {facet, value} -> %{facet: facet, value: value} end),
      results_count: assigns.results_count,
      selected_product_id: assigns.product && assigns.product.id,
      selected_color: assigns.selected_color,
      selected_size: assigns.selected_size,
      selected_variant_id: variant && variant.id,
      comparison_product_ids: Enum.map(assigns.comparison, & &1.id),
      annotations:
        assigns.annotations |> Map.values() |> List.flatten() |> Enum.map(&annotation/1),
      plan: assigns.plan,
      lookbook: FitzyoWeb.StoreLive.Lookbook.summary(assigns.lookbook, assigns.cart),
      pending_question: FitzyoWeb.StoreLive.Questions.pending(assigns.question),
      pending_proposal: FitzyoWeb.StoreLive.Proposals.pending(assigns.proposal, assigns.cart),
      members: Enum.map(assigns.members, &FitzyoWeb.StoreLive.Members.summary/1),
      capabilities: FitzyoWeb.StoreLive.Capabilities.summary(assigns.capabilities),
      pending_capability_request:
        FitzyoWeb.StoreLive.Capabilities.pending(assigns.capability_request),
      cart: cart_totals(assigns.cart),
      cart_open: assigns.cart_open,
      agent: %{
        status: to_string(assigns.agent.status),
        message: assigns.agent.message,
        progress: assigns.agent.progress,
        set_with: "agent_update"
      }
    }
  end

  def price(%Decimal{} = amount, currency), do: %{amount: number(amount), currency: currency}

  def number(%Decimal{} = value), do: value |> Decimal.round(2) |> Decimal.to_float()
  def number(value), do: value

  defp sizes(variants, only_available?) do
    variants
    |> Enum.filter(&(not only_available? or &1.inventory_quantity > 0))
    |> Enum.map(& &1.size)
    |> Enum.uniq()
    |> Fitzyo.Catalog.Sizes.sort()
  end

  defp inventory_status(quantity) when quantity <= 0, do: "out_of_stock"
  defp inventory_status(quantity) when quantity <= 3, do: "low_stock"
  defp inventory_status(_), do: "in_stock"
end
