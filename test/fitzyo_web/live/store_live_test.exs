defmodule FitzyoWeb.StoreLiveTest do
  use FitzyoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fitzyo.CatalogFixtures

  setup do
    shirts =
      category_fixture(%{id: "shirts-#{System.unique_integer([:positive])}", name: "Shirts"})

    shorts =
      category_fixture(%{id: "shorts-#{System.unique_integer([:positive])}", name: "Shorts"})

    shirt =
      product_fixture(%{
        category_id: shirts.id,
        name: "Bahama Shirt",
        brand: "Columbia",
        fit: :relaxed,
        price: Decimal.new("45"),
        activities: ["beach"]
      })

    short =
      product_fixture(%{
        category_id: shorts.id,
        name: "Quandary Short",
        brand: "Patagonia",
        fit: :regular,
        price: Decimal.new("79"),
        activities: ["hiking"]
      })

    variants_fixture(shirt, ["blue", "sage"], ["L", "XL"], fn color, size ->
      if color == "sage" and size == "XL", do: 0, else: 5
    end)

    variants_fixture(short, ["black"], ["32", "34"], 2)

    size_guide_fixture(shirt, [
      %{size: "L", chest_min: 41, chest_max: 43},
      %{size: "XL", chest_min: 44, chest_max: 46}
    ])

    %{shirts: shirts, shorts: shorts, shirt: shirt, short: short}
  end

  describe "results" do
    test "lists products with stable semantic ids", %{conn: conn, shirt: shirt, short: short} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#product-#{shirt.id}[data-brand='Columbia']")
      assert has_element?(view, "#product-#{short.id}[data-category='#{short.category_id}']")
      assert has_element?(view, "#results-count", "products found")
    end

    test "search narrows results and shows a removable chip", %{
      conn: conn,
      shirt: shirt,
      short: short
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#store-search", %{q: "bahama"}) |> render_submit()

      assert_patch(view, ~p"/?q=bahama")
      assert has_element?(view, "#product-#{shirt.id}")
      refute has_element?(view, "#product-#{short.id}")
      assert has_element?(view, "#active-filters")

      view |> element("#clear-filters") |> render_click()
      assert_patch(view, ~p"/")
      assert has_element?(view, "#product-#{short.id}")
    end

    test "category, size and color filters compose through the URL", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      view |> element("#filter-category-#{ctx.shirts.id}") |> render_click()
      assert_patch(view, ~p"/?category=#{ctx.shirts.id}")
      assert has_element?(view, "#filter-size-xl")
      refute has_element?(view, "#product-#{ctx.short.id}")

      view |> element("#filter-size-xl") |> render_click()
      view |> element("#filter-color-sage") |> render_click()

      # sage XL is sold out, so the same-variant rule hides the shirt
      assert has_element?(view, "#results-empty")

      view |> element("#filter-color-sage") |> render_click()
      view |> element("#filter-color-blue") |> render_click()
      assert has_element?(view, "#product-#{ctx.shirt.id}")
    end

    test "the shop-for facet narrows by gender and toggles off", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      view |> element("#filter-gender-women") |> render_click()
      assert_patch(view, ~p"/?gender=women")
      assert has_element?(view, "#results-empty")

      view |> element("#filter-gender-women") |> render_click()
      assert_patch(view, ~p"/")
      assert has_element?(view, "#product-#{ctx.shirt.id}")
    end

    test "visiting with filters in the URL applies them", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/?brand[]=Patagonia&max=100")

      assert has_element?(view, "#product-#{ctx.short.id}")
      refute has_element?(view, "#product-#{ctx.shirt.id}")
      assert has_element?(view, "#filter-brand-patagonia input[checked]")
    end
  end

  describe "product detail" do
    test "shows variants, size guide and lets the shopper pick a color and size", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/products/#{ctx.shirt.id}")

      assert has_element?(
               view,
               "#product-#{ctx.shirt.id}[data-selected-color='blue'][data-selected-size='L']"
             )

      assert has_element?(view, "#variant-#{ctx.shirt.id}_blue_xl[data-available='true']")

      view |> element("#variant-#{ctx.shirt.id}_blue_xl") |> render_click()

      assert has_element?(
               view,
               "#product-#{ctx.shirt.id}[data-selected-variant-id='#{ctx.shirt.id}_blue_xl']"
             )

      # switching color keeps the chosen size and reports it honestly when sold out
      view |> element("#variant-#{ctx.shirt.id}-sage") |> render_click()

      assert has_element?(
               view,
               "#variant-#{ctx.shirt.id}_sage_xl[data-available='false'][disabled]"
             )

      assert has_element?(view, "#product-#{ctx.shirt.id}[data-selected-size='XL']")
      assert has_element?(view, "#add-to-cart[disabled]", "Unavailable in this size")

      view |> element("#variant-#{ctx.shirt.id}_sage_l") |> render_click()
      assert has_element?(view, "#add-to-cart:not([disabled])", "Add to Cart")

      refute has_element?(view, "#size-guide")
      view |> element("#toggle-size-guide") |> render_click()
      assert has_element?(view, "#size-guide td", "44–46")
    end

    test "back to results keeps the active filters", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/?category=#{ctx.shirts.id}")

      view |> element("#product-#{ctx.shirt.id} a", "Bahama Shirt") |> render_click()
      assert_patch(view, ~p"/products/#{ctx.shirt.id}?category=#{ctx.shirts.id}")

      view |> element("#back-to-results") |> render_click()
      assert_patch(view, ~p"/?category=#{ctx.shirts.id}")
    end

    test "an unknown product falls back to results with a message", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => message}}}} =
               live(conn, ~p"/products/nope")

      assert message =~ "couldn't find that product"
    end
  end

  describe "cart" do
    test "adding, adjusting, removing and checking out", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/products/#{ctx.shirt.id}")

      refute has_element?(view, "#cart-count")
      view |> element("#add-to-cart") |> render_click()

      assert has_element?(view, "#cart-drawer")
      assert has_element?(view, "#cart-count", "1")

      assert has_element?(
               view,
               "#cart-items li[data-variant-id='#{ctx.shirt.id}_blue_l'][data-quantity='1']"
             )

      assert has_element?(view, "#cart-subtotal", "$45.00")

      view |> element("#cart-items li [aria-label='Increase quantity']") |> render_click()
      assert has_element?(view, "#cart-count", "2")
      assert has_element?(view, "#cart-subtotal", "$90.00")

      view |> element("#cart-items li [aria-label='Decrease quantity']") |> render_click()
      assert has_element?(view, "#cart-count", "1")

      view |> element("#checkout") |> render_click()
      assert has_element?(view, "#order-confirmation", "Order confirmed")
      refute has_element?(view, "#cart-count")

      view |> element("#order-confirmation button", "Done") |> render_click()
      refute has_element?(view, "#order-confirmation")
    end

    test "the cart survives navigation because it is keyed by the session", ctx do
      # One plain request establishes the session cookie that both LiveViews share.
      conn = get(ctx.conn, ~p"/")

      {:ok, view, _html} = live(conn, ~p"/products/#{ctx.shirt.id}")
      view |> element("#add-to-cart") |> render_click()

      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#cart-count", "1")

      view |> element("#cart-button") |> render_click()
      view |> element("#cart-items li button", "Remove") |> render_click()
      assert has_element?(view, "#cart-empty")
      assert has_element?(view, "#checkout[disabled]")
    end

    test "stock limits are enforced with a visible error", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/products/#{ctx.short.id}")

      view |> element("#add-to-cart") |> render_click()
      view |> element("#cart-items li [aria-label='Increase quantity']") |> render_click()
      html = view |> element("#cart-items li [aria-label='Increase quantity']") |> render_click()

      assert html =~ "INSUFFICIENT_STOCK"
      refute html =~ "Bread Crumbs"
      assert has_element?(view, "#cart-count", "2")
    end
  end

  describe "agent panel" do
    test "can be collapsed and expanded", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#agent-panel[data-open='true']")

      view |> element("#agent-panel [aria-label='Collapse agent panel']") |> render_click()
      assert has_element?(view, "#agent-panel[data-open='false']")
    end
  end
end
