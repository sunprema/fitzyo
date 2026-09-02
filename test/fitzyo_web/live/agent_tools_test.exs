defmodule FitzyoWeb.StoreLive.AgentToolsTest do
  @moduledoc """
  Drives the WebMCP tool surface the way the browser hook does: a
  `webmcp:call` event in, a `webmcp:result` push out, and the human UI
  updated in between.
  """

  use FitzyoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Fitzyo.CatalogFixtures

  alias FitzyoWeb.StoreLive.AgentTools

  @tool_names ~w(get_store_info get_categories search_products filter_products get_product
                 get_variants get_size_guide find_matching_variants compare_products get_cart
                 add_to_cart remove_from_cart update_cart_item focus_product focus_filter)

  setup do
    shirts =
      category_fixture(%{id: "shirts-#{System.unique_integer([:positive])}", name: "Shirts"})

    shorts =
      category_fixture(%{id: "shorts-#{System.unique_integer([:positive])}", name: "Shorts"})

    columbia =
      product_fixture(%{
        category_id: shirts.id,
        name: "Bahama Shirt",
        brand: "Columbia",
        fit: :relaxed,
        price: Decimal.new("45"),
        activities: ["travel", "beach"]
      })

    patagonia =
      product_fixture(%{
        category_id: shirts.id,
        name: "Capilene Shirt",
        brand: "Patagonia",
        fit: :regular,
        price: Decimal.new("49"),
        activities: ["hiking"]
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

    variants_fixture(columbia, ["blue", "sage"], ["L", "XL"], fn color, size ->
      if color == "sage" and size == "XL", do: 0, else: 5
    end)

    variants_fixture(patagonia, ["black"], ["L", "XL"], 2)
    variants_fixture(short, ["black"], ["32", "34"], 4)

    size_guide_fixture(columbia, [
      %{size: "L", chest_min: 41, chest_max: 43},
      %{size: "XL", chest_min: 44, chest_max: 46}
    ])

    %{shirts: shirts, shorts: shorts, columbia: columbia, patagonia: patagonia, short: short}
  end

  defp call(view, tool, input \\ %{}) do
    id = System.unique_integer([:positive])
    render_hook(view, "webmcp:call", %{"id" => id, "tool" => tool, "input" => input})
    assert_push_event(view, "webmcp:result", %{id: ^id} = payload)
    payload
  end

  defp ok!(view, tool, input \\ %{}) do
    assert %{status: "ok", result: result} = call(view, tool, input)
    result
  end

  defp error!(view, tool, input) do
    assert %{status: "error", error: json} = call(view, tool, input)
    Jason.decode!(json)
  end

  describe "tool surface" do
    test "registers all fifteen semantic tools with schemas and annotations", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert_push_event(view, "webmcp:register", %{tools: tools})
      assert Enum.map(tools, & &1.name) == @tool_names

      for tool <- tools do
        assert tool.input_schema.type == "object"
        assert is_map(tool.annotations)
      end

      assert Enum.find(tools, &(&1.name == "get_cart")).annotations.readOnlyHint
      refute Enum.find(tools, &(&1.name == "add_to_cart")).annotations.readOnlyHint
      refute Enum.any?(tools, &(&1.annotations[:destructive?] == true))
      assert length(AgentTools.tools()) == 15
    end

    test "unknown tools and malformed input return structured errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert %{status: "error", error: "Unknown tool"} = call(view, "click_button")

      assert %{"code" => "INVALID_OPERATION", "success" => false} =
               error!(view, "get_product", %{})
    end
  end

  describe "discovery" do
    test "get_store_info and get_categories describe the retailer", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      info = ok!(view, "get_store_info")
      assert info.store.name == "FitzYo Retail"
      assert "cart" in info.capabilities
      assert ctx.shirts.id in info.categories

      cats = ok!(view, "get_categories")
      assert Enum.find(cats.categories, &(&1.id == ctx.shirts.id)).product_count == 2

      assert has_element?(view, "#agent-activity li[data-status='ok']", "get_categories()")
      assert has_element?(view, "#agent-status[data-agent-connected='true']")
    end
  end

  describe "search and filter" do
    test "search_products sets the search state and returns results", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result = ok!(view, "search_products", %{"query" => "bahama"})
      assert result.total == 1
      assert [%{product_id: id, price: %{amount: 45.0, currency: "USD"}}] = result.results
      assert id == ctx.columbia.id

      assert_patch(view, ~p"/?q=bahama")
      assert has_element?(view, "#store-search-input[value='bahama']")
      refute has_element?(view, "#product-#{ctx.short.id}")
    end

    test "filter_products replaces filters, updates the URL, and validates input", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "filter_products", %{
          "category" => ctx.shirts.id,
          "size" => ["XL"],
          "color" => ["Blue", "black"],
          "brand" => ["Columbia", "Patagonia"],
          "price_max" => 80
        })

      assert result.total == 2
      assert result.filters_applied["color"] == ["blue", "black"]
      assert_patch(view)
      assert has_element?(view, "#filter-size-xl[aria-pressed='true']")
      assert has_element?(view, "#filter-color-blue[aria-pressed='true']")
      assert has_element?(view, "#active-filters", "Under $80")
      assert has_element?(view, "#filter-gender-men[aria-pressed='false']")

      # gender narrows to a shopper group and shows in the sidebar
      assert ok!(view, "filter_products", %{"category" => ctx.shirts.id, "gender" => "women"}).total ==
               0

      assert has_element?(view, "#filter-gender-women[aria-pressed='true']")
      assert has_element?(view, "#active-filters", "Women")

      # sage XL is sold out: same-variant rule
      result =
        ok!(view, "filter_products", %{
          "category" => ctx.shirts.id,
          "size" => ["XL"],
          "color" => ["sage"]
        })

      assert result.total == 0
      assert has_element?(view, "#results-empty")

      # replacing with {} clears everything
      assert ok!(view, "filter_products", %{}).total == 3
      assert_patch(view, ~p"/")

      assert %{"code" => "INVALID_CATEGORY"} =
               error!(view, "filter_products", %{"category" => "hats"})

      assert %{"code" => "INVALID_FILTER"} =
               error!(view, "filter_products", %{"fit" => ["baggy"]})

      assert %{"code" => "INVALID_FILTER"} = error!(view, "filter_products", %{"price_max" => -1})
      assert has_element?(view, "#agent-activity li[data-status='error']")
    end
  end

  describe "product information" do
    test "get_product, get_variants and get_size_guide are read-only and structured", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      %{product: product} = ok!(view, "get_product", %{"product_id" => ctx.columbia.id})

      assert product.fit == %{
               profile: "relaxed",
               stretch: "low",
               length: "regular",
               cut: nil,
               weight: nil
             }

      assert product.available_sizes == ["L", "XL"]
      assert product.available_colors == ["blue", "sage"]

      %{variants: variants} = ok!(view, "get_variants", %{"product_id" => ctx.columbia.id})
      assert length(variants) == 4
      sage_xl = Enum.find(variants, &(&1.variant_id == "#{ctx.columbia.id}_sage_xl"))
      refute sage_xl.available
      assert sage_xl.inventory_status == "out_of_stock"

      guide = ok!(view, "get_size_guide", %{"product_id" => ctx.columbia.id})
      assert guide.unit == "inches"
      assert [%{size: "L", chest_min: 41.0, chest_max: 43.0}, %{size: "XL"}] = guide.measurements

      assert %{"code" => "PRODUCT_NOT_FOUND", "product_id" => "nope"} =
               error!(view, "get_product", %{"product_id" => "nope"})

      # still on the results page, nothing selected
      refute has_element?(view, "#product-detail-#{ctx.columbia.id}")
    end
  end

  describe "find_matching_variants" do
    test "returns strict matches and narrows the human's view", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "find_matching_variants", %{
          "category" => ctx.shirts.id,
          "size" => "xl",
          "color" => ["blue", "black"],
          "brand" => ["Columbia"],
          "fit" => "relaxed",
          "price_max" => 50
        })

      assert result.strict
      assert [match] = result.matches
      assert match.variant_id == "#{ctx.columbia.id}_blue_xl"
      assert match.match == %{size: true, color: true, brand: true, fit: true, price: true}
      assert match.match_score == 1.0

      assert_patch(view)
      assert has_element?(view, "#filter-brand-columbia input[checked]")
      assert has_element?(view, "#product-#{ctx.columbia.id}")
      refute has_element?(view, "#product-#{ctx.patagonia.id}")
    end

    test "falls back to hard constraints and explains what did not match", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "find_matching_variants", %{
          "category" => ctx.shirts.id,
          "size" => "XL",
          "color" => ["red"],
          "brand" => ["Columbia"]
        })

      refute result.strict
      assert result.total == 2
      [best | _] = result.matches
      assert best.brand == "Columbia"
      assert best.match == %{size: true, color: false, brand: true}
      assert best.match_score == 0.67

      # only the hard constraints reach the UI
      assert has_element?(view, "#filter-size-xl[aria-pressed='true']")
      refute has_element?(view, "#filter-brand-columbia input[checked]")
    end
  end

  describe "compare_products" do
    test "shows the comparison to the human, who can clear it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "compare_products", %{"product_ids" => [ctx.columbia.id, ctx.patagonia.id]})

      assert Enum.map(result.products, & &1.brand) == ["Columbia", "Patagonia"]

      assert has_element?(
               view,
               "#comparison[data-product-ids='#{ctx.columbia.id},#{ctx.patagonia.id}']"
             )

      assert_push_event(view, "fz:focus", %{id: "comparison"})

      view |> element("#compare-clear") |> render_click()
      refute has_element?(view, "#comparison")

      assert %{"code" => "PRODUCT_NOT_FOUND"} =
               error!(view, "compare_products", %{"product_ids" => [ctx.columbia.id, "ghost"]})
    end
  end

  describe "cart" do
    test "add, inspect, update, and remove with validation", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"

      result =
        ok!(view, "add_to_cart", %{
          "product_id" => ctx.columbia.id,
          "variant_id" => blue_xl,
          "label" => "Dad"
        })

      assert result.success
      assert result.cart == %{item_count: 1, subtotal: 45.0, currency: "USD"}
      assert has_element?(view, "#cart-count", "1")
      assert_push_event(view, "fz:focus", %{id: "cart-button"})

      # same variant again increments rather than duplicating
      assert ok!(view, "add_to_cart", %{
               "product_id" => ctx.columbia.id,
               "variant_id" => blue_xl,
               "quantity" => 2
             }).cart.item_count == 3

      %{cart: cart} = ok!(view, "get_cart")

      assert [
               %{
                 variant_id: ^blue_xl,
                 quantity: 3,
                 label: "Dad",
                 size: "XL",
                 color: "blue",
                 unit_price: 45.0
               }
             ] = cart.items

      assert cart.subtotal == 135.0

      assert ok!(view, "update_cart_item", %{"variant_id" => blue_xl, "quantity" => 1}).cart.item_count ==
               1

      assert %{"code" => "VARIANT_UNAVAILABLE"} =
               error!(view, "update_cart_item", %{"variant_id" => blue_xl, "quantity" => 99})

      assert %{"code" => "INVALID_QUANTITY"} =
               error!(view, "add_to_cart", %{
                 "product_id" => ctx.columbia.id,
                 "variant_id" => blue_xl,
                 "quantity" => 0
               })

      assert %{"code" => "VARIANT_UNAVAILABLE"} =
               error!(view, "add_to_cart", %{
                 "product_id" => ctx.columbia.id,
                 "variant_id" => "#{ctx.columbia.id}_sage_xl"
               })

      assert %{"code" => "VARIANT_NOT_FOUND"} =
               error!(view, "add_to_cart", %{
                 "product_id" => ctx.patagonia.id,
                 "variant_id" => blue_xl
               })

      # failed calls leave the cart untouched
      assert ok!(view, "get_cart").cart.item_count == 1

      assert ok!(view, "remove_from_cart", %{"variant_id" => blue_xl}).cart.item_count == 0

      assert %{"code" => "CART_ITEM_NOT_FOUND"} =
               error!(view, "remove_from_cart", %{"variant_id" => blue_xl})

      refute has_element?(view, "#cart-count")
    end

    test "the agent's cart is the human's cart", ctx do
      conn = get(ctx.conn, ~p"/")
      {:ok, view, _html} = live(conn, ~p"/products/#{ctx.short.id}")
      view |> element("#add-to-cart") |> render_click()

      %{cart: cart} = ok!(view, "get_cart")
      assert [%{product_id: id, size: "32"}] = cart.items
      assert id == ctx.short.id
    end
  end

  describe "UI focus" do
    test "focus_product opens the product with the requested variant selected", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/?category=#{ctx.shirts.id}")
      sage_l = "#{ctx.columbia.id}_sage_l"

      result =
        ok!(view, "focus_product", %{"product_id" => ctx.columbia.id, "variant_id" => sage_l})

      assert result.variant_id == sage_l

      assert_patch(view, ~p"/products/#{ctx.columbia.id}?category=#{ctx.shirts.id}")

      assert has_element?(
               view,
               "#product-#{ctx.columbia.id}[data-selected-variant-id='#{sage_l}']"
             )

      assert_push_event(view, "fz:focus", %{id: "product-" <> _})

      assert %{"code" => "VARIANT_NOT_FOUND"} =
               error!(view, "focus_product", %{
                 "product_id" => ctx.columbia.id,
                 "variant_id" => "nope"
               })
    end

    test "focus_filter highlights a sidebar section and rejects unknown ids", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      assert ok!(view, "focus_filter", %{"filter_id" => "color"}).success
      assert_push_event(view, "fz:focus", %{id: "filter-colors"})

      assert %{"code" => "INVALID_FILTER"} = error!(view, "focus_filter", %{"filter_id" => "dom"})
    end

    test "the transport report marks the agent as connected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#agent-status[data-agent-connected='false']")

      render_hook(view, "webmcp:transport", %{"native" => true, "tools" => 15})
      assert has_element?(view, "#agent-status[data-agent-connected='true']")
      assert has_element?(view, "#agent-panel", "(native)")
    end
  end
end
