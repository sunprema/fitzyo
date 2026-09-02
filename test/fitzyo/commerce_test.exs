defmodule Fitzyo.CommerceTest do
  use Fitzyo.DataCase, async: true

  import Fitzyo.CatalogFixtures

  alias Fitzyo.Commerce

  setup do
    product = product_fixture(%{price: Decimal.new("45.00")})

    [blue_xl, blue_l, red_xl] =
      variants_fixture(product, ["blue", "red"], ["XL", "L"], fn color, size ->
        cond do
          color == "red" and size == "XL" -> 0
          color == "blue" and size == "L" -> 2
          true -> 10
        end
      end)
      |> then(fn [bxl, bl, rxl, _rl] -> [bxl, bl, rxl] end)

    cart = Commerce.ensure_cart!(Ash.UUID.generate())

    %{cart: cart, product: product, blue_xl: blue_xl, blue_l: blue_l, red_xl: red_xl}
  end

  describe "ensure_cart/1" do
    test "is idempotent for the same session id", %{cart: cart} do
      assert Commerce.ensure_cart!(cart.id).id == cart.id
    end
  end

  describe "add_to_cart/3" do
    test "adds a variant with its price snapshotted and an optional label", ctx do
      item = Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id, %{label: "Dad"})

      assert item.quantity == 1
      assert item.label == "Dad"
      assert Decimal.equal?(item.unit_price, "45.00")
    end

    test "adding the same variant again increases quantity instead of duplicating", ctx do
      first = Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id, %{label: "Dad"})
      second = Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id, %{quantity: 2})

      assert second.id == first.id
      assert second.quantity == 3
      assert second.label == "Dad"

      cart = Commerce.get_cart!(ctx.cart.id, load: [:item_count, :subtotal, :items])
      assert length(cart.items) == 1
      assert cart.item_count == 3
      assert Decimal.equal?(cart.subtotal, "135.00")
    end

    test "rejects unknown, sold-out, and over-stock requests with coded messages", ctx do
      assert {:error, error} = Commerce.add_to_cart(ctx.cart.id, "nope_nope")
      assert Exception.message(error) =~ "VARIANT_NOT_FOUND"

      assert {:error, error} = Commerce.add_to_cart(ctx.cart.id, ctx.red_xl.id)
      assert Exception.message(error) =~ "VARIANT_UNAVAILABLE"

      assert {:error, error} = Commerce.add_to_cart(ctx.cart.id, ctx.blue_l.id, %{quantity: 3})
      assert Exception.message(error) =~ "INSUFFICIENT_STOCK"

      Commerce.add_to_cart!(ctx.cart.id, ctx.blue_l.id, %{quantity: 2})
      assert {:error, error} = Commerce.add_to_cart(ctx.cart.id, ctx.blue_l.id)
      assert Exception.message(error) =~ "INSUFFICIENT_STOCK"
    end

    test "rejects a zero quantity", ctx do
      assert {:error, %Ash.Error.Invalid{}} =
               Commerce.add_to_cart(ctx.cart.id, ctx.blue_xl.id, %{quantity: 0})
    end
  end

  describe "cart modification" do
    test "quantity can be changed and items removed", ctx do
      item = Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id)
      other = Commerce.add_to_cart!(ctx.cart.id, ctx.blue_l.id)

      updated = Commerce.set_cart_item_quantity!(item, 4)
      assert updated.quantity == 4

      Commerce.remove_from_cart!(other)

      cart = Commerce.get_cart!(ctx.cart.id, load: [:item_count, items: [:line_total]])
      assert cart.item_count == 4
      assert [%{line_total: total}] = cart.items
      assert Decimal.equal?(total, "180.00")
    end

    test "clear_cart/1 empties the cart", ctx do
      Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id)
      assert :ok = Commerce.clear_cart(ctx.cart.id)
      assert Commerce.get_cart!(ctx.cart.id, load: [:item_count]).item_count == 0
    end
  end

  describe "checkout_cart/1" do
    test "returns an order summary, empties the cart, and records the order number", ctx do
      Commerce.add_to_cart!(ctx.cart.id, ctx.blue_xl.id, %{quantity: 2})

      assert {:ok, %{order_number: "FZ-" <> _ = number, item_count: 2, subtotal: subtotal}} =
               Commerce.checkout_cart(ctx.cart.id)

      assert Decimal.equal?(subtotal, "90.00")

      cart = Commerce.get_cart!(ctx.cart.id, load: [:item_count])
      assert cart.item_count == 0
      assert cart.last_order_number == number
      assert cart.checked_out_at
    end

    test "refuses to check out an empty cart", ctx do
      assert {:error, error} = Commerce.checkout_cart(ctx.cart.id)
      assert Exception.message(error) =~ "CART_EMPTY"
    end
  end
end
