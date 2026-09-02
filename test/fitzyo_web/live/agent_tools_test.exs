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
                 add_to_cart remove_from_cart update_cart_item clear_cart recommend_product
                 present_plan agent_update ask_human propose_cart get_store_state focus_product
                 focus_filter)

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
      assert length(AgentTools.tools()) == 22
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

      # a new search starts fresh unless the agent asks to keep the filters
      ok!(view, "filter_products", %{"category" => ctx.shorts.id})
      assert ok!(view, "search_products", %{"query" => "bahama"}).total == 1
      assert_patch(view, ~p"/?q=bahama")

      ok!(view, "filter_products", %{"category" => ctx.shorts.id})

      assert ok!(view, "search_products", %{"query" => "bahama", "keep_filters" => true}).total ==
               0

      assert has_element?(view, "#filter-category-#{ctx.shorts.id}[aria-pressed='true']")
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
      refute result.truncated
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

    test "clear_cart empties everything at once", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => "#{ctx.columbia.id}_blue_xl",
        "quantity" => 2
      })

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.short.id,
        "variant_id" => "#{ctx.short.id}_black_32"
      })

      assert has_element?(view, "#cart-count", "3")

      assert ok!(view, "clear_cart").cart == %{item_count: 0, subtotal: 0.0, currency: "USD"}
      refute has_element?(view, "#cart-count")
      assert ok!(view, "get_cart").cart.items == []
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

  describe "agent annotations" do
    test "a labelled match badges products, tags the variant, and the human can clear it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "find_matching_variants", %{
          "category" => ctx.shirts.id,
          "size" => "XL",
          "color" => ["blue"],
          "label" => "Dad"
        })

      assert result.label == "Dad"
      assert has_element?(view, "#product-#{ctx.columbia.id}[data-fits='Dad']", "Fits Dad")
      refute has_element?(view, "#product-#{ctx.patagonia.id}[data-fits]")
      assert has_element?(view, "#fit-label-dad", "1 product")

      # the badge follows the product to its detail page and marks the variant
      view |> element("#product-#{ctx.columbia.id} a", "Bahama Shirt") |> render_click()

      assert has_element?(
               view,
               "#fit-match-#{ctx.columbia.id}-dad-match[data-variant-id='#{ctx.columbia.id}_blue_xl']"
             )

      assert has_element?(view, "#variant-#{ctx.columbia.id}_blue_xl span", "Dad")

      state = ok!(view, "get_store_state").state

      assert [%{label: "Dad", source: "match", match: %{size: true, color: true}}] =
               state.annotations

      # human override: clear everything the agent attached under "Dad"
      view |> element("#fit-label-dad button") |> render_click()
      refute has_element?(view, "#fit-labels")
      refute has_element?(view, "#fit-match-#{ctx.columbia.id}-dad-match")
      assert ok!(view, "get_store_state").state.annotations == []
    end

    test "relaxed matches are reported but not badged as fits", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "find_matching_variants", %{
          "category" => ctx.shirts.id,
          "size" => "XL",
          "color" => ["red"],
          "label" => "Dad"
        })

      refute result.strict
      refute has_element?(view, "#fit-labels")
    end

    test "recommend_product shows an agent-written reason the human can dismiss", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/products/#{ctx.columbia.id}")

      result =
        ok!(view, "recommend_product", %{
          "product_id" => ctx.columbia.id,
          "variant_id" => "#{ctx.columbia.id}_blue_xl",
          "label" => "Dad",
          "reason" => "Matches his size, preferred color and casual style."
        })

      assert result.success

      assert has_element?(
               view,
               "#fit-match-#{ctx.columbia.id}-dad-recommendation",
               "preferred color"
             )

      assert_push_event(view, "fz:focus", %{id: "product-" <> _})

      view |> element("#fit-match-#{ctx.columbia.id}-dad-recommendation button") |> render_click()
      refute has_element?(view, "#fit-match-#{ctx.columbia.id}-dad-recommendation")

      assert %{"code" => "VARIANT_NOT_FOUND"} =
               error!(view, "recommend_product", %{
                 "product_id" => ctx.columbia.id,
                 "variant_id" => "nope",
                 "label" => "Dad",
                 "reason" => "x"
               })
    end

    test "present_plan renders the agent's plan and validates it", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      result =
        ok!(view, "present_plan", %{
          "title" => "Hawaii — 7 day wardrobe",
          "subtitle" => "Beach, hiking, dinners",
          "groups" => [
            %{
              "label" => "Dad",
              "items" => [
                %{"text" => "3 casual shirts", "status" => "have"},
                %{"text" => "1 hiking short", "status" => "need"}
              ]
            },
            %{
              "label" => "Mom",
              "items" => [
                %{"text" => "1 sundress", "status" => "added", "product_id" => ctx.columbia.id}
              ]
            }
          ]
        })

      assert result.groups == 2
      assert has_element?(view, "#agent-plan", "Hawaii — 7 day wardrobe")
      assert has_element?(view, "#agent-plan li[data-status='need']", "1 hiking short")
      assert ok!(view, "get_store_state").state.plan.title == "Hawaii — 7 day wardrobe"

      view |> element("#agent-plan button[aria-label='Dismiss plan']") |> render_click()
      refute has_element?(view, "#agent-plan")

      assert %{"code" => "INVALID_OPERATION"} =
               error!(view, "present_plan", %{
                 "title" => "x",
                 "groups" => [
                   %{"label" => "Dad", "items" => [%{"text" => "y", "status" => "maybe"}]}
                 ]
               })
    end

    test "get_store_state reflects what the human changed", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      ok!(view, "filter_products", %{"category" => ctx.shirts.id, "color" => ["blue"]})
      # the human swaps blue for sage
      view |> element("#filter-color-blue") |> render_click()
      view |> element("#filter-color-sage") |> render_click()

      state = ok!(view, "get_store_state").state
      assert state.view == "results"
      assert state.filters["color"] == ["sage"]
      assert state.filters["category"] == ctx.shirts.id
      assert state.results_count == 1
      assert state.cart.item_count == 0
    end

    test "the cart drawer groups lines by the agent's labels", ctx do
      conn = get(ctx.conn, ~p"/")
      {:ok, view, _html} = live(conn, ~p"/products/#{ctx.short.id}")

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => "#{ctx.columbia.id}_blue_xl",
        "label" => "Dad"
      })

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.patagonia.id,
        "variant_id" => "#{ctx.patagonia.id}_black_l",
        "label" => "Mom"
      })

      view |> element("#add-to-cart") |> render_click()

      assert has_element?(view, "#cart-group-dad h3", "Dad")
      assert has_element?(view, "#cart-group-mom h3", "Mom")
      assert has_element?(view, "#cart-group-everyone h3", "Your picks")
      assert has_element?(view, "#cart-group-dad li[data-product-id='#{ctx.columbia.id}']")
    end
  end

  describe "agent presence" do
    test "any tool call shows the working banner until the agent goes quiet", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      refute has_element?(view, "#agent-banner")

      ok!(view, "get_categories")
      assert has_element?(view, "#agent-banner[data-status='working']", "Agent is working")

      # the idle timer fires with the tick it was scheduled with
      %{socket: %{assigns: %{agent: %{tick: tick}}}} = :sys.get_state(view.pid)
      send(view.pid, {:fz_agent_idle, tick})
      refute has_element?(view, "#agent-banner")
    end

    test "agent_update drives the banner, progress, and a streamed thought feed", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      ok!(view, "agent_update", %{
        "status" => "working",
        "message" => "Planning Dad's outfits",
        "thought" => "Dad already owns three shirts,",
        "progress" => %{"done" => 2, "total" => 10}
      })

      assert has_element?(
               view,
               "#agent-banner[data-status='working'] #agent-banner-message",
               "Planning Dad's outfits"
             )

      assert has_element?(view, "#agent-progress", "2 / 10")
      assert has_element?(view, "#agent-activity li[data-kind='thought']", "three shirts")

      ok!(view, "agent_update", %{"thought" => " so he only needs two more.", "append" => true})

      assert has_element?(
               view,
               "#agent-activity li[data-kind='thought']",
               "three shirts, so he only needs two more."
             )

      assert view
             |> render()
             |> LazyHTML.from_fragment()
             |> LazyHTML.query("li[data-kind='thought']")
             |> Enum.count() == 1

      # explicit status survives the auto-idle timer
      %{socket: %{assigns: %{agent: %{tick: tick}}}} = :sys.get_state(view.pid)
      send(view.pid, {:fz_agent_idle, tick})
      assert has_element?(view, "#agent-banner[data-status='working']")

      ok!(view, "agent_update", %{"status" => "done", "message" => "Cart is ready for review"})
      assert has_element?(view, "#agent-banner[data-status='done']", "Agent finished")
      assert ok!(view, "get_store_state").state.agent.status == "done"

      view |> element("#agent-banner button[aria-label='Dismiss']") |> render_click()
      refute has_element?(view, "#agent-banner")

      assert %{"code" => "INVALID_FILTER"} =
               error!(view, "agent_update", %{"status" => "sleeping"})

      assert %{"code" => "INVALID_OPERATION"} =
               error!(view, "agent_update", %{"progress" => %{"done" => 1}})
    end

    test "selected items appear in the tray as the agent adds them", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      refute has_element?(view, "#selections")

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => "#{ctx.columbia.id}_blue_xl",
        "label" => "Dad"
      })

      assert has_element?(view, "#selections article[data-label='Dad']", "Bahama Shirt")
      assert has_element?(view, "#selections", "1 item")

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.short.id,
        "variant_id" => "#{ctx.short.id}_black_32",
        "label" => "Milo"
      })

      assert has_element?(view, "#selections article[data-label='Milo']", "Quandary Short")
      assert has_element?(view, "#selections", "2 items")

      ok!(view, "clear_cart")
      refute has_element?(view, "#selections")
    end
  end

  describe "product page preselection" do
    # The product page is the human-approval surface: what the recommendation
    # says and what "Add to Cart" adds must be the same variant.
    test "opening a recommended product preselects the recommended variant", ctx do
      conn = get(ctx.conn, ~p"/")
      {:ok, view, _html} = live(conn, ~p"/")
      sage_l = "#{ctx.columbia.id}_sage_l"

      ok!(view, "recommend_product", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => sage_l,
        "label" => "Dad",
        "reason" => "Fits."
      })

      # navigate the human way, not via focus_product
      view |> element("#product-#{ctx.columbia.id} a", "Bahama Shirt") |> render_click()

      assert has_element?(
               view,
               "#product-#{ctx.columbia.id}[data-selected-variant-id='#{sage_l}']"
             )

      assert has_element?(view, "#add-to-cart[phx-value-variant_id='#{sage_l}']")
      assert ok!(view, "get_store_state").state.selected_variant_id == sage_l
    end

    test "opening a product already in the cart preselects the cart's variant", ctx do
      conn = get(ctx.conn, ~p"/")
      {:ok, view, _html} = live(conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"

      ok!(view, "add_to_cart", %{"product_id" => ctx.columbia.id, "variant_id" => blue_xl})
      view |> element("#product-#{ctx.columbia.id} a", "Bahama Shirt") |> render_click()

      assert has_element?(view, "#add-to-cart[phx-value-variant_id='#{blue_xl}']")
    end

    test "an annotation wins over a cart line, and a sold-out recommendation falls through",
         ctx do
      conn = get(ctx.conn, ~p"/")
      {:ok, view, _html} = live(conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"
      sage_l = "#{ctx.columbia.id}_sage_l"
      sage_xl = "#{ctx.columbia.id}_sage_xl"

      ok!(view, "add_to_cart", %{"product_id" => ctx.columbia.id, "variant_id" => blue_xl})

      ok!(view, "recommend_product", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => sage_l,
        "label" => "Dad",
        "reason" => "Fits."
      })

      view |> element("#product-#{ctx.columbia.id} a", "Bahama Shirt") |> render_click()
      assert has_element?(view, "#add-to-cart[phx-value-variant_id='#{sage_l}']")

      # sold-out recommendation: fall through to the cart line rather than an unpurchasable pick
      ok!(view, "recommend_product", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => sage_xl,
        "label" => "Dad",
        "reason" => "Fits."
      })

      view |> element("#back-to-results") |> render_click()
      view |> element("#product-#{ctx.columbia.id} a", "Bahama Shirt") |> render_click()
      assert has_element?(view, "#add-to-cart[phx-value-variant_id='#{blue_xl}']")
    end

    test "without annotation or cart line the first in-stock variant is preselected", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/products/#{ctx.columbia.id}")
      assert has_element?(view, "#add-to-cart[phx-value-variant_id='#{ctx.columbia.id}_blue_l']")
    end

    test "add_to_cart leaves the active filters alone", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      ok!(view, "filter_products", %{"category" => ctx.shirts.id, "color" => ["blue"]})

      ok!(view, "add_to_cart", %{
        "product_id" => ctx.columbia.id,
        "variant_id" => "#{ctx.columbia.id}_blue_xl"
      })

      assert has_element?(view, "#filter-color-blue[aria-pressed='true']")
      assert ok!(view, "get_store_state").state.filters["category"] == ctx.shirts.id
      refute has_element?(view, "#product-#{ctx.short.id}")
    end
  end

  describe "ask_human" do
    # ask_human is a blocking round-trip: the call is held open until the
    # shopper acts, then the reply is pushed with the original call id.
    defp ask(view, input) do
      id = System.unique_integer([:positive])
      render_hook(view, "webmcp:call", %{"id" => id, "tool" => "ask_human", "input" => input})
      refute_push_event(view, "webmcp:result", %{id: ^id})
      id
    end

    defp answered(view, id) do
      assert_push_event(view, "webmcp:result", %{id: ^id, status: "ok", result: result})
      result
    end

    test "renders options, blocks, and resolves with the chosen option", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      id =
        ask(view, %{
          "question" => "Both dinner pieces put you over budget. Which one?",
          "subtitle" => "Budget is $600; this puts you at $743",
          "options" => [
            %{"id" => "skip_shirt", "label" => "Skip Dad's shirt", "description" => "Saves $118"},
            %{
              "id" => "skip_dress",
              "label" => "Skip Mom's dress",
              "product_id" => ctx.columbia.id,
              "variant_id" => "#{ctx.columbia.id}_blue_xl"
            },
            %{"id" => "go_over", "label" => "Go over budget"}
          ]
        })

      assert has_element?(view, "#agent-question", "Which one?")
      assert has_element?(view, "#agent-banner[data-status='waiting']", "Waiting for you")
      assert has_element?(view, "#question-option-skip_dress", "Bahama Shirt")
      assert has_element?(view, "#question-option-skip_dress", "Blue / XL")
      assert has_element?(view, "#agent-activity li[data-kind='call']", "ask_human")
      assert_push_event(view, "fz:focus", %{id: "agent-question"})

      state = ok!(view, "get_store_state").state
      assert state.pending_question.question =~ "over budget"

      assert Enum.map(state.pending_question.options, & &1.id) == [
               "skip_shirt",
               "skip_dress",
               "go_over"
             ]

      # the human keeps full control while the question is open
      view |> element("#filter-category-#{ctx.shirts.id}") |> render_click()
      assert has_element?(view, "#agent-question")
      assert ok!(view, "get_store_state").state.cart.item_count == 0

      view |> element("#question-option-skip_shirt") |> render_click()
      result = answered(view, id)

      assert %{answered: true, selected: ["skip_shirt"], free_text: nil, question_id: "q_" <> _} =
               result

      refute has_element?(view, "#agent-question")
      refute has_element?(view, "#agent-banner[data-status='waiting']")

      assert has_element?(
               view,
               "#agent-activity li[data-kind='human']",
               "Answered: Skip Dad's shirt"
             )

      assert ok!(view, "get_store_state").state.pending_question == nil
    end

    test "allow_multiple returns every selected id and free text comes back verbatim", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      id =
        ask(view, %{
          "question" => "Which of these can go?",
          "options" => [
            %{"id" => "a", "label" => "A"},
            %{"id" => "b", "label" => "B"},
            %{"id" => "c", "label" => "C"}
          ],
          "allow_multiple" => true,
          "allow_free_text" => true
        })

      view
      |> form("#agent-question-form", %{
        "selected" => ["a", "c"],
        "free_text" => "  keep B for now "
      })
      |> render_submit()

      assert %{answered: true, selected: ["a", "c"], free_text: "keep B for now"} =
               answered(view, id)

      # free-text only prompt
      id = ask(view, %{"question" => "What size does the shirt need to be?"})
      view |> form("#agent-question-form", %{"free_text" => "XL"}) |> render_submit()
      assert %{answered: true, selected: [], free_text: "XL"} = answered(view, id)
    end

    test "dismissal, timeout, and supersession resolve as answered: false", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      options = [%{"id" => "y", "label" => "Yes"}, %{"id" => "n", "label" => "No"}]

      id = ask(view, %{"question" => "Go over budget?", "options" => options})
      view |> element("#dismiss-question") |> render_click()
      assert %{answered: false, reason: "dismissed"} = answered(view, id)
      assert has_element?(view, "#agent-activity li[data-kind='human']", "Dismissed")

      id =
        ask(view, %{"question" => "Go over budget?", "options" => options, "timeout_ms" => 5000})

      %{socket: %{assigns: %{question: %{id: qid}}}} = :sys.get_state(view.pid)
      send(view.pid, {:fz_question_timeout, qid})
      assert %{answered: false, reason: "timeout", question_id: ^qid} = answered(view, id)
      refute has_element?(view, "#agent-question")

      assert has_element?(
               view,
               "#agent-activity li[data-kind='call'][data-status='error']",
               "timeout"
             )

      first = ask(view, %{"question" => "First?", "options" => options})
      second = ask(view, %{"question" => "Second?", "options" => options})
      assert %{answered: false, reason: "superseded"} = answered(view, first)
      assert has_element?(view, "#agent-question", "Second?")
      view |> element("#question-option-y") |> render_click()
      assert %{answered: true, selected: ["y"]} = answered(view, second)
    end

    test "invalid questions fail immediately with a structured error", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      id = System.unique_integer([:positive])

      render_hook(view, "webmcp:call", %{
        "id" => id,
        "tool" => "ask_human",
        "input" => %{"question" => "Pick", "options" => [%{"id" => "only", "label" => "One"}]}
      })

      assert_push_event(view, "webmcp:result", %{id: ^id, status: "error", error: json})
      assert %{"code" => "INVALID_OPERATION"} = Jason.decode!(json)
      refute has_element?(view, "#agent-question")

      id = System.unique_integer([:positive])
      render_hook(view, "webmcp:call", %{"id" => id, "tool" => "ask_human", "input" => %{}})
      assert_push_event(view, "webmcp:result", %{id: ^id, status: "error"})
    end
  end

  describe "propose_cart" do
    defp propose(view, input) do
      id = System.unique_integer([:positive])
      render_hook(view, "webmcp:call", %{"id" => id, "tool" => "propose_cart", "input" => input})
      refute_push_event(view, "webmcp:result", %{id: ^id})
      id
    end

    defp resolved(view, id) do
      assert_push_event(view, "webmcp:result", %{id: ^id, status: "ok", result: result})
      result
    end

    test "renders a priced, grouped basket with live totals and applies only what the shopper accepts",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"
      black_l = "#{ctx.patagonia.id}_black_l"
      short_32 = "#{ctx.short.id}_black_32"
      sage_xl = "#{ctx.columbia.id}_sage_xl"

      id =
        propose(view, %{
          "title" => "Beach trip — 3 person wardrobe",
          "subtitle" => "Sun protection, swim, dinners",
          "budget" => %{"total" => 150, "by_label" => %{"Dad" => 100}},
          "lines" => [
            %{
              "variant_id" => blue_xl,
              "quantity" => 2,
              "label" => "Dad",
              "reason" => "Quick-dry travel shirt"
            },
            %{
              "variant_id" => black_l,
              "label" => "Dad",
              "reason" => "Trail tee",
              "optional" => true
            },
            %{"variant_id" => short_32, "label" => "Milo", "reason" => "Hiking short"},
            %{"variant_id" => sage_xl, "label" => "Dad", "reason" => "Sold out one"},
            %{"variant_id" => "ghost_variant", "label" => "Mom"}
          ]
        })

      # rendered, blocking, and visible in the banner
      assert has_element?(view, "#agent-proposal", "Beach trip — 3 person wardrobe")

      assert has_element?(
               view,
               "#agent-banner[data-status='waiting']",
               "Review the proposed basket"
             )

      assert has_element?(view, "#agent-proposal [data-label='Dad']", "Quick-dry travel shirt")
      assert has_element?(view, "#agent-proposal [data-label='Milo']", "Hiking short")
      assert has_element?(view, "#proposal-line-1[data-selected='false']")

      assert has_element?(
               view,
               "#proposal-unavailable li[data-variant-id='#{sage_xl}']",
               "out_of_stock"
             )

      assert has_element?(
               view,
               "#proposal-unavailable li[data-variant-id='ghost_variant']",
               "not_found"
             )

      # 2 × $45 + $79 = $169 selected against a $150 budget
      assert has_element?(view, "#agent-proposal[data-selected-total='169'][data-over-by='19']")
      assert has_element?(view, "#proposal-total", "$19.00 over")
      assert has_element?(view, "#agent-proposal [data-label='Dad']", "$90.00 / $100.00")

      state = ok!(view, "get_store_state").state
      assert state.pending_proposal.line_count == 3
      # selection alone vs budget, and the whole cart (empty so far + selection) vs budget
      assert state.pending_proposal.budget == %{
               total: 150.0,
               selection_over_by: 19.0,
               cart_over_by: 19.0
             }

      assert state.pending_proposal.projected_cart_total == 169.0

      # the shopper edits: drops one shirt, ticks the optional tee, unticks the short
      view |> element("#proposal-line-0 [aria-label='Decrease quantity']") |> render_click()
      view |> element("#proposal-tick-1") |> render_click()
      view |> element("#proposal-tick-2") |> render_click()
      assert has_element?(view, "#agent-proposal[data-selected-total='94'][data-over-by='0']")
      assert has_element?(view, "#proposal-total", "within budget")

      # meanwhile the human adds something by hand; it must survive the accept
      ok!(view, "add_to_cart", %{
        "product_id" => ctx.short.id,
        "variant_id" => "#{ctx.short.id}_black_34"
      })

      # the projected cart reading now differs from the selection reading
      assert has_element?(view, "#proposal-projected[data-projected='173']", "$23.00 over budget")

      assert ok!(view, "get_store_state").state.pending_proposal.budget == %{
               total: 150.0,
               selection_over_by: 0.0,
               cart_over_by: 23.0
             }

      view |> element("#proposal-accept") |> render_click()
      result = resolved(view, id)

      assert result.accepted

      assert Enum.map(result.applied, &{&1.variant_id, &1.quantity, &1.label}) == [
               {blue_xl, 1, "Dad"},
               {black_l, 1, "Dad"}
             ]

      assert Enum.map(result.applied, & &1.line_total) == [45.0, 49.0]
      assert result.declined == [short_32]
      assert result.substituted == []
      assert Enum.map(result.unavailable, & &1.reason) == ["out_of_stock", "not_found"]
      assert result.cart.item_count == 3
      assert result.budget == %{total: 150.0, selection_over_by: 0.0, cart_over_by: 23.0}

      cart = ok!(view, "get_cart").cart

      assert Enum.map(cart.items, &{&1.variant_id, &1.source}) |> Enum.sort() ==
               Enum.sort([
                 {blue_xl, "proposal"},
                 {black_l, "proposal"},
                 {"#{ctx.short.id}_black_34", "agent"}
               ])

      refute has_element?(view, "#agent-proposal")
      refute has_element?(view, "#order-confirmation")

      assert has_element?(
               view,
               "#agent-activity li[data-kind='human']",
               "Accepted proposal: 2 lines added"
             )

      assert ok!(view, "get_store_state").state.pending_proposal == nil
    end

    test "alternatives can be swapped, and a sold-out line preselects an offered alternative",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"
      blue_l = "#{ctx.columbia.id}_blue_l"
      sage_xl = "#{ctx.columbia.id}_sage_xl"
      black_xl = "#{ctx.patagonia.id}_black_xl"

      id =
        propose(view, %{
          "lines" => [
            %{
              "variant_id" => blue_xl,
              "label" => "Dad",
              "alternatives" => [%{"variant_id" => blue_l, "reason" => "same shirt, size L"}]
            },
            %{
              "variant_id" => sage_xl,
              "label" => "Dad",
              "alternatives" => [%{"variant_id" => black_xl, "reason" => "same size, in stock"}]
            }
          ]
        })

      assert has_element?(view, "#proposal-line-1[data-variant-id='#{black_xl}']", "sold out")
      view |> element("#proposal-line-0 [phx-value-variant_id='#{blue_l}']") |> render_click()
      assert has_element?(view, "#proposal-line-0[data-variant-id='#{blue_l}']")

      view |> element("#proposal-accept") |> render_click()
      result = resolved(view, id)

      assert Enum.sort(result.substituted) ==
               Enum.sort([
                 %{proposed: blue_xl, chosen: blue_l},
                 %{proposed: sage_xl, chosen: black_xl}
               ])

      assert Enum.map(result.applied, & &1.variant_id) == [blue_l, black_xl]
    end

    test "replace mode clears the cart only on accept; reject changes nothing", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      blue_xl = "#{ctx.columbia.id}_blue_xl"
      short_32 = "#{ctx.short.id}_black_32"

      ok!(view, "add_to_cart", %{"product_id" => ctx.short.id, "variant_id" => short_32})

      id = propose(view, %{"mode" => "replace", "lines" => [%{"variant_id" => blue_xl}]})
      assert ok!(view, "get_cart").cart.item_count == 1
      view |> element("#proposal-reject") |> render_click()
      assert %{accepted: false, reason: "rejected", cart: %{item_count: 1}} = resolved(view, id)
      assert has_element?(view, "#agent-activity li[data-kind='human']", "Rejected")

      id = propose(view, %{"mode" => "replace", "lines" => [%{"variant_id" => blue_xl}]})
      view |> element("#proposal-accept") |> render_click()
      result = resolved(view, id)
      assert result.cart.item_count == 1
      assert [%{variant_id: ^blue_xl}] = ok!(view, "get_cart").cart.items
    end

    test "timeout and supersession resolve as not accepted; a question supersedes a proposal",
         ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")
      lines = [%{"variant_id" => "#{ctx.columbia.id}_blue_xl"}]

      id = propose(view, %{"lines" => lines, "timeout_ms" => 5000})
      %{socket: %{assigns: %{proposal: %{id: pid}}}} = :sys.get_state(view.pid)
      send(view.pid, {:fz_proposal_timeout, pid})
      assert %{accepted: false, reason: "timeout", proposal_id: ^pid} = resolved(view, id)
      refute has_element?(view, "#agent-proposal")

      first = propose(view, %{"lines" => lines})
      second = propose(view, %{"lines" => lines})
      assert %{accepted: false, reason: "superseded"} = resolved(view, first)

      qid = System.unique_integer([:positive])

      render_hook(view, "webmcp:call", %{
        "id" => qid,
        "tool" => "ask_human",
        "input" => %{"question" => "Skip it?"}
      })

      assert %{accepted: false, reason: "superseded"} = resolved(view, second)
      assert has_element?(view, "#agent-question")
      refute has_element?(view, "#agent-proposal")
    end

    test "invalid proposals fail immediately and never touch the cart", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/")

      for input <- [
            %{},
            %{"lines" => []},
            %{"lines" => [%{"variant_id" => "nope"}]},
            %{"lines" => [%{"variant_id" => "#{ctx.columbia.id}_blue_xl"}], "mode" => "merge"}
          ] do
        id = System.unique_integer([:positive])

        render_hook(view, "webmcp:call", %{"id" => id, "tool" => "propose_cart", "input" => input})

        assert_push_event(view, "webmcp:result", %{id: ^id, status: "error", error: json})
        assert %{"code" => "INVALID_OPERATION"} = Jason.decode!(json)
      end

      refute has_element?(view, "#agent-proposal")
      assert ok!(view, "get_cart").cart.item_count == 0
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
