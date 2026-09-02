defmodule FitzyoWeb.StoreLive.State do
  @moduledoc """
  The one canonical application state (AGENTS.md §14) and the operations
  that change it:

      filters · results · selected product · selected variant · comparison · cart
      · agent annotations ("Fits Dad", recommendations) · agent plan

  Both the human UI (`FitzyoWeb.StoreLive` events) and the agent
  (`FitzyoWeb.StoreLive.AgentTools`) go through these functions, so there is
  never a separate "agent state". Everything here takes and returns the
  socket; nothing renders.
  """

  import Phoenix.Component, only: [assign: 2, update: 3]
  import Phoenix.LiveView

  require Ash.Query

  alias Fitzyo.Catalog
  alias Fitzyo.Catalog.Facets
  alias Fitzyo.Commerce
  alias FitzyoWeb.StoreComponents
  alias FitzyoWeb.StoreLive.{Filters, Members}

  use Phoenix.VerifiedRoutes,
    endpoint: FitzyoWeb.Endpoint,
    router: FitzyoWeb.Router,
    statics: FitzyoWeb.static_paths()

  @variant_query Ash.Query.sort(Catalog.Variant, position: :asc)
  @product_load [:category, :available, :size_guide_entries, variants: @variant_query]
  @results_load [:available, variants: @variant_query]
  @cart_load [:item_count, :subtotal, items: [:line_total, variant: [:available, :product]]]
  @activity_limit 60
  @idle_after_ms Application.compile_env(:fitzyo, :agent_idle_ms, 6_000)

  @idle_agent %{status: :idle, message: nil, progress: nil, explicit?: false, tick: 0}

  @type activity_entry :: %{call: String.t(), result: String.t(), status: :ok | :error | :warning}

  # ---------------------------------------------------------------- setup

  @doc "Assigns the initial state for a session's cart."
  def initial(socket, cart_id) do
    Commerce.ensure_cart!(cart_id)

    socket
    |> assign(
      cart_id: cart_id,
      facets: Facets.all(),
      filters: %Filters{},
      filter_origins: %{},
      removed_by_human: [],
      filter_actor: :human,
      excluded_by: %{},
      members: [],
      member_fits: %{},
      lookbook: nil,
      sizes: [],
      results_count: 0,
      product: nil,
      selected_color: nil,
      selected_size: nil,
      comparison: [],
      annotations: %{},
      plan: nil,
      activity: [],
      agent: @idle_agent,
      agent_connected: false
    )
    |> stream_configure(:products, dom_id: &"product-#{&1.id}")
    |> stream(:products, [])
    |> load_cart()
  end

  # ---------------------------------------------------------------- filters & results

  @doc """
  Stores the filters and the category-dependent size facet, and records who
  set each constraint. The actor is whoever triggered the patch
  (`patch_filters/3`); a URL visit or back button counts as the human.

  Every constraint keeps its origin (`:agent` or `:human`) until it is
  removed. When the human removes an agent constraint it is remembered in
  `removed_by_human`, and an agent re-applying it, or clearing a human one,
  is written to the feed as such, so the shopper's corrections are visible
  to both sides.
  """
  def put_filters(socket, %Filters{} = filters) do
    actor = socket.assigns[:filter_actor] || :human
    old_keys = socket.assigns.filters |> Filters.chips() |> Enum.map(&Filters.chip_key/1)
    new_chips = Filters.chips(filters)
    new_keys = Enum.map(new_chips, &Filters.chip_key/1)
    origins = socket.assigns[:filter_origins] || %{}

    added = new_keys -- old_keys
    removed = old_keys -- new_keys

    next_origins =
      origins
      |> Map.drop(removed)
      |> Map.merge(Map.new(added, &{&1, actor}))

    socket
    |> assign(
      filters: filters,
      sizes: Facets.sizes_for_category(filters.category),
      filter_origins: next_origins,
      filter_actor: :human
    )
    |> note_filter_changes(actor, origins, added, removed)
  end

  defp note_filter_changes(socket, :human, origins, _added, removed) do
    overridden = Enum.filter(removed, &(origins[&1] == :agent))

    socket
    |> update(:removed_by_human, &Enum.uniq(&1 ++ overridden))
    |> then(fn socket ->
      Enum.reduce(overridden, socket, fn key, socket ->
        log_human(socket, "Removed the agent's #{describe_key(key)} constraint")
      end)
    end)
  end

  defp note_filter_changes(socket, :agent, origins, added, removed) do
    reapplied = Enum.filter(added, &(&1 in socket.assigns.removed_by_human))
    cleared = Enum.filter(removed, &(origins[&1] == :human))

    socket =
      Enum.reduce(reapplied, socket, fn key, socket ->
        log_activity(
          socket,
          "filter #{describe_key(key)}",
          "re-applied a constraint you removed earlier",
          :warning
        )
      end)

    Enum.reduce(cleared, socket, fn key, socket ->
      log_activity(
        socket,
        "filter #{describe_key(key)}",
        "cleared a constraint you set",
        :warning
      )
    end)
  end

  defp describe_key({facet, value}), do: "#{Filters.facet_label(facet)}: #{value}"

  @doc "Runs the catalog query for `filters`."
  def fetch_results(%Filters{} = filters) do
    filters
    |> Filters.to_browse_args()
    |> Catalog.filter_products!(load: @results_load)
  end

  @doc """
  Refreshes the results stream from the current filters and counts, per
  active facet, how many more products would show if only that facet were
  dropped (`excluded_by`).
  """
  def load_results(socket) do
    filters = socket.assigns.filters
    products = fetch_results(filters)
    count = length(products)

    excluded_by =
      filters
      |> Filters.chip_groups()
      |> Map.new(fn %{facet: facet} ->
        without = filters |> Filters.clear_facet(facet) |> fetch_results() |> length()
        {facet, max(without - count, 0)}
      end)

    socket
    |> assign(
      results_count: count,
      excluded_by: excluded_by,
      member_fits: Members.fits_map(socket.assigns.members, products)
    )
    |> stream(:products, products, reset: true)
  end

  @doc """
  Navigates to the results page with `filters` applied; `handle_params`
  reloads. `actor` says who is changing the constraints and is consumed by
  `put_filters/2`.
  """
  def patch_filters(socket, %Filters{} = filters, actor \\ :human) do
    socket
    |> assign(filter_actor: actor)
    |> push_patch(to: index_path(filters))
  end

  @doc "Per-facet origin for `get_store_state`: agent, human, or mixed."
  def filter_origin_summary(origins) do
    origins
    |> Enum.group_by(fn {{facet, _}, _} -> facet end, fn {_, actor} -> actor end)
    |> Map.new(fn {facet, actors} ->
      {facet,
       case Enum.uniq(actors) do
         [one] -> to_string(one)
         _ -> "mixed"
       end}
    end)
  end

  def index_path(%Filters{} = filters), do: ~p"/?#{Filters.to_params(filters)}"

  @doc "The order review page; filters ride along so leaving it restores the same results."
  def review_path(%Filters{} = filters), do: ~p"/checkout?#{Filters.to_params(filters)}"

  def product_path(id, %Filters{} = filters),
    do: ~p"/products/#{id}?#{Filters.to_params(filters)}"

  def results_heading(facets, %Filters{} = filters) do
    cond do
      filters.category -> category_name(facets, filters.category)
      filters.query -> ~s(Results for "#{filters.query}")
      true -> "All Products"
    end
  end

  def category_name(facets, id) do
    case Enum.find(facets.categories, &(&1.id == id)) do
      nil -> id
      category -> category.name
    end
  end

  # ---------------------------------------------------------------- product & variant

  @doc "Loads a product with everything the detail page and tools need."
  def fetch_product(id), do: Catalog.get_product(id, load: @product_load)

  @doc """
  Makes `id` the selected product. Keeps the current color/size selection when
  the product offers it. Returns `{:error, socket}` (with a flash and a patch
  back to results) when the product does not exist.
  """
  def load_product(socket, id) do
    case fetch_product(id) do
      {:ok, product} ->
        {color, size} = initial_selection(socket, product)

        {:ok,
         socket
         |> assign(product: product, page_title: product.name)
         |> select_variant(color, size)}

      {:error, _} ->
        {:error,
         socket
         |> put_flash(:error, "We couldn't find that product.")
         |> push_patch(to: index_path(socket.assigns.filters))}
    end
  end

  # The variant a product page should open on, in priority order:
  #   1. an agent annotation for this product that names an in-stock variant
  #   2. the shopper's existing cart line for this product
  #   3. the color/size carried over from the previous page
  #   4. (handled by select_variant) the first color and size with stock
  # The page is the human-approval surface, so what the recommendation says
  # and what "Add to Cart" adds must be the same thing.
  defp initial_selection(socket, product) do
    annotated =
      socket.assigns.annotations
      |> annotations_for(product.id)
      |> Enum.map(& &1.variant_id)

    in_cart =
      socket.assigns.cart.items
      |> Enum.filter(&(&1.variant.product_id == product.id))
      |> Enum.map(& &1.variant_id)

    (annotated ++ in_cart)
    |> Enum.reject(&is_nil/1)
    |> Enum.find_value(fn variant_id ->
      case Enum.find(product.variants, &(&1.id == variant_id and &1.inventory_quantity > 0)) do
        nil -> nil
        variant -> {variant.color, variant.size}
      end
    end)
    |> Kernel.||({socket.assigns.selected_color, socket.assigns.selected_size})
  end

  @doc """
  Sets the selected color and size for the current product, falling back to
  the first color with stock and the first in-stock size of that color.
  A chosen size that exists but is sold out is kept, so the UI can say so.
  """
  def select_variant(%{assigns: %{product: nil}} = socket, _color, _size), do: socket

  def select_variant(socket, color, size) do
    product = socket.assigns.product
    colors = StoreComponents.color_options(product)

    color =
      cond do
        Enum.any?(colors, &(&1.name == color)) -> color
        first = Enum.find(colors, & &1.available) -> first.name
        first = List.first(colors) -> first.name
        true -> nil
      end

    variants = StoreComponents.variants_in_color(product, color)

    size =
      cond do
        Enum.any?(variants, &(&1.size == size)) -> size
        first = Enum.find(variants, &(&1.inventory_quantity > 0)) -> first.size
        true -> nil
      end

    assign(socket, selected_color: color, selected_size: size)
  end

  @doc "The variant matching the current color/size selection, if any."
  def selected_variant(%{assigns: %{product: nil}}), do: nil

  def selected_variant(%{assigns: assigns}) do
    Enum.find(
      assigns.product.variants,
      &(&1.color == assigns.selected_color and &1.size == assigns.selected_size)
    )
  end

  # ---------------------------------------------------------------- comparison

  @doc "Replaces the comparison set with the given products (max 4, in order)."
  def compare(socket, products) when is_list(products) do
    assign(socket, comparison: Enum.take(products, 4))
  end

  def add_to_comparison(socket, product) do
    comparison = Enum.reject(socket.assigns.comparison, &(&1.id == product.id))
    compare(socket, comparison ++ [product])
  end

  def remove_from_comparison(socket, product_id) do
    assign(socket, comparison: Enum.reject(socket.assigns.comparison, &(&1.id == product_id)))
  end

  def clear_comparison(socket), do: assign(socket, comparison: [])

  # ---------------------------------------------------------------- agent annotations

  @doc """
  Records which variants an agent found to fit someone it calls `label`
  ("Dad"). The retailer never learns who that is; it only shows the label.
  Replaces any earlier matches for the same label.
  """
  def put_matches(socket, label, matches) when is_binary(label) and is_list(matches) do
    fresh =
      Enum.map(matches, fn m ->
        %{
          label: label,
          product_id: m.product_id,
          variant_id: m.variant_id,
          source: :match,
          match: m.match,
          score: m.match_score,
          reason: nil
        }
      end)

    socket
    |> update_annotations(fn annotations ->
      annotations
      |> drop_annotations(&(&1.label == label and &1.source == :match))
      |> add_annotations(fresh)
    end)
  end

  @doc "Attaches an agent-written recommendation to a product for `label`."
  def recommend(socket, label, product_id, variant_id, reason) do
    annotation = %{
      label: label,
      product_id: product_id,
      variant_id: variant_id,
      source: :recommendation,
      match: %{},
      score: nil,
      reason: reason
    }

    update_annotations(socket, fn annotations ->
      annotations
      |> drop_annotations(
        &(&1.label == label and &1.product_id == product_id and &1.source == :recommendation)
      )
      |> add_annotations([annotation])
    end)
  end

  @doc "Human override: forget everything the agent attached under `label`."
  def clear_label(socket, label) do
    update_annotations(socket, &drop_annotations(&1, fn a -> a.label == label end))
  end

  @doc "Human override: remove one product's annotations for `label`."
  def remove_annotation(socket, product_id, label) do
    update_annotations(
      socket,
      &drop_annotations(&1, fn a -> a.label == label and a.product_id == product_id end)
    )
  end

  @doc """
  Agent-side lifecycle for its own annotations (`clear_annotations`): drops
  every annotation matching the given label, product, and source, any of
  which may be nil to mean "any". Returns the socket and how many went.
  """
  def clear_annotations(socket, label, product_id, source) do
    before = socket.assigns.annotations |> Map.values() |> List.flatten() |> length()

    socket =
      update_annotations(
        socket,
        &drop_annotations(&1, fn a ->
          (is_nil(label) or a.label == label) and
            (is_nil(product_id) or a.product_id == product_id) and
            (is_nil(source) or a.source == source)
        end)
      )

    after_count = socket.assigns.annotations |> Map.values() |> List.flatten() |> length()
    {socket, before - after_count}
  end

  @doc "Product ids annotated under `label`, in first-seen order."
  def products_for_label(annotations, label) do
    annotations
    |> Enum.filter(fn {_id, entries} -> Enum.any?(entries, &(&1.label == label)) end)
    |> Enum.map(fn {id, _} -> id end)
  end

  @doc "Annotations for one product, or `[]`."
  def annotations_for(annotations, product_id), do: Map.get(annotations, product_id, [])

  @doc "The labels in use with how many products each covers, alphabetically."
  def labels(annotations) do
    annotations
    |> Map.values()
    |> List.flatten()
    |> Enum.group_by(& &1.label)
    |> Enum.map(fn {label, entries} ->
      %{
        label: label,
        product_count: entries |> Enum.map(& &1.product_id) |> Enum.uniq() |> length()
      }
    end)
    |> Enum.sort_by(& &1.label)
  end

  defp update_annotations(socket, fun) do
    socket
    |> assign(annotations: fun.(socket.assigns.annotations))
    |> refresh_listing()
  end

  defp drop_annotations(annotations, pred) do
    annotations
    |> Enum.map(fn {product_id, entries} -> {product_id, Enum.reject(entries, pred)} end)
    |> Enum.reject(fn {_id, entries} -> entries == [] end)
    |> Map.new()
  end

  defp add_annotations(annotations, entries) do
    Enum.reduce(entries, annotations, fn entry, acc ->
      Map.update(acc, entry.product_id, [entry], &(&1 ++ [entry]))
    end)
  end

  # Product cards live in a stream, so they only pick up new annotations when
  # re-inserted. Cheap enough for a demo catalog.
  defp refresh_listing(%{assigns: %{product: nil}} = socket), do: load_results(socket)
  defp refresh_listing(socket), do: socket

  # ---------------------------------------------------------------- party members

  @doc "Registers or replaces a member and re-badges the listing."
  def put_member(socket, member) do
    with {:ok, members} <- Members.put(socket.assigns.members, member) do
      {:ok, socket |> assign(members: members) |> refresh_listing()}
    end
  end

  @doc "Forgets a member: their badges, the agent's matches for them, and their budget."
  def remove_member(socket, label) do
    case Members.find(socket.assigns.members, label) do
      nil ->
        {:error, :not_found}

      member ->
        {:ok,
         socket
         |> assign(members: Enum.reject(socket.assigns.members, &(&1.label == member.label)))
         |> clear_label(member.label)}
    end
  end

  # ---------------------------------------------------------------- agent plan

  @doc "Stores the agent-presented shopping plan (title, groups of needs) for the human to read."
  def put_plan(socket, plan) when is_map(plan), do: assign(socket, plan: plan)

  def clear_plan(socket), do: assign(socket, plan: nil)

  # ---------------------------------------------------------------- cart

  @doc "Reloads the session cart with totals and item details."
  def load_cart(socket) do
    cart = Commerce.get_cart!(socket.assigns.cart_id, load: @cart_load)
    socket = assign(socket, cart: cart)

    # While the human is reviewing, any change to the cart (theirs or the
    # agent's) invalidates the approval nonce: a hold must never approve
    # something other than what was on screen.
    case socket.assigns[:review_fingerprint] do
      nil -> socket
      fingerprint -> mark_review_stale(socket, fingerprint != cart_fingerprint(cart))
    end
  end

  defp mark_review_stale(socket, false), do: socket

  defp mark_review_stale(socket, true),
    do: assign(socket, checkout_nonce: nil, review_stale: true)

  @doc "What the human is approving: every line's variant and quantity."
  def cart_fingerprint(cart) do
    cart.items |> Enum.map(&{&1.variant_id, &1.quantity}) |> Enum.sort()
  end

  # ---------------------------------------------------------------- agent activity & focus

  @doc """
  Appends a tool call to the agent activity feed (chronological) and marks the
  agent as working until it goes quiet for a few seconds.
  """
  def log_activity(socket, call, result, status \\ :ok) do
    entry = %{kind: :call, call: call, result: result, status: status, at: DateTime.utc_now()}

    socket
    |> append_activity(entry)
    |> mark_working()
  end

  @doc """
  Records a human action in the same feed as tool calls, so the audit trail
  shows who did what. Does not mark the agent as working.
  """
  def log_human(socket, text, status \\ :ok) when is_binary(text) do
    append_activity(socket, %{kind: :human, text: text, status: status, at: DateTime.utc_now()})
  end

  @doc """
  Streams an agent thought into the feed. With `append?` the text continues
  the previous thought instead of starting a new one, so an agent can stream
  a sentence in chunks.
  """
  def log_thought(socket, text, append? \\ false) when is_binary(text) do
    activity = socket.assigns.activity

    case {append?, List.last(activity)} do
      {true, %{kind: :thought} = last} ->
        updated = %{last | text: last.text <> text, at: DateTime.utc_now()}
        assign(socket, activity: List.replace_at(activity, -1, updated))

      _ ->
        append_activity(socket, %{kind: :thought, text: text, at: DateTime.utc_now()})
    end
    |> mark_working()
  end

  @doc """
  The agent's explicit status for the banner: `:working`, `:done`, or `:idle`,
  with an optional message and `%{done, total}` progress. Explicit status
  sticks until the agent changes it; auto-idle only applies to implicit work.
  """
  def set_agent_status(socket, status, message, progress)
      when status in [:working, :done, :idle] do
    agent = socket.assigns.agent

    assign(socket,
      agent: %{
        agent
        | status: status,
          message: message,
          progress: progress,
          explicit?: status != :idle,
          tick: agent.tick + 1
      },
      agent_connected: true
    )
  end

  @doc "Human dismissed the banner."
  def dismiss_agent_status(socket), do: set_agent_status(socket, :idle, nil, nil)

  @doc "Idle timer fired; go idle if nothing happened since it was scheduled."
  def agent_idle(socket, tick) do
    agent = socket.assigns.agent

    if agent.tick == tick and not agent.explicit? do
      assign(socket, agent: %{agent | status: :idle, message: nil, progress: nil})
    else
      socket
    end
  end

  @doc "The most recent thought, for the banner."
  def latest_thought(activity) do
    activity
    |> Enum.reverse()
    |> Enum.find_value(fn
      %{kind: :thought, text: t} -> t
      _ -> nil
    end)
  end

  defp append_activity(socket, entry) do
    update(socket, :activity, fn activity -> Enum.take(activity ++ [entry], -@activity_limit) end)
  end

  defp mark_working(socket) do
    agent = socket.assigns.agent
    tick = agent.tick + 1
    Process.send_after(self(), {:fz_agent_idle, tick}, @idle_after_ms)

    status = if agent.explicit?, do: agent.status, else: :working

    assign(socket,
      agent: %{agent | status: status, tick: tick},
      agent_connected: true
    )
  end

  @doc "Asks the browser to scroll a DOM element into view and highlight it briefly."
  def focus_element(socket, dom_id) when is_binary(dom_id) do
    push_event(socket, "fz:focus", %{id: dom_id})
  end
end
