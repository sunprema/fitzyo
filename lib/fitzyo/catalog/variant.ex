defmodule Fitzyo.Catalog.Variant do
  @moduledoc """
  A purchasable configuration of a product: one size in one color.

  Inventory lives here. Product-level availability is derived from variants,
  so an agent must never assume a product being available means a specific
  size/color is.

  The primary key is the stable variant id (`prod_1024_blue_xl`).
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Catalog,
    data_layer: AshPostgres.DataLayer

  alias Fitzyo.Catalog.Types

  postgres do
    table "variants"
    repo Fitzyo.Repo

    references do
      reference :product, on_delete: :delete
    end

    custom_indexes do
      index [:product_id, :position]
      index [:size]
      index [:color]
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :id,
        :product_id,
        :size,
        :color,
        :color_hex,
        :sku,
        :price,
        :inventory_quantity,
        :position
      ]

      upsert? true
    end

    read :for_product do
      argument :product_id, :string, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
      prepare build(sort: [position: :asc])
    end

    read :distinct_colors do
      description "Every color sold in the catalog, once, with its swatch hex."
      prepare build(select: [:color, :color_hex], distinct: [:color], sort: [color: :asc])
    end

    read :sizes_in_category do
      description "Every size stocked in a category, once. Unsorted; use Fitzyo.Catalog.Sizes.sort/1."
      argument :category, :string, allow_nil?: false
      filter expr(product.category_id == ^arg(:category))
      prepare build(select: [:size], distinct: [:size], sort: [size: :asc])
    end

    read :matching do
      description """
      Find in-stock variants satisfying a set of shopping constraints.
      Every supplied constraint must hold (AND); list constraints match any
      of their values (OR). Matching is case-insensitive. `size` and `sizes`
      combine into one OR list; exclusions are AND-NOT.
      """

      argument :product_id, :string
      argument :category, :string
      argument :size, :string
      argument :sizes, {:array, :string}, default: []
      argument :colors, {:array, :string}, default: []
      argument :exclude_colors, {:array, :string}, default: []
      argument :brands, {:array, :string}, default: []
      argument :exclude_brands, {:array, :string}, default: []
      argument :fit, Types.Fit
      argument :activities, {:array, :string}, default: []
      argument :gender, Types.Gender
      argument :price_max, :decimal
      argument :in_stock_only, :boolean, default: true

      prepare Fitzyo.Catalog.Variant.Preparations.ApplyMatchConstraints
      prepare build(sort: [product_id: :asc, position: :asc])
    end
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_-]+$/
    end

    attribute :size, :string, allow_nil?: false, public?: true
    attribute :color, :string, allow_nil?: false, public?: true
    attribute :color_hex, :string, public?: true
    attribute :sku, :string, public?: true

    attribute :price, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :inventory_quantity, :integer do
      allow_nil? false
      default 0
      public? true
      constraints min: 0
    end

    attribute :position, :integer, default: 0, allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :product, Fitzyo.Catalog.Product do
      attribute_type :string
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :available, :boolean, expr(inventory_quantity > 0), public?: true

    calculate :inventory_status,
              :string,
              expr(
                cond do
                  inventory_quantity <= 0 -> "out_of_stock"
                  inventory_quantity <= 3 -> "low_stock"
                  true -> "in_stock"
                end
              ),
              public?: true
  end
end
