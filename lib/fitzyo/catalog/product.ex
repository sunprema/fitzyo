defmodule Fitzyo.Catalog.Product do
  @moduledoc """
  A sellable style, e.g. "Bahama II Short Sleeve Shirt".

  Products carry the normalized semantic attributes an agent reasons over
  (brand, category, fit, activities, price). Purchasable size/color
  combinations live on `Fitzyo.Catalog.Variant`; availability is always
  derived from variants, never asserted at the product level.

  The primary key is the stable product id (`prod_1024`).
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Catalog,
    data_layer: AshPostgres.DataLayer

  alias Fitzyo.Catalog.Types

  postgres do
    table "products"
    repo Fitzyo.Repo

    references do
      reference :category, on_delete: :restrict
    end

    custom_indexes do
      index [:brand]
      index [:fit]
      index [:price]
      index [:activities], using: "GIN"
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :id,
        :name,
        :brand,
        :description,
        :category_id,
        :price,
        :currency,
        :gender,
        :age_group,
        :material,
        :fit,
        :stretch,
        :fit_length,
        :cut,
        :weight,
        :activities,
        :image_url,
        :size_system,
        :measurement_unit
      ]

      upsert? true
    end

    read :browse do
      description """
      Search and filter the catalog in one deterministic query.
      Filters use AND semantics across facets and OR semantics within a facet.
      Size and color filters must be satisfied by the same in-stock variant.
      Exclusions (`exclude_colors`, `exclude_brands`) are AND-NOT: a product
      only counts when an in-stock variant in a non-excluded color satisfies
      the size and color filters, and its brand is not excluded.
      """

      argument :query, :string
      argument :category, :string
      argument :sizes, {:array, :string}, default: []
      argument :colors, {:array, :string}, default: []
      argument :brands, {:array, :string}, default: []
      argument :exclude_colors, {:array, :string}, default: []
      argument :exclude_brands, {:array, :string}, default: []
      argument :fits, {:array, Types.Fit}, default: []
      argument :activities, {:array, :string}, default: []
      argument :gender, Types.Gender
      argument :price_min, :decimal
      argument :price_max, :decimal
      argument :in_stock_only, :boolean, default: true

      prepare Fitzyo.Catalog.Product.Preparations.ApplyBrowseFilters
      prepare build(sort: [brand: :asc, name: :asc])
    end

    read :distinct_brands do
      description "Every brand in the catalog, once, alphabetically."
      prepare build(select: [:brand], distinct: [:brand], sort: [brand: :asc])
    end
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9_-]+$/
    end

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :brand, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true

    attribute :price, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    attribute :currency, :string, default: "USD", allow_nil?: false, public?: true

    attribute :gender, Types.Gender, default: :unisex, allow_nil?: false, public?: true
    attribute :age_group, Types.AgeGroup, default: :adult, allow_nil?: false, public?: true
    attribute :material, :string, public?: true

    # Structured fit information (see AGENTS.md §7). Kept flat so every field
    # is directly filterable and serializes to plain JSON for agents.
    attribute :fit, Types.Fit, default: :regular, allow_nil?: false, public?: true
    attribute :stretch, Types.Stretch, default: :low, allow_nil?: false, public?: true
    attribute :fit_length, :string, default: "regular", public?: true
    attribute :cut, :string, public?: true
    attribute :weight, :string, public?: true

    attribute :activities, {:array, :string}, default: [], allow_nil?: false, public?: true
    attribute :image_url, :string, public?: true

    attribute :size_system, :string, default: "US", allow_nil?: false, public?: true
    attribute :measurement_unit, :string, default: "inches", allow_nil?: false, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :category, Fitzyo.Catalog.Category do
      attribute_type :string
      allow_nil? false
      public? true
    end

    # No default sort here: list aggregates with `uniq?` inherit relationship
    # sorts, and Postgres rejects `array_agg(DISTINCT x ORDER BY y)`.
    # Use `list_variants_for_product/1` or `load: [variants: [sort: ...]]`.
    has_many :variants, Fitzyo.Catalog.Variant

    has_many :size_guide_entries, Fitzyo.Catalog.SizeGuideEntry do
      sort position: :asc
    end
  end

  aggregates do
    exists :available, :variants do
      public? true
      filter expr(inventory_quantity > 0)
    end

    list :sizes, :variants, :size do
      public? true
      uniq? true
    end

    list :colors, :variants, :color do
      public? true
      uniq? true
    end

    list :available_sizes, :variants, :size do
      public? true
      uniq? true
      filter expr(inventory_quantity > 0)
    end

    list :available_colors, :variants, :color do
      public? true
      uniq? true
      filter expr(inventory_quantity > 0)
    end
  end
end
