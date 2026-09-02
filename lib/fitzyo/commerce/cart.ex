defmodule Fitzyo.Commerce.Cart do
  @moduledoc """
  A session-scoped shopping cart. The id is minted by the web layer and kept
  in the browser session, so the same cart is shared by the human's UI and any
  agent driving that page.
  """

  use Ash.Resource,
    otp_app: :fitzyo,
    domain: Fitzyo.Commerce,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "carts"
    repo Fitzyo.Repo
  end

  actions do
    defaults [:read]

    create :ensure do
      description "Creates the cart with the given id if it does not exist yet."
      accept [:id]
      upsert? true
    end

    update :record_order do
      accept [:last_order_number]
      change set_attribute(:checked_out_at, &DateTime.utc_now/0)
    end

    action :clear do
      description "Removes every item from the cart."
      argument :cart_id, :uuid, allow_nil?: false
      run Fitzyo.Commerce.Cart.Actions.Clear
    end

    action :checkout, :map do
      description """
      Human-only demo checkout: empties the cart and returns an order number.
      No payment is processed. Never expose this to an agent.
      """

      argument :cart_id, :uuid, allow_nil?: false
      run Fitzyo.Commerce.Cart.Actions.Checkout
    end
  end

  attributes do
    uuid_primary_key :id, writable?: true

    attribute :last_order_number, :string, public?: true
    attribute :checked_out_at, :utc_datetime_usec, public?: true

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    has_many :items, Fitzyo.Commerce.CartItem do
      sort inserted_at: :asc
    end
  end

  aggregates do
    sum :item_count, :items, :quantity do
      public? true
      default 0
    end

    sum :subtotal, :items, :line_total do
      public? true
      default Decimal.new(0)
    end
  end
end
