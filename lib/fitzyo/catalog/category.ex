defmodule Fitzyo.Catalog.Category do
  @moduledoc """
  A top-level product category such as `shirts` or `swimwear`.

  The primary key is the stable, human-readable category id that agents use
  (`category_id` in the WebMCP spec).
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Catalog,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "categories"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read]

    create :create do
      accept [:id, :name, :description, :position]
      upsert? true
    end
  end

  preparations do
    prepare build(sort: [position: :asc, name: :asc]), on: [:read]
  end

  attributes do
    attribute :id, :string do
      primary_key? true
      allow_nil? false
      public? true
      constraints match: ~r/^[a-z0-9-]+$/
    end

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :description, :string, public?: true
    attribute :position, :integer, default: 0, allow_nil?: false, public?: true
  end

  relationships do
    has_many :products, Fitzyo.Catalog.Product
  end

  aggregates do
    count :product_count, :products do
      public? true
    end
  end
end
