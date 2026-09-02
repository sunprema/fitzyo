defmodule FitzyoWeb.StoreComponents do
  @moduledoc """
  Function components for the FitzYo storefront.

  Every commerce object rendered here carries a stable DOM id and `data-*`
  attributes (`product-prod_1001`, `variant-prod_1001_blue_xl`,
  `filter-color-blue`, `cart-item-<id>`) so that the same markup a human
  reads is also legible to an agent (RETAIL_UX_REQUIREMENTS §10, §36).
  """

  use Phoenix.Component

  alias Fitzyo.Catalog.Sizes

  # ---------------------------------------------------------------- helpers

  @doc "Formats a Decimal as US dollars, always with cents."
  def format_price(%Decimal{} = amount),
    do: "$" <> Decimal.to_string(Decimal.round(amount, 2), :normal)

  def format_price(nil), do: ""

  @doc "A DOM-safe slug: `16.5/34` becomes `16_5_34`."
  def dom_slug(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  @doc "Capitalizes a lowercase catalog token such as a color or activity."
  def humanize(nil), do: ""
  def humanize(value), do: value |> to_string() |> String.capitalize()

  @doc "The distinct colors of a product's variants, in catalog order, with swatch hex."
  def color_options(%{variants: variants}) when is_list(variants) do
    variants
    |> Enum.sort_by(& &1.position)
    |> Enum.uniq_by(& &1.color)
    |> Enum.map(fn v ->
      %{
        name: v.color,
        hex: v.color_hex || "#9caf88",
        available: Enum.any?(variants, &(&1.color == v.color and &1.inventory_quantity > 0))
      }
    end)
  end

  def color_options(_), do: []

  @doc "The variants of a product in one color, in size order."
  def variants_in_color(%{variants: variants}, color) when is_list(variants) do
    variants
    |> Enum.filter(&(&1.color == color))
    |> Enum.sort_by(&{&1.position, Sizes.sort_key(&1.size)})
  end

  def variants_in_color(_, _), do: []

  @doc "Picks a readable text class for content drawn over a color."
  def contrast_class(hex) when is_binary(hex) do
    with "#" <> digits <- hex,
         6 <- String.length(digits),
         {r, ""} <- Integer.parse(String.slice(digits, 0, 2), 16),
         {g, ""} <- Integer.parse(String.slice(digits, 2, 2), 16),
         {b, ""} <- Integer.parse(String.slice(digits, 4, 2), 16) do
      luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
      if luminance > 170, do: "text-[#1e2b24]/70", else: "text-white/85"
    else
      _ -> "text-white/85"
    end
  end

  def contrast_class(_), do: "text-white/85"

  defp initials(name) do
    name
    |> String.split(~r/[\s-]+/, trim: true)
    |> Enum.reject(&String.match?(&1, ~r/^[^A-Za-z]/))
    |> Enum.take(2)
    |> Enum.map_join(&String.first/1)
    |> String.upcase()
  end

  # ---------------------------------------------------------------- product art

  @doc """
  A painted stand-in for product photography, colored with a variant's hex.
  """
  attr :name, :string, required: true
  attr :hex, :string, default: nil
  attr :caption, :string, default: nil
  attr :class, :any, default: nil
  slot :inner_block

  def product_art(assigns) do
    assigns = assign(assigns, :hex, assigns.hex || "#9caf88")

    ~H"""
    <div
      class={["fz-art relative flex items-center justify-center overflow-hidden", @class]}
      style={"--fz-art: #{@hex}"}
      aria-hidden="true"
    >
      <span class={[
        "font-display text-4xl font-semibold tracking-wide select-none",
        contrast_class(@hex)
      ]}>
        {initials(@name)}
      </span>
      <span
        :if={@caption}
        class={[
          "absolute bottom-2 right-2.5 text-[10px] font-semibold uppercase tracking-wider",
          contrast_class(@hex)
        ]}
      >
        {@caption}
      </span>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ---------------------------------------------------------------- product card

  @doc """
  A product card for the results grid. `product` must have `variants` and
  `available` loaded.
  """
  attr :id, :string, required: true
  attr :product, :map, required: true
  attr :href, :string, required: true
  attr :annotations, :list, default: [], doc: "agent annotations for this product (see State)"

  def product_card(assigns) do
    colors = color_options(assigns.product)
    labels = assigns.annotations |> Enum.map(& &1.label) |> Enum.uniq()
    assigns = assign(assigns, colors: colors, hero: List.first(colors), labels: labels)

    ~H"""
    <article
      id={@id}
      class="fz-fade group flex flex-col overflow-hidden rounded-2xl border border-base-300 bg-base-100 transition hover:-translate-y-0.5 hover:shadow-md"
      data-product-id={@product.id}
      data-product-name={@product.name}
      data-brand={@product.brand}
      data-category={@product.category_id}
      data-price={Decimal.to_string(@product.price, :normal)}
      data-available={to_string(@product.available)}
      data-fits={if @labels != [], do: Enum.join(@labels, ",")}
    >
      <.link patch={@href} class="block" aria-label={"View #{@product.name}"}>
        <.product_art
          name={@product.name}
          hex={@hero && @hero.hex}
          caption={@product.category_id}
          class="aspect-square w-full"
        >
          <span
            :if={!@product.available}
            class="absolute left-2 top-2 rounded-full bg-base-100/90 px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide text-muted"
          >
            Sold out
          </span>
          <span
            :if={@labels != []}
            class="fz-fade absolute left-2 top-2 rounded-full bg-accent px-2 py-0.5 text-[10px] font-bold text-accent-content shadow-sm"
            title="Matched by your agent"
          >
            ✦ Fits {Enum.join(@labels, " · ")}
          </span>
        </.product_art>
      </.link>
      <div class="flex flex-1 flex-col gap-1 p-3.5">
        <span class="text-[11px] font-bold uppercase tracking-wide text-primary">{@product.brand}</span>
        <.link patch={@href} class="text-sm font-semibold leading-snug hover:underline">
          {@product.name}
        </.link>
        <div class="mt-1.5 flex items-center justify-between">
          <span class="text-sm font-bold">{format_price(@product.price)}</span>
          <div class="flex gap-1" aria-label="Available colors">
            <span
              :for={color <- Enum.take(@colors, 4)}
              class="size-3.5 rounded-full border border-base-300"
              style={"background: #{color.hex}"}
              title={humanize(color.name)}
            />
          </div>
        </div>
      </div>
    </article>
    """
  end

  # ---------------------------------------------------------------- filter widgets

  attr :title, :string, required: true
  slot :inner_block, required: true

  def facet(assigns) do
    ~H"""
    <section class="mb-5">
      <h3 class="mb-2.5 text-[11px] font-bold uppercase tracking-wider text-muted">{@title}</h3>
      {render_slot(@inner_block)}
    </section>
    """
  end

  @doc "A toggle pill used for sizes, fits, and activities."
  attr :id, :string, required: true
  attr :facet, :string, required: true
  attr :value, :string, required: true
  attr :selected, :boolean, default: false
  attr :shape, :string, default: "pill", values: ~w(pill square)
  slot :inner_block, required: true

  def facet_pill(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click="toggle_filter"
      phx-value-facet={@facet}
      phx-value-value={@value}
      data-filter-type={@facet}
      data-filter-value={@value}
      aria-pressed={to_string(@selected)}
      class={[
        "border px-2.5 py-1.5 text-xs font-semibold capitalize transition cursor-pointer",
        if(@shape == "pill", do: "rounded-full", else: "rounded-lg"),
        if(@selected,
          do: "border-primary bg-primary text-primary-content",
          else: "border-base-300 bg-base-100 text-base-content hover:border-primary/60"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :id, :string, required: true
  attr :facet, :string, default: "color"
  attr :name, :string, required: true
  attr :hex, :string, required: true
  attr :selected, :boolean, default: false
  attr :size, :string, default: "size-7"
  attr :event, :string, default: "toggle_filter"
  attr :rest, :global

  def color_swatch(assigns) do
    ~H"""
    <button
      type="button"
      id={@id}
      phx-click={@event}
      phx-value-facet={@facet}
      phx-value-value={@name}
      data-filter-type={@facet}
      data-filter-value={@name}
      aria-label={humanize(@name)}
      aria-pressed={to_string(@selected)}
      title={humanize(@name)}
      style={"background: #{@hex}"}
      class={[
        "rounded-full cursor-pointer transition",
        @size,
        if(@selected,
          do: "ring-2 ring-primary ring-offset-2 ring-offset-base-100 border border-primary",
          else: "border border-base-300 hover:ring-2 hover:ring-primary/40 hover:ring-offset-1"
        )
      ]}
      {@rest}
    />
    """
  end

  @doc "An active-filter chip with a remove control."
  attr :facet, :string, required: true
  attr :value, :string, default: nil
  attr :label, :string, required: true

  def active_chip(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="remove_filter"
      phx-value-facet={@facet}
      phx-value-value={@value}
      class="flex items-center gap-1.5 rounded-full border border-peach-dark bg-peach px-2.5 py-1 text-xs font-semibold text-error cursor-pointer hover:bg-peach-dark/60"
      aria-label={"Remove filter #{@label}"}
    >
      {@label} <span aria-hidden="true">×</span>
    </button>
    """
  end

  # ---------------------------------------------------------------- misc

  @doc "The pulsing status dot used for agent connection state."
  attr :class, :any, default: nil

  def status_dot(assigns) do
    ~H"""
    <span class={["fz-pulse inline-block size-2 rounded-full bg-primary", @class]} />
    """
  end
end
