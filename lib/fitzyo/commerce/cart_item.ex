defmodule Fitzyo.Commerce.CartItem do
  @moduledoc """
  One purchasable variant in a cart, with the quantity and the unit price
  captured when it was added. `label` is an optional shopper-supplied tag such
  as "Dad" so a family cart stays readable; the retailer attaches no meaning
  to it.
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Commerce,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "cart_items"
    repo Fitzyo.Repo

    references do
      reference :cart, on_delete: :delete
      reference :variant, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :cart_id,
        :variant_id,
        :quantity,
        :label,
        :unit_price,
        :source,
        :proposed_variant_id
      ]
    end

    update :set_quantity do
      accept [:quantity, :label]
    end

    update :increment do
      argument :by, :integer, allow_nil?: false, default: 1
      change atomic_update(:quantity, expr(quantity + ^arg(:by)))
    end

    action :add, :struct do
      description """
      Adds a variant to a cart, or increases its quantity if it is already there.
      Fails if the variant does not exist or is out of stock.
      """

      constraints instance_of: __MODULE__

      argument :cart_id, :uuid, allow_nil?: false
      argument :variant_id, :string, allow_nil?: false

      argument :quantity, :integer do
        allow_nil? false
        default 1
        constraints min: 1
      end

      argument :label, :string

      argument :source, Fitzyo.Commerce.Types.LineSource do
        description "Who put the line in the cart: the human, an agent tool call, or an accepted agent proposal"
        default :human
      end

      argument :proposed_variant_id, :string do
        description "For a proposal line the human swapped: the variant the agent originally proposed"
      end

      run Fitzyo.Commerce.CartItem.Actions.Add
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :quantity, :integer do
      allow_nil? false
      default 1
      public? true
      constraints min: 1
    end

    attribute :label, :string, public?: true

    attribute :source, Fitzyo.Commerce.Types.LineSource do
      description "Provenance: human, agent, or proposal (accepted by the human)"
      allow_nil? false
      default :human
      public? true
    end

    attribute :proposed_variant_id, :string do
      description "Set when the human swapped an agent-proposed line for an alternative the agent offered; records what was proposed"
      public? true
    end

    attribute :unit_price, :decimal do
      allow_nil? false
      public? true
      constraints min: 0
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :cart, Fitzyo.Commerce.Cart do
      allow_nil? false
      public? true
    end

    belongs_to :variant, Fitzyo.Catalog.Variant do
      attribute_type :string
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :line_total, :decimal, expr(unit_price * quantity), public?: true
  end

  identities do
    identity :unique_variant_per_cart, [:cart_id, :variant_id]
  end
end
