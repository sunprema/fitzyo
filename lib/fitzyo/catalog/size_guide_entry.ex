defmodule Fitzyo.Catalog.SizeGuideEntry do
  @moduledoc """
  One row of a product's structured size guide, e.g. `XL → chest 44–46"`.

  Measurements are in the product's `measurement_unit`. Fields that do not
  apply to a garment type (neck on shorts, inseam on shirts) are left nil.
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "size_guide_entries"
    repo Fitzyo.Repo

    references do
      reference :product, on_delete: :delete
    end
  end

  actions do
    defaults [:read]

    create :create do
      accept [
        :product_id,
        :size,
        :position,
        :chest_min,
        :chest_max,
        :waist_min,
        :waist_max,
        :hip_min,
        :hip_max,
        :neck,
        :sleeve,
        :inseam
      ]

      upsert? true
      upsert_identity :unique_size_per_product
    end

    read :for_product do
      argument :product_id, :string, allow_nil?: false
      filter expr(product_id == ^arg(:product_id))
      prepare build(sort: [position: :asc])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :size, :string, allow_nil?: false, public?: true
    attribute :position, :integer, default: 0, allow_nil?: false, public?: true

    attribute :chest_min, :decimal, public?: true
    attribute :chest_max, :decimal, public?: true
    attribute :waist_min, :decimal, public?: true
    attribute :waist_max, :decimal, public?: true
    attribute :hip_min, :decimal, public?: true
    attribute :hip_max, :decimal, public?: true
    attribute :neck, :decimal, public?: true
    attribute :sleeve, :decimal, public?: true
    attribute :inseam, :decimal, public?: true
  end

  relationships do
    belongs_to :product, Fitzyo.Catalog.Product do
      attribute_type :string
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_size_per_product, [:product_id, :size]
  end
end
