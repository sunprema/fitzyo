defmodule Fitzyo.Commerce do
  @moduledoc """
  Shopping carts. A cart belongs to a browser session, never to an identified
  customer: the retailer only ever sees variant ids, quantities, and an
  optional free-text label (such as "Dad") the shopper's agent chooses to add.

  Checkout is deliberately a human-only step (WEBMCP_SPEC §52); nothing here
  processes payment.
  """

  use Ash.Domain,
    otp_app: :fitzyo

  resources do
    resource Fitzyo.Commerce.Cart do
      define :ensure_cart, action: :ensure, args: [:id]
      define :get_cart, action: :read, get_by: [:id]
      define :clear_cart, action: :clear, args: [:cart_id]
      define :checkout_cart, action: :checkout, args: [:cart_id]
    end

    resource Fitzyo.Commerce.CartItem do
      define :add_to_cart, action: :add, args: [:cart_id, :variant_id]
      define :get_cart_item, action: :read, get_by: [:id]
      define :set_cart_item_quantity, action: :set_quantity, args: [:quantity]
      define :remove_from_cart, action: :destroy
    end
  end
end
