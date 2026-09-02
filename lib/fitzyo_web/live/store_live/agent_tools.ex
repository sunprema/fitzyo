defmodule FitzyoWeb.StoreLive.AgentTools do
  @moduledoc """
  The retailer's WebMCP tool surface (WEBMCP_SPEC §7), exposed from the
  storefront LiveView through `AshWebMcp.ViewTools`.

  Every tool is a semantic commerce operation, never a DOM action. Tools
  that change what the human sees (search, filter, compare, focus, cart)
  do so through `FitzyoWeb.StoreLive.State`, so the UI updates in the same
  render as the agent's reply. Tools receive only task-relevant constraints;
  the shopper's identity and profile never reach this module.

  Failures are structured (§30): the error string an agent receives is a JSON
  object with a `code` such as `VARIANT_UNAVAILABLE` and a `message`, plus the
  ids involved. A failed call never leaves state partially modified (§31).
  """

  @behaviour AshWebMcp.ViewTools

  alias Fitzyo.Catalog
  alias Fitzyo.Catalog.Types
  alias Fitzyo.Commerce
  alias FitzyoWeb.StoreLive.{Filters, Presenter, State}

  @store %{
    id: "fitzyo-retail-demo",
    name: "FitzYo Retail",
    currency: "USD",
    country: "US",
    description:
      "Demo apparel retailer for families: shirts, shorts, pants, dresses, swimwear, shoes, and accessories."
  }

  @capabilities ~w(product_search product_filtering variant_selection fit_matching comparison cart ui_focus)

  @filter_ids ~w(category gender size color brand price fit activity)

  @read_only %{readOnlyHint: true, destructive?: false}
  @state_change %{readOnlyHint: false, destructive?: false, idempotentHint: true}

  # ---------------------------------------------------------------- specs

  @impl true
  def tools do
    [
      %{
        name: "get_store_info",
        description:
          "Basic facts about this retailer: name, currency, catalog size, and which capabilities are available. Read-only.",
        input_schema: object(%{}),
        annotations: @read_only
      },
      %{
        name: "get_categories",
        description: "List product categories with stable ids and product counts. Read-only.",
        input_schema: object(%{}),
        annotations: @read_only
      },
      %{
        name: "search_products",
        description:
          "Full-text search over product names, brands, and descriptions. Sets the store's search box and, unless keep_filters is true, clears the structured filters so the search starts fresh. Returns matching products.",
        input_schema:
          object(
            %{
              query: %{type: "string", description: "Words to look for, e.g. \"linen shirt\""},
              keep_filters: %{
                type: "boolean",
                default: false,
                description: "Search within the currently active filters instead of clearing them"
              },
              limit: %{
                type: "integer",
                minimum: 1,
                maximum: 50,
                description: "Max results to return (default 20)"
              }
            },
            ["query"]
          ),
        annotations: @state_change
      },
      %{
        name: "filter_products",
        description:
          "Apply structured filters to the catalog and show them in the store UI. Replaces the active filters: omit a key to clear it; pass {} to clear all. AND between facets, OR within one; size and color must be in stock together on the same variant.",
        input_schema:
          object(%{
            category: %{type: "string", description: "Category id from get_categories"},
            brand: string_array("Brand names"),
            size: string_array("Size labels such as XL, 34, 34x32, 9, 6Y"),
            color: string_array("Color names such as blue, navy, black"),
            fit: %{type: "array", items: %{type: "string", enum: fit_values()}},
            activity: string_array("Activities such as travel, beach, hiking, dinner"),
            gender: %{type: "string", enum: gender_values()},
            price_min: %{type: "number", minimum: 0},
            price_max: %{type: "number", minimum: 0},
            limit: %{type: "integer", minimum: 1, maximum: 50}
          }),
        annotations: @state_change
      },
      %{
        name: "get_product",
        description:
          "Complete details for one product including fit information, colors, and sizes. Read-only.",
        input_schema: object(%{product_id: %{type: "string"}}, ["product_id"]),
        annotations: @read_only
      },
      %{
        name: "get_variants",
        description:
          "Every purchasable size/color variant of a product with price and availability. Read-only.",
        input_schema: object(%{product_id: %{type: "string"}}, ["product_id"]),
        annotations: @read_only
      },
      %{
        name: "get_size_guide",
        description:
          "Structured size guide (chest, waist, hip, neck, sleeve, inseam ranges per size) for a product. Read-only.",
        input_schema: object(%{product_id: %{type: "string"}}, ["product_id"]),
        annotations: @read_only
      },
      %{
        name: "find_matching_variants",
        description:
          "Find in-stock variants satisfying shopping constraints derived from the shopper's private context (size, colors, brands, fit, activities, budget). Send constraints only, never the profile. When nothing satisfies every constraint, returns the closest matches with a per-constraint match map and score. Also narrows the store view to the hard constraints.",
        input_schema:
          object(%{
            product_id: %{type: "string", description: "Restrict to one product"},
            category: %{type: "string"},
            size: %{type: "string", description: "The size that fits, e.g. XL or 36"},
            color: string_array("Preferred colors (any of)"),
            brand: string_array("Preferred brands (any of)"),
            fit: %{type: "string", enum: fit_values()},
            activity: string_array("Intended activities (any of)"),
            gender: %{type: "string", enum: gender_values()},
            price_max: %{type: "number", minimum: 0},
            label: %{
              type: "string",
              description:
                "Who these constraints are for, as the shopper says it (e.g. \"Dad\"). When given, matching products are badged \"Fits Dad\" in the store UI. Not stored beyond this session."
            },
            limit: %{type: "integer", minimum: 1, maximum: 50}
          }),
        annotations: @state_change
      },
      %{
        name: "compare_products",
        description:
          "Compare 2–4 products side by side and show the comparison to the human. Returns price, fit, colors, sizes, and activities for each.",
        input_schema:
          object(
            %{product_ids: %{type: "array", items: %{type: "string"}, minItems: 1, maxItems: 4}},
            ["product_ids"]
          ),
        annotations: @state_change
      },
      %{
        name: "get_cart",
        description: "The current cart with every line item and totals. Read-only.",
        input_schema: object(%{}),
        annotations: @read_only
      },
      %{
        name: "add_to_cart",
        description:
          "Add a purchasable variant to the cart. Adding the same variant again increases its quantity. Optional label (e.g. \"Dad\") tags the line for the human. Never checks out.",
        input_schema:
          object(
            %{
              product_id: %{type: "string"},
              variant_id: %{type: "string"},
              quantity: %{type: "integer", minimum: 1, default: 1},
              label: %{
                type: "string",
                description: "Who this item is for, as the shopper would say it"
              }
            },
            ["product_id", "variant_id"]
          ),
        annotations: %{readOnlyHint: false, destructive?: false, idempotentHint: false}
      },
      %{
        name: "remove_from_cart",
        description: "Remove a variant's line from the cart.",
        input_schema:
          object(%{product_id: %{type: "string"}, variant_id: %{type: "string"}}, ["variant_id"]),
        annotations: @state_change
      },
      %{
        name: "update_cart_item",
        description: "Set the quantity of a cart line (1 or more) and optionally its label.",
        input_schema:
          object(
            %{
              product_id: %{type: "string"},
              variant_id: %{type: "string"},
              quantity: %{type: "integer", minimum: 1},
              label: %{type: "string"}
            },
            ["variant_id", "quantity"]
          ),
        annotations: @state_change
      },
      %{
        name: "clear_cart",
        description:
          "Remove every line from the cart, e.g. to start over after the shopper changes the plan. Prefer remove_from_cart for single lines.",
        input_schema: object(%{}),
        annotations: %{readOnlyHint: false, destructive?: false, idempotentHint: true}
      },
      %{
        name: "recommend_product",
        description:
          "Show the human an agent-written recommendation on a product (\"✦ FitzYo Recommendation — Dad: matches his size, preferred color and casual style\"). Presentation only; nothing is added to the cart.",
        input_schema:
          object(
            %{
              product_id: %{type: "string"},
              variant_id: %{
                type: "string",
                description: "The specific size/color being recommended"
              },
              label: %{type: "string", description: "Who it is for, e.g. \"Mom\""},
              reason: %{type: "string", description: "One or two sentences the shopper will read"}
            },
            ["product_id", "label", "reason"]
          ),
        annotations: @state_change
      },
      %{
        name: "present_plan",
        description:
          "Show the human your shopping plan in the store's agent panel: a title and groups (one per person) of needs with a status each. Replaces any earlier plan. Presentation only.",
        input_schema:
          object(
            %{
              title: %{type: "string", description: "e.g. \"Hawaii — 7 day wardrobe\""},
              subtitle: %{
                type: "string",
                description: "e.g. \"Beach, hiking, dinners · budget $600\""
              },
              groups: %{
                type: "array",
                minItems: 1,
                items:
                  object(
                    %{
                      label: %{type: "string", description: "Person or group, e.g. \"Dad\""},
                      items: %{
                        type: "array",
                        items:
                          object(
                            %{
                              text: %{
                                type: "string",
                                description: "e.g. \"2 lightweight shirts\""
                              },
                              status: %{type: "string", enum: ~w(have need added skipped)},
                              product_id: %{type: "string"}
                            },
                            ["text", "status"]
                          )
                      }
                    },
                    ["label", "items"]
                  )
              }
            },
            ["title", "groups"]
          ),
        annotations: @state_change
      },
      %{
        name: "agent_update",
        description:
          "Tell the human what you are doing, like a coding agent narrating its work. status drives a banner at the top of the page (working / done / idle), message is the banner headline, thought streams into the activity feed (pass append: true to continue the previous thought in chunks), progress is {done, total}. Cheap; call it before and after each step.",
        input_schema:
          object(%{
            status: %{type: "string", enum: ~w(working done idle)},
            message: %{type: "string", description: "e.g. \"Finding Milo's rash guard\""},
            thought: %{
              type: "string",
              description: "What you are reasoning about, in the shopper's words"
            },
            append: %{
              type: "boolean",
              default: false,
              description: "Continue the previous thought"
            },
            progress:
              object(
                %{done: %{type: "integer", minimum: 0}, total: %{type: "integer", minimum: 1}},
                ["done", "total"]
              )
          }),
        annotations: @state_change
      },
      FitzyoWeb.StoreLive.Questions.spec(),
      FitzyoWeb.StoreLive.Proposals.spec(),
      %{
        name: "get_store_state",
        description:
          "What the human currently sees: search, filters, selected product/variant, comparison, cart totals, your annotations and plan. Call it after a pause to notice human changes; human actions always win over stale assumptions. Read-only.",
        input_schema: object(%{}),
        annotations: @read_only
      },
      %{
        name: "focus_product",
        description:
          "Open a product in the human's view and highlight it, optionally preselecting a variant. No commerce side effects.",
        input_schema:
          object(
            %{product_id: %{type: "string"}, variant_id: %{type: "string"}},
            ["product_id"]
          ),
        annotations: @state_change
      },
      %{
        name: "focus_filter",
        description:
          "Draw the human's attention to one filter section in the sidebar. No commerce side effects.",
        input_schema: object(%{filter_id: %{type: "string", enum: @filter_ids}}, ["filter_id"]),
        annotations: @state_change
      }
    ]
  end

  # ---------------------------------------------------------------- dispatch

  @impl true
  def handle_tool(name, input, socket) do
    input = input || %{}

    case run(name, input, socket) do
      {:ok, result, socket} ->
        {:ok, result, socket}

      {:ok, result} ->
        {:ok, result, State.log_activity(socket, call_label(name, input), "ok")}

      {:error, %{code: _} = error} ->
        send(self(), {:fz_activity, call_label(name, input), error.message, :error})
        {:error, Jason.encode!(Map.put(error, :success, false))}
    end
  end

  # ---------------------------------------------------------------- read tools

  defp run("get_store_info", _input, socket) do
    facets = socket.assigns.facets
    product_count = facets.categories |> Enum.map(& &1.product_count) |> Enum.sum()

    result = %{
      store: Map.put(@store, :product_count, product_count),
      capabilities: @capabilities,
      categories: Enum.map(facets.categories, & &1.id),
      brands: facets.brands,
      colors: Enum.map(facets.colors, & &1.name),
      fits: facets.fits,
      activities: facets.activities
    }

    {:ok, result, log(socket, "get_store_info()", "#{@store.name} — #{product_count} products")}
  end

  defp run("get_categories", _input, socket) do
    categories =
      Enum.map(socket.assigns.facets.categories, fn c ->
        %{id: c.id, name: c.name, description: c.description, product_count: c.product_count}
      end)

    {:ok, %{categories: categories},
     log(socket, "get_categories()", Enum.map_join(categories, ", ", & &1.id))}
  end

  defp run("get_product", %{"product_id" => id}, socket) do
    with {:ok, product} <- fetch_product(id) do
      {:ok, %{product: Presenter.product(product)},
       log(socket, "get_product(\"#{id}\")", product.name)}
    end
  end

  defp run("get_variants", %{"product_id" => id}, socket) do
    with {:ok, product} <- fetch_product(id) do
      variants = Enum.map(product.variants, &Presenter.variant/1)
      in_stock = Enum.count(variants, & &1.available)

      {:ok, %{product_id: id, variants: variants},
       log(
         socket,
         "get_variants(\"#{id}\")",
         "#{length(variants)} variants, #{in_stock} in stock"
       )}
    end
  end

  defp run("get_size_guide", %{"product_id" => id}, socket) do
    with {:ok, product} <- fetch_product(id) do
      {:ok, Presenter.size_guide(product, product.size_guide_entries),
       log(socket, "get_size_guide(\"#{id}\")", "#{length(product.size_guide_entries)} sizes")}
    end
  end

  defp run("get_cart", _input, socket) do
    socket = State.load_cart(socket)
    cart = socket.assigns.cart

    {:ok, %{cart: Presenter.cart(cart)},
     log(socket, "get_cart()", "#{cart.item_count} items, #{money(cart.subtotal)}")}
  end

  # ---------------------------------------------------------------- search & filter

  defp run("search_products", %{"query" => query} = input, socket) when is_binary(query) do
    base = if input["keep_filters"] == true, do: socket.assigns.filters, else: %Filters{}
    filters = Filters.put_query(base, query)
    products = State.fetch_results(filters)

    result = %{
      query: query,
      filters_applied: Filters.to_params(filters),
      results: summaries(products, input),
      total: length(products)
    }

    socket =
      socket
      |> State.patch_filters(filters)
      |> log("search_products(\"#{query}\")", "#{length(products)} products found")

    {:ok, result, socket}
  end

  defp run("filter_products", input, socket) do
    with {:ok, filters} <- build_filters(input, socket.assigns.filters.query, socket) do
      products = State.fetch_results(filters)

      result = %{
        filters_applied: Filters.to_params(filters),
        results: summaries(products, input),
        total: length(products)
      }

      socket =
        socket
        |> State.patch_filters(filters)
        |> log(call_label("filter_products", input), "#{length(products)} products found")

      {:ok, result, socket}
    end
  end

  defp run("find_matching_variants", input, socket) do
    with :ok <- validate_category(input["category"], socket),
         :ok <- validate_enum(input["fit"], fit_values(), "fit"),
         :ok <- validate_enum(input["gender"], gender_values(), "gender"),
         {:ok, _} <- validate_product_id(input["product_id"]) do
      {strict?, variants} = match_variants(input)

      matches =
        variants
        |> Enum.map(&match_entry(&1, input, strict?))
        |> Enum.sort_by(& &1.match_score, :desc)

      label = blank_to_nil(input["label"])

      result = %{
        strict: strict?,
        label: label,
        constraints: constraint_map(input),
        matches: Enum.take(matches, limit(input)),
        total: length(matches),
        truncated: length(matches) > limit(input)
      }

      summary =
        if strict?,
          do: "#{length(matches)} variants match every constraint",
          else: "no exact match; #{length(matches)} closest variants"

      socket =
        socket
        |> apply_match_filters(input, strict?)
        |> label_matches(label, matches, strict?)
        |> log(call_label("find_matching_variants", input), summary)

      {:ok, result, socket}
    end
  end

  defp run(
         "recommend_product",
         %{"product_id" => id, "label" => label, "reason" => reason} = input,
         socket
       )
       when is_binary(label) and is_binary(reason) do
    with {:ok, product} <- fetch_product(id),
         {:ok, variant} <- optional_variant(input["variant_id"], product) do
      socket =
        socket
        |> State.recommend(label, product.id, variant && variant.id, reason)
        |> State.focus_element("product-#{product.id}")
        |> log(call_label("recommend_product", input), "#{label}: #{product.name}")

      {:ok,
       %{success: true, product_id: product.id, variant_id: variant && variant.id, label: label},
       socket}
    end
  end

  defp run("present_plan", %{"title" => title, "groups" => groups} = input, socket)
       when is_binary(title) and is_list(groups) do
    with {:ok, plan} <- build_plan(title, input["subtitle"], groups) do
      needs = plan.groups |> Enum.flat_map(& &1.items) |> Enum.count(&(&1.status == "need"))

      socket =
        socket
        |> State.put_plan(plan)
        |> State.focus_element("agent-plan")
        |> log(
          ~s|present_plan("#{title}")|,
          "#{length(plan.groups)} people, #{needs} items still needed"
        )

      {:ok, %{success: true, title: title, groups: length(plan.groups)}, socket}
    end
  end

  defp run("agent_update", input, socket) do
    with {:ok, status} <- optional_enum(input["status"], ~w(working done idle), "status"),
         {:ok, progress} <- optional_progress(input["progress"]) do
      socket =
        socket
        |> maybe_thought(input["thought"], input["append"] == true)
        |> maybe_status(status, input["message"], progress)

      {:ok, %{success: true, agent: %{status: to_string(socket.assigns.agent.status)}}, socket}
    end
  end

  # ask_human is intercepted by FitzyoWeb.StoreLive before the library
  # dispatches here; this clause only exists so a misrouted call fails clearly.
  defp run(name, _input, _socket) when name in ["ask_human", "propose_cart"] do
    error("INVALID_OPERATION", "#{name} must be called through the WebMCP transport")
  end

  defp run("get_store_state", _input, socket) do
    socket = State.load_cart(socket)
    state = Presenter.state(socket.assigns, State.selected_variant(socket))

    {:ok, %{state: state},
     log(
       socket,
       "get_store_state()",
       "#{state.view} view, #{state.results_count} results, cart #{state.cart.item_count}"
     )}
  end

  defp run("compare_products", %{"product_ids" => ids}, socket) when is_list(ids) do
    ids = ids |> Enum.filter(&is_binary/1) |> Enum.uniq() |> Enum.take(4)

    with {:ok, products} <- fetch_products(ids) do
      socket =
        socket
        |> State.compare(products)
        |> State.focus_element("comparison")
        |> log(
          call_label("compare_products", %{"product_ids" => ids}),
          "comparing #{length(products)} products"
        )

      {:ok, %{products: Enum.map(products, &comparison_entry/1)}, socket}
    end
  end

  # ---------------------------------------------------------------- cart writes

  defp run("add_to_cart", %{"variant_id" => variant_id} = input, socket) do
    quantity = Map.get(input, "quantity", 1)
    label = input["label"]

    with {:ok, variant} <- fetch_variant(variant_id, input["product_id"]),
         :ok <- validate_quantity(quantity),
         {:ok, _item} <-
           commerce(
             Commerce.add_to_cart(socket.assigns.cart_id, variant.id, %{
               quantity: quantity,
               label: label,
               source: :agent
             }),
             variant
           ) do
      socket = State.load_cart(socket)
      cart = socket.assigns.cart

      result = %{
        success: true,
        product_id: variant.product_id,
        variant_id: variant.id,
        quantity_added: quantity,
        cart: Presenter.cart_totals(cart)
      }

      socket =
        socket
        |> State.focus_element("cart-button")
        |> log(
          call_label("add_to_cart", input),
          "#{variant.product.name} (#{variant.color}/#{variant.size}) — cart now #{cart.item_count} items"
        )

      {:ok, result, socket}
    end
  end

  defp run("remove_from_cart", %{"variant_id" => variant_id} = input, socket) do
    with {:ok, item} <- fetch_cart_item(socket, variant_id),
         :ok <- Commerce.remove_from_cart(item) do
      socket = State.load_cart(socket)
      cart = socket.assigns.cart

      {:ok, %{success: true, variant_id: variant_id, cart: Presenter.cart_totals(cart)},
       log(socket, call_label("remove_from_cart", input), "cart now #{cart.item_count} items")}
    end
  end

  defp run(
         "update_cart_item",
         %{"variant_id" => variant_id, "quantity" => quantity} = input,
         socket
       ) do
    with :ok <- validate_quantity(quantity),
         {:ok, item} <- fetch_cart_item(socket, variant_id),
         :ok <- validate_stock(item.variant, quantity),
         {:ok, _} <-
           commerce(
             Commerce.set_cart_item_quantity(item, quantity, %{
               label: input["label"] || item.label
             }),
             item.variant
           ) do
      socket = State.load_cart(socket)
      cart = socket.assigns.cart

      {:ok,
       %{
         success: true,
         variant_id: variant_id,
         quantity: quantity,
         cart: Presenter.cart_totals(cart)
       }, log(socket, call_label("update_cart_item", input), "cart now #{cart.item_count} items")}
    end
  end

  defp run("clear_cart", _input, socket) do
    case Commerce.clear_cart(socket.assigns.cart_id) do
      :ok ->
        socket = State.load_cart(socket)

        {:ok, %{success: true, cart: Presenter.cart_totals(socket.assigns.cart)},
         log(socket, "clear_cart()", "cart emptied")}

      {:error, ash_error} ->
        error("INVALID_OPERATION", Fitzyo.Errors.message(ash_error))
    end
  end

  # ---------------------------------------------------------------- UI focus

  defp run("focus_product", %{"product_id" => id} = input, socket) do
    with {:ok, product} <- fetch_product(id),
         {:ok, variant} <- optional_variant(input["variant_id"], product) do
      socket =
        socket
        |> preselect(variant)
        |> Phoenix.LiveView.push_patch(to: State.product_path(id, socket.assigns.filters))
        |> State.focus_element("product-#{id}")
        |> log(call_label("focus_product", input), "showing #{product.name}")

      {:ok, %{success: true, product_id: id, variant_id: variant && variant.id}, socket}
    end
  end

  defp run("focus_filter", %{"filter_id" => filter_id}, socket) do
    if filter_id in @filter_ids do
      dom_id = if filter_id == "price", do: "filter-price", else: "filter-#{plural(filter_id)}"

      {:ok, %{success: true, filter_id: filter_id},
       socket
       |> State.focus_element(dom_id)
       |> log("focus_filter(\"#{filter_id}\")", "highlighted")}
    else
      error(
        "INVALID_FILTER",
        "Unknown filter #{inspect(filter_id)}; use one of #{Enum.join(@filter_ids, ", ")}"
      )
    end
  end

  defp run(name, _input, _socket) do
    error("INVALID_OPERATION", "#{name} requires the fields listed in its input schema")
  end

  # ---------------------------------------------------------------- matching

  # Hard constraints must hold; if the soft ones (color, brand, fit, activity)
  # exclude everything, fall back to hard-only matches and score the rest.
  defp match_variants(input) do
    strict =
      Catalog.find_matching_variants!(match_args(input, :all), load: [product: [:name, :brand]])

    if strict != [] do
      {true, strict}
    else
      {false,
       Catalog.find_matching_variants!(match_args(input, :hard), load: [product: [:name, :brand]])}
    end
  end

  defp match_args(input, mode) do
    hard = %{
      product_id: input["product_id"],
      category: input["category"],
      size: input["size"],
      gender: input["gender"],
      price_max: decimal(input["price_max"])
    }

    soft = %{
      colors: list(input["color"]),
      brands: list(input["brand"]),
      fit: input["fit"],
      activities: list(input["activity"])
    }

    case mode do
      :all -> Map.merge(hard, soft)
      :hard -> hard
    end
  end

  defp match_entry(variant, input, strict?) do
    product = variant.product

    checks =
      [
        {:size, input["size"], fn -> same?(variant.size, input["size"]) end},
        {:color, list(input["color"]), fn -> any_same?(variant.color, input["color"]) end},
        {:brand, list(input["brand"]), fn -> any_same?(product.brand, input["brand"]) end},
        {:fit, input["fit"], fn -> same?(to_string(product.fit), input["fit"]) end},
        {:activity, list(input["activity"]),
         fn -> Enum.any?(product.activities, &any_same?(&1, input["activity"])) end},
        {:price, input["price_max"],
         fn -> Decimal.compare(variant.price, decimal(input["price_max"])) != :gt end}
      ]
      |> Enum.reject(fn {_k, given, _} -> given in [nil, "", []] end)

    match = Map.new(checks, fn {key, _given, check} -> {key, check.()} end)
    matched = Enum.count(match, fn {_k, ok?} -> ok? end)
    score = if map_size(match) == 0, do: 1.0, else: Float.round(matched / map_size(match), 2)

    %{
      product_id: product.id,
      variant_id: variant.id,
      name: product.name,
      brand: product.brand,
      size: variant.size,
      color: variant.color,
      price: Presenter.number(variant.price),
      available: variant.inventory_quantity > 0,
      match: match,
      match_score: if(strict?, do: 1.0, else: score)
    }
  end

  # Narrow the human's view to what the agent is looking for: the hard
  # constraints always, the soft ones only when they produced a strict match.
  defp apply_match_filters(socket, input, strict?) do
    base = %Filters{
      query: socket.assigns.filters.query,
      category: input["category"],
      gender: input["gender"] && String.downcase(input["gender"]),
      sizes: list(input["size"]),
      price_max: decimal(input["price_max"])
    }

    filters =
      if strict? do
        %{
          base
          | colors: list(input["color"]),
            brands: list(input["brand"]),
            fits: list(input["fit"]),
            activities: list(input["activity"])
        }
      else
        base
      end

    if input["product_id"] do
      socket
    else
      State.patch_filters(socket, filters)
    end
  end

  defp maybe_thought(socket, nil, _append?), do: socket
  defp maybe_thought(socket, "", _append?), do: socket

  defp maybe_thought(socket, text, append?) when is_binary(text),
    do: State.log_thought(socket, text, append?)

  defp maybe_thought(socket, _other, _append?), do: socket

  defp maybe_status(socket, nil, nil, nil), do: socket

  defp maybe_status(socket, nil, message, progress),
    do: State.set_agent_status(socket, :working, message, progress)

  defp maybe_status(socket, status, message, progress),
    do: State.set_agent_status(socket, String.to_existing_atom(status), message, progress)

  defp optional_enum(nil, _values, _field), do: {:ok, nil}

  defp optional_enum(value, values, field) do
    case validate_enum(value, values, field) do
      :ok -> {:ok, String.downcase(value)}
      err -> err
    end
  end

  defp optional_progress(nil), do: {:ok, nil}

  defp optional_progress(%{"done" => done, "total" => total})
       when is_integer(done) and is_integer(total) and total >= 1 and done >= 0,
       do: {:ok, %{done: min(done, total), total: total}}

  defp optional_progress(_),
    do: error("INVALID_OPERATION", "progress must be {done, total} integers")

  defp label_matches(socket, nil, _matches, _strict?), do: socket
  defp label_matches(socket, _label, _matches, false), do: socket
  defp label_matches(socket, label, matches, true), do: State.put_matches(socket, label, matches)

  defp build_plan(title, subtitle, groups) do
    groups =
      Enum.map(groups, fn
        %{"label" => label, "items" => items} when is_binary(label) and is_list(items) ->
          %{
            label: label,
            items:
              Enum.map(items, fn
                %{"text" => text, "status" => status} = item
                when is_binary(text) and status in ~w(have need added skipped) ->
                  %{text: text, status: status, product_id: item["product_id"]}

                _ ->
                  :invalid
              end)
          }

        _ ->
          :invalid
      end)

    if groups == [] or Enum.any?(groups, &(&1 == :invalid or :invalid in &1.items)) do
      error(
        "INVALID_OPERATION",
        "present_plan groups need a label and items with text and a status of have, need, added, or skipped"
      )
    else
      {:ok, %{title: title, subtitle: subtitle, groups: groups}}
    end
  end

  defp constraint_map(input) do
    input
    |> Map.take(~w(product_id category size color brand fit activity gender price_max label))
    |> Map.reject(fn {_k, v} -> v in [nil, "", []] end)
  end

  # ---------------------------------------------------------------- filters

  defp build_filters(input, query, socket) do
    with :ok <- validate_category(input["category"], socket),
         :ok <- validate_enum_list(input["fit"], fit_values(), "fit"),
         :ok <- validate_enum(input["gender"], gender_values(), "gender"),
         :ok <- validate_price(input["price_min"], "price_min"),
         :ok <- validate_price(input["price_max"], "price_max") do
      {:ok,
       %Filters{
         query: query,
         category: blank_to_nil(input["category"]),
         gender: input["gender"] && String.downcase(input["gender"]),
         sizes: list(input["size"]),
         colors: input["color"] |> list() |> Enum.map(&String.downcase/1),
         brands: list(input["brand"]),
         fits: list(input["fit"]),
         activities: input["activity"] |> list() |> Enum.map(&String.downcase/1),
         price_min: decimal(input["price_min"]),
         price_max: decimal(input["price_max"])
       }}
    end
  end

  defp validate_category(nil, _socket), do: :ok
  defp validate_category("", _socket), do: :ok

  defp validate_category(category, socket) do
    ids = Enum.map(socket.assigns.facets.categories, & &1.id)

    if category in ids,
      do: :ok,
      else:
        error(
          "INVALID_CATEGORY",
          "Unknown category #{inspect(category)}; use one of #{Enum.join(ids, ", ")}"
        )
  end

  defp validate_enum(nil, _values, _field), do: :ok
  defp validate_enum("", _values, _field), do: :ok

  defp validate_enum(value, values, field) when is_binary(value) do
    if String.downcase(value) in values,
      do: :ok,
      else: error("INVALID_FILTER", "#{field} must be one of #{Enum.join(values, ", ")}")
  end

  defp validate_enum(_value, values, field),
    do: error("INVALID_FILTER", "#{field} must be one of #{Enum.join(values, ", ")}")

  defp validate_enum_list(nil, _values, _field), do: :ok

  defp validate_enum_list(values, allowed, field) when is_list(values) do
    Enum.reduce_while(values, :ok, fn value, :ok ->
      case validate_enum(value, allowed, field) do
        :ok -> {:cont, :ok}
        err -> {:halt, err}
      end
    end)
  end

  defp validate_enum_list(_values, _allowed, field),
    do: error("INVALID_FILTER", "#{field} must be an array")

  defp validate_price(nil, _field), do: :ok
  defp validate_price(value, _field) when is_number(value) and value >= 0, do: :ok

  defp validate_price(_value, field),
    do: error("INVALID_FILTER", "#{field} must be a non-negative number")

  defp validate_quantity(quantity) when is_integer(quantity) and quantity >= 1, do: :ok

  defp validate_quantity(_),
    do: error("INVALID_QUANTITY", "quantity must be an integer of 1 or more")

  defp validate_stock(%{inventory_quantity: stock, id: id}, quantity) when quantity > stock,
    do: error("VARIANT_UNAVAILABLE", "Only #{stock} of #{id} in stock", variant_id: id)

  defp validate_stock(_variant, _quantity), do: :ok

  defp validate_product_id(nil), do: {:ok, nil}
  defp validate_product_id(id), do: fetch_product(id)

  # ---------------------------------------------------------------- lookups

  defp fetch_product(id) when is_binary(id) do
    case State.fetch_product(id) do
      {:ok, product} -> {:ok, product}
      {:error, _} -> error("PRODUCT_NOT_FOUND", "No product #{inspect(id)}", product_id: id)
    end
  end

  defp fetch_product(id),
    do: error("PRODUCT_NOT_FOUND", "product_id must be a string", product_id: id)

  defp fetch_products(ids) do
    Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, acc} ->
      case fetch_product(id) do
        {:ok, product} -> {:cont, {:ok, acc ++ [product]}}
        err -> {:halt, err}
      end
    end)
  end

  defp fetch_variant(variant_id, product_id) when is_binary(variant_id) do
    case Catalog.get_variant(variant_id, load: [:available, product: [:name]]) do
      {:ok, %{product_id: pid} = variant} when is_nil(product_id) or pid == product_id ->
        {:ok, variant}

      {:ok, %{product_id: pid}} ->
        error("VARIANT_NOT_FOUND", "Variant #{variant_id} belongs to #{pid}, not #{product_id}",
          product_id: product_id,
          variant_id: variant_id
        )

      {:error, _} ->
        error("VARIANT_NOT_FOUND", "No variant #{inspect(variant_id)}",
          product_id: product_id,
          variant_id: variant_id
        )
    end
  end

  defp fetch_variant(variant_id, product_id),
    do:
      error("VARIANT_NOT_FOUND", "variant_id must be a string",
        product_id: product_id,
        variant_id: variant_id
      )

  defp optional_variant(nil, _product), do: {:ok, nil}

  defp optional_variant(variant_id, product) do
    case Enum.find(product.variants, &(&1.id == variant_id)) do
      nil ->
        error("VARIANT_NOT_FOUND", "#{product.id} has no variant #{inspect(variant_id)}",
          product_id: product.id,
          variant_id: variant_id
        )

      variant ->
        {:ok, variant}
    end
  end

  defp fetch_cart_item(socket, variant_id) do
    socket = State.load_cart(socket)

    case Enum.find(socket.assigns.cart.items, &(&1.variant_id == variant_id)) do
      nil ->
        error("CART_ITEM_NOT_FOUND", "Cart has no line for variant #{inspect(variant_id)}",
          variant_id: variant_id
        )

      item ->
        {:ok, item}
    end
  end

  defp preselect(socket, nil), do: socket

  defp preselect(socket, variant),
    do:
      Phoenix.Component.assign(socket, selected_color: variant.color, selected_size: variant.size)

  # Translate coded Commerce errors into structured tool errors.
  defp commerce({:ok, value}, _variant), do: {:ok, value}

  defp commerce({:error, ash_error}, variant) do
    message = Fitzyo.Errors.message(ash_error)

    code =
      case Fitzyo.Errors.code(ash_error) do
        "INSUFFICIENT_STOCK" -> "VARIANT_UNAVAILABLE"
        nil -> "INVALID_OPERATION"
        code -> code
      end

    error(code, message, product_id: variant.product_id, variant_id: variant.id)
  end

  # ---------------------------------------------------------------- helpers

  defp summaries(products, input) do
    products |> Enum.take(limit(input)) |> Enum.map(&Presenter.product_summary/1)
  end

  defp comparison_entry(product) do
    product
    |> Presenter.product_summary()
    |> Map.merge(%{
      material: product.material,
      stretch: to_string(product.stretch),
      description: product.description
    })
  end

  defp limit(input) do
    case input["limit"] do
      n when is_integer(n) and n >= 1 -> min(n, 50)
      _ -> 20
    end
  end

  defp log(socket, call, result), do: State.log_activity(socket, call, result)

  defp error(code, message, extra \\ []) do
    {:error, Map.merge(%{code: code, message: message}, Map.new(extra))}
  end

  defp money(%Decimal{} = amount), do: "$" <> Decimal.to_string(Decimal.round(amount, 2), :normal)

  defp call_label(name, input) when map_size(input) == 0, do: "#{name}()"

  defp call_label(name, input) do
    args =
      input
      |> Enum.reject(fn {_k, v} -> v in [nil, "", []] end)
      |> Enum.map_join(", ", fn {k, v} -> "#{k}: #{Jason.encode!(v)}" end)

    "#{name}({#{args}})"
  end

  defp same?(a, b) when is_binary(a) and is_binary(b),
    do: String.downcase(a) == String.downcase(b)

  defp same?(_, _), do: false

  defp any_same?(value, candidates), do: Enum.any?(list(candidates), &same?(value, &1))

  defp list(nil), do: []
  defp list(value) when is_binary(value), do: [value]
  defp list(values) when is_list(values), do: Enum.filter(values, &is_binary/1)
  defp list(_), do: []

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp decimal(nil), do: nil
  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp decimal(value) when is_binary(value), do: Decimal.new(value)

  defp plural("category"), do: "categories"
  defp plural("gender"), do: "genders"
  defp plural("activity"), do: "activities"
  defp plural(id), do: id <> "s"

  defp fit_values, do: Enum.map(Types.Fit.values(), &Atom.to_string/1)
  defp gender_values, do: Enum.map(Types.Gender.values(), &Atom.to_string/1)

  defp object(properties, required \\ []) do
    schema = %{type: "object", properties: properties, additionalProperties: false}
    if required == [], do: schema, else: Map.put(schema, :required, required)
  end

  defp string_array(description),
    do: %{type: "array", items: %{type: "string"}, description: description}
end
