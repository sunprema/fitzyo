defmodule FitzyoWeb.StoreLive do
  @moduledoc """
  The FitzYo storefront: one LiveView that owns the whole application state
  a human and an agent share (AGENTS.md §14):

      filters · results · selected product · selected variant · comparison · cart

  Search and filter state lives in the URL (`FitzyoWeb.StoreLive.Filters`),
  the selected product is the `/products/:id` route, and the cart is keyed by
  the session's cart id. All state changes go through
  `FitzyoWeb.StoreLive.State`, whether they come from a human click here or
  from an agent calling a WebMCP tool in `FitzyoWeb.StoreLive.AgentTools`, so
  whatever the agent does is immediately visible to the human and vice versa.
  """

  use FitzyoWeb, :live_view

  # Must be attached before AshWebMcp's own hook: `ask_human` calls are held
  # open here instead of being answered synchronously by the library.
  on_mount {__MODULE__, :intercept_questions}

  use AshWebMcp.LiveView,
    resources: [],
    view_tools: FitzyoWeb.StoreLive.AgentTools,
    activity_messages: true

  alias Fitzyo.Commerce
  alias FitzyoWeb.Plugs.CartSession
  alias FitzyoWeb.StoreLive.{AgentTools, Filters, Proposals, Questions, State}

  def on_mount(:intercept_questions, _params, _session, socket) do
    {:cont,
     socket
     |> attach_hook(:fz_ask_human, :handle_event, &Questions.intercept/3)
     |> attach_hook(:fz_propose_cart, :handle_event, &Proposals.intercept/3)}
  end

  # ---------------------------------------------------------------- lifecycle

  @impl true
  def mount(_params, session, socket) do
    cart_id = session[CartSession.session_key()] || Ash.UUID.generate()

    {:ok,
     socket
     |> State.initial(cart_id)
     |> assign(
       size_guide_open: false,
       cart_open: false,
       agent_panel_open: true,
       agent_transport: nil,
       tool_count: length(AgentTools.tools()),
       order_confirmation: nil,
       checkout_review: false,
       checkout_nonce: nil,
       question: nil,
       proposal: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    socket = State.put_filters(socket, Filters.from_params(params))

    case socket.assigns.live_action do
      :index ->
        heading = State.results_heading(socket.assigns.facets, socket.assigns.filters)

        {:noreply,
         socket
         |> assign(product: nil, page_title: heading)
         |> State.load_results()}

      :show ->
        case State.load_product(socket, params["id"]) do
          {:ok, socket} -> {:noreply, assign(socket, size_guide_open: false)}
          {:error, socket} -> {:noreply, socket}
        end
    end
  end

  # ---------------------------------------------------------------- events: search & filters

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    patch_filters(socket, Filters.put_query(socket.assigns.filters, query))
  end

  def handle_event("toggle_filter", %{"facet" => facet, "value" => value}, socket) do
    patch_filters(socket, Filters.toggle(socket.assigns.filters, facet, value))
  end

  def handle_event("set_category", %{"value" => category}, socket) do
    patch_filters(socket, Filters.toggle_category(socket.assigns.filters, category))
  end

  def handle_event("set_gender", %{"value" => gender}, socket) do
    patch_filters(socket, Filters.toggle_gender(socket.assigns.filters, gender))
  end

  def handle_event("set_price", params, socket) do
    patch_filters(socket, Filters.put_price(socket.assigns.filters, params["min"], params["max"]))
  end

  def handle_event("remove_filter", %{"facet" => facet} = params, socket) do
    patch_filters(socket, Filters.remove(socket.assigns.filters, facet, params["value"]))
  end

  def handle_event("clear_filters", _params, socket) do
    patch_filters(socket, Filters.clear(socket.assigns.filters))
  end

  # ---------------------------------------------------------------- events: product detail

  def handle_event("select_color", %{"value" => color}, socket) do
    {:noreply, State.select_variant(socket, color, socket.assigns.selected_size)}
  end

  def handle_event("select_size", %{"value" => size}, socket) do
    {:noreply, State.select_variant(socket, socket.assigns.selected_color, size)}
  end

  def handle_event("toggle_size_guide", _params, socket) do
    {:noreply, update(socket, :size_guide_open, &(!&1))}
  end

  def handle_event("add_to_cart", %{"variant_id" => variant_id}, socket) do
    case Commerce.add_to_cart(socket.assigns.cart_id, variant_id) do
      {:ok, _item} ->
        {:noreply, socket |> State.load_cart() |> assign(cart_open: true)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  # ---------------------------------------------------------------- events: comparison

  def handle_event("compare_add", %{"product_id" => id}, socket) do
    case State.fetch_product(id) do
      {:ok, product} -> {:noreply, State.add_to_comparison(socket, product)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "We couldn't find that product.")}
    end
  end

  def handle_event("compare_remove", %{"product_id" => id}, socket) do
    {:noreply, State.remove_from_comparison(socket, id)}
  end

  def handle_event("compare_clear", _params, socket) do
    {:noreply, State.clear_comparison(socket)}
  end

  # ---------------------------------------------------------------- events: agent annotations (human override)

  def handle_event("clear_label", %{"label" => label}, socket) do
    {:noreply, State.clear_label(socket, label)}
  end

  def handle_event("remove_annotation", %{"product_id" => id, "label" => label}, socket) do
    {:noreply, State.remove_annotation(socket, id, label)}
  end

  def handle_event("dismiss_plan", _params, socket) do
    {:noreply, State.clear_plan(socket)}
  end

  # ---------------------------------------------------------------- events: cart

  def handle_event("toggle_cart", _params, socket) do
    {:noreply, update(socket, :cart_open, &(!&1))}
  end

  def handle_event("cart_increment", %{"id" => item_id}, socket) do
    with {:ok, item} <- Commerce.get_cart_item(item_id),
         {:ok, _} <- Commerce.add_to_cart(socket.assigns.cart_id, item.variant_id) do
      {:noreply, State.load_cart(socket)}
    else
      {:error, error} -> {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  def handle_event("cart_decrement", %{"id" => item_id}, socket) do
    with {:ok, item} <- Commerce.get_cart_item(item_id),
         {:ok, _} <- decrement_or_remove(item) do
      {:noreply, State.load_cart(socket)}
    else
      {:error, error} -> {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  def handle_event("remove_cart_item", %{"id" => item_id}, socket) do
    with {:ok, item} <- Commerce.get_cart_item(item_id),
         :ok <- Commerce.remove_from_cart(item) do
      {:noreply, State.load_cart(socket)}
    else
      {:error, error} -> {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  def handle_event("clear_cart", _params, socket) do
    case Commerce.clear_cart(socket.assigns.cart_id) do
      :ok -> {:noreply, State.load_cart(socket)}
      {:error, error} -> {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  # Checkout is the one action no agent may take. It is three things at once:
  #   1. a review step (the order summary modal),
  #   2. an approval gesture: press-and-hold on the confirm button, sent by a
  #      JS hook only for trusted pointer/keyboard input together with a
  #      single-use nonce issued when the review opened,
  #   3. an audit entry in the activity feed naming the human as approver.
  # A synthetic `.click()` has no gesture, no trusted event, and no nonce.
  def handle_event("checkout", _params, %{assigns: %{cart: %{items: []}}} = socket) do
    {:noreply, socket}
  end

  def handle_event("checkout", _params, socket) do
    nonce = Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)

    {:noreply,
     socket
     |> assign(checkout_review: true, checkout_nonce: nonce)
     |> push_event("fz:checkout_nonce", %{nonce: nonce})
     |> State.log_human(
       "Opened order review (#{items_label(socket.assigns.cart.item_count)}, #{format_price(socket.assigns.cart.subtotal)})"
     )}
  end

  def handle_event("cancel_checkout", _params, socket) do
    {:noreply,
     socket
     |> assign(checkout_review: false, checkout_nonce: nil)
     |> State.log_human("Went back to the cart without ordering")}
  end

  def handle_event("confirm_checkout", params, socket) do
    with :ok <- verify_approval(params, socket),
         {:ok, confirmation} <- Commerce.checkout_cart(socket.assigns.cart_id) do
      {:noreply,
       socket
       |> assign(
         order_confirmation:
           Map.put(confirmation, :approved_by, "a human press-and-hold on this device"),
         cart_open: false,
         checkout_review: false,
         checkout_nonce: nil
       )
       |> State.log_human(
         "Approved and placed order #{confirmation.order_number} · #{items_label(confirmation.item_count)} · #{format_price(confirmation.subtotal)}"
       )
       |> State.load_cart()}
    else
      {:error, :not_approved} ->
        {:noreply,
         socket
         |> put_flash(:error, "Checkout needs a press-and-hold from you; nothing was ordered.")
         |> State.log_human("Checkout blocked: no human approval signal", :error)}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, Fitzyo.Errors.message(error))}
    end
  end

  def handle_event("close_confirmation", _params, socket) do
    {:noreply, assign(socket, order_confirmation: nil)}
  end

  # ---------------------------------------------------------------- events: agent

  def handle_event("toggle_agent_panel", _params, socket) do
    {:noreply, update(socket, :agent_panel_open, &(!&1))}
  end

  # Pushed by the WebMcp hook wrapper in app.js whenever the transport changes.
  def handle_event("webmcp:transport", %{"native" => native?}, socket) do
    transport = if native?, do: :native, else: :bridge

    {:noreply,
     socket
     |> assign(agent_transport: transport)
     |> assign(agent_connected: socket.assigns.agent_connected or native?)}
  end

  # ---------------------------------------------------------------- info

  def handle_event("dismiss_agent_status", _params, socket) do
    {:noreply, State.dismiss_agent_status(socket)}
  end

  # ---------------------------------------------------------------- events: agent questions

  def handle_event("answer_question", %{"option_id" => id}, socket) do
    {:noreply, Questions.answer(socket, [id], nil)}
  end

  def handle_event("answer_question", params, socket) do
    selected = List.wrap(params["selected"]) |> Enum.filter(&is_binary/1)
    {:noreply, Questions.answer(socket, selected, params["free_text"])}
  end

  def handle_event("dismiss_question", _params, socket) do
    {:noreply, Questions.dismiss(socket)}
  end

  # ---------------------------------------------------------------- events: agent proposals

  def handle_event("proposal_toggle", %{"key" => key}, socket) do
    {:noreply, Proposals.toggle_line(socket, String.to_integer(key))}
  end

  def handle_event("proposal_qty", %{"key" => key, "delta" => delta}, socket) do
    key = String.to_integer(key)
    line = Enum.find(socket.assigns.proposal.lines, &(&1.key == key))
    {:noreply, Proposals.set_quantity(socket, key, line.quantity + String.to_integer(delta))}
  end

  def handle_event("proposal_swap", %{"key" => key, "variant_id" => variant_id}, socket) do
    {:noreply, Proposals.swap(socket, String.to_integer(key), variant_id)}
  end

  def handle_event("proposal_accept", _params, socket) do
    {:noreply, Proposals.accept(socket)}
  end

  def handle_event("proposal_reject", _params, socket) do
    {:noreply, Proposals.reject(socket)}
  end

  @impl true
  def handle_info({:fz_proposal_timeout, proposal_id}, socket) do
    {:noreply, Proposals.timeout(socket, proposal_id)}
  end

  def handle_info({:fz_question_timeout, question_id}, socket) do
    {:noreply, Questions.timeout(socket, question_id)}
  end

  def handle_info({:fz_agent_idle, tick}, socket) do
    {:noreply, State.agent_idle(socket, tick)}
  end

  def handle_info({:fz_activity, call, result, status}, socket) do
    {:noreply, State.log_activity(socket, call, result, status)}
  end

  # Successful calls log themselves with a summary inside AgentTools; failures
  # are logged via :fz_activity above. Nothing left to do here.
  def handle_info({AshWebMcp.LiveView, :activity, _info}, socket), do: {:noreply, socket}

  # ---------------------------------------------------------------- helpers

  @hold_ms 600

  defp items_label(1), do: "1 item"
  defp items_label(count), do: "#{count} items"

  defp verify_approval(params, socket) do
    nonce = socket.assigns.checkout_nonce
    held = params["held_ms"]

    if is_binary(nonce) and params["nonce"] == nonce and params["trusted"] == true and
         is_integer(held) and held >= @hold_ms do
      :ok
    else
      {:error, :not_approved}
    end
  end

  defp patch_filters(socket, filters), do: {:noreply, State.patch_filters(socket, filters)}

  defp decrement_or_remove(%{quantity: 1} = item), do: {:ok, Commerce.remove_from_cart!(item)}

  defp decrement_or_remove(item),
    do: Commerce.set_cart_item_quantity(item, item.quantity - 1)

  # Cart lines grouped by the label the shopper's agent attached, labelled
  # groups first, in first-seen order.
  defp cart_groups(items) do
    items
    |> Enum.group_by(& &1.label)
    |> Enum.sort_by(fn {label, items} -> {is_nil(label), hd(items).inserted_at} end)
  end

  defp variant_labels(annotations, variant_id) do
    annotations
    |> Enum.filter(&(&1.variant_id == variant_id))
    |> Enum.map(& &1.label)
    |> Enum.uniq()
  end

  defp chip_label(facets, %{facet: "category", value: id}), do: State.category_name(facets, id)
  defp chip_label(_facets, chip), do: chip.label

  defp product_path(id, filters), do: State.product_path(id, filters)

  defp size_guide_columns(entries) do
    [
      {"Chest", :chest_min, :chest_max},
      {"Waist", :waist_min, :waist_max},
      {"Hip", :hip_min, :hip_max},
      {"Neck", :neck, nil},
      {"Sleeve", :sleeve, nil},
      {"Inseam", :inseam, nil}
    ]
    |> Enum.filter(fn {_label, min, _max} -> Enum.any?(entries, &Map.get(&1, min)) end)
  end

  defp measurement(entry, min, nil), do: number(Map.get(entry, min))

  defp measurement(entry, min, max) do
    case {Map.get(entry, min), Map.get(entry, max)} do
      {nil, nil} -> "—"
      {lo, nil} -> number(lo)
      {lo, hi} -> "#{number(lo)}–#{number(hi)}"
    end
  end

  defp number(nil), do: "—"
  defp number(%Decimal{} = value), do: Decimal.to_string(Decimal.normalize(value), :normal)

  # ---------------------------------------------------------------- render

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        chips: Filters.chips(assigns.filters),
        variant: State.selected_variant(%{assigns: assigns})
      )

    ~H"""
    <Layouts.app flash={@flash}>
      <div id="store" class="flex min-h-screen flex-col" phx-hook="FzFocus">
        <div id="webmcp" phx-hook="WebMcp" phx-update="ignore" hidden></div>
        <.store_header cart={@cart} filters={@filters} agent_connected={@agent_connected} />
        <.agent_banner
          agent={@agent}
          thought={State.latest_thought(@activity)}
          question={@question}
          proposal={@proposal}
        />
        <.selections :if={@cart.items != []} cart={@cart} filters={@filters} />

        <div class="flex flex-1 min-h-0">
          <.filter_rail
            filters={@filters}
            facets={@facets}
            sizes={@sizes}
            labels={State.labels(@annotations)}
          />

          <main class="fz-scroll min-w-0 flex-1 overflow-y-auto px-4 py-5 md:px-6">
            <%= if @product do %>
              <.product_detail
                product={@product}
                filters={@filters}
                selected_color={@selected_color}
                selected_size={@selected_size}
                variant={@variant}
                size_guide_open={@size_guide_open}
                comparing={Enum.any?(@comparison, &(&1.id == @product.id))}
                annotations={State.annotations_for(@annotations, @product.id)}
              />
            <% else %>
              <.comparison :if={@comparison != []} products={@comparison} filters={@filters} />
              <.results
                filters={@filters}
                facets={@facets}
                chips={@chips}
                results_count={@results_count}
                streams={@streams}
                annotations={@annotations}
              />
            <% end %>
          </main>

          <.agent_panel
            open={@agent_panel_open}
            connected={@agent_connected}
            transport={@agent_transport}
            tool_count={@tool_count}
            activity={@activity}
            plan={@plan}
            question={@question}
            proposal={@proposal}
          />
        </div>

        <.cart_drawer :if={@cart_open} cart={@cart} />
        <.checkout_review :if={@checkout_review} cart={@cart} />
        <.order_confirmation :if={@order_confirmation} confirmation={@order_confirmation} />
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------- header

  attr :cart, :map, required: true
  attr :filters, Filters, required: true
  attr :agent_connected, :boolean, required: true

  defp store_header(assigns) do
    ~H"""
    <header
      id="store-header"
      class="sticky top-0 z-20 flex h-[68px] shrink-0 items-center gap-4 border-b border-base-300 bg-base-100 px-4 md:gap-6 md:px-8"
    >
      <.link navigate={~p"/"} class="flex shrink-0 items-center gap-2" aria-label="FitzYo home">
        <span class="flex size-8 items-center justify-center rounded-[10px] bg-primary font-display text-base font-bold text-primary-content">
          Fz
        </span>
        <span class="font-display text-[22px] font-bold text-secondary">FitzYo</span>
      </.link>

      <form
        id="store-search"
        phx-submit="search"
        role="search"
        class="flex h-[42px] max-w-[480px] flex-1 items-center gap-2 rounded-full border border-base-300 bg-mint px-4 dark:bg-base-200"
      >
        <.icon name="hero-magnifying-glass" class="size-4 text-muted" />
        <input
          id="store-search-input"
          type="search"
          name="q"
          value={@filters.query}
          placeholder="Search products..."
          aria-label="Search products"
          autocomplete="off"
          class="min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-faint"
        />
        <button
          type="submit"
          class="rounded-full bg-primary px-4 py-1.5 text-[13px] font-semibold text-primary-content cursor-pointer hover:brightness-95"
        >
          Search
        </button>
      </form>

      <div class="flex-1" />

      <div
        id="agent-status"
        class="hidden shrink-0 items-center gap-2 rounded-full border border-base-300 bg-mint px-3.5 py-1.5 sm:flex dark:bg-base-200"
        title={if @agent_connected, do: "WebMCP-connected agent", else: "No agent connected yet"}
        data-agent-connected={to_string(@agent_connected)}
      >
        <%= if @agent_connected do %>
          <.status_dot />
          <span class="text-xs font-semibold text-secondary">Agent Connected</span>
        <% else %>
          <span class="inline-block size-2 rounded-full bg-faint" />
          <span class="text-xs font-semibold text-muted">Agent Ready</span>
        <% end %>
      </div>

      <button
        id="cart-button"
        type="button"
        phx-click="toggle_cart"
        aria-label={"Open cart, #{@cart.item_count} items"}
        class="relative flex shrink-0 items-center gap-2 rounded-full border border-base-300 bg-base-100 px-4 py-2 text-[13px] font-semibold cursor-pointer hover:border-primary/60"
      >
        <.icon name="hero-shopping-bag" class="size-4" /> Cart
        <span
          :if={@cart.item_count > 0}
          id="cart-count"
          class="absolute -right-1.5 -top-1.5 flex h-[18px] min-w-[18px] items-center justify-center rounded-full bg-accent px-1 text-[11px] font-bold text-accent-content"
        >
          {@cart.item_count}
        </span>
      </button>
    </header>
    """
  end

  # ---------------------------------------------------------------- agent banner

  attr :agent, :map, required: true
  attr :thought, :string, default: nil
  attr :question, :map, default: nil
  attr :proposal, :map, default: nil

  # A blocked agent must never look idle: an open question or proposal
  # overrides the agent's own status with a "waiting for you" state.
  defp agent_banner(assigns) do
    status = if assigns.question || assigns.proposal, do: :waiting, else: assigns.agent.status

    waiting_text =
      cond do
        assigns.question ->
          {"#agent-question", assigns.question.question}

        assigns.proposal ->
          {"#agent-proposal", "Review the proposed basket: #{assigns.proposal.title}"}

        true ->
          nil
      end

    assigns = assign(assigns, status: status, waiting_text: waiting_text)

    ~H"""
    <div
      :if={@status != :idle}
      id="agent-banner"
      role="status"
      aria-live="polite"
      data-status={@status}
      class={[
        "fz-fade sticky top-[68px] z-10 flex items-center gap-3 border-b px-4 py-2 text-[13px] md:px-8",
        case @status do
          :working -> "border-mint-dark bg-mint text-secondary dark:bg-base-300"
          :waiting -> "border-peach-dark bg-peach text-[#4a3b33]"
          _ -> "border-primary/40 bg-primary text-primary-content"
        end
      ]}
    >
      <%= case @status do %>
        <% :working -> %>
          <.status_dot class="size-2.5" />
          <span class="shrink-0 font-bold">Agent is working</span>
        <% :waiting -> %>
          <span class="fz-pulse inline-block size-2.5 rounded-full bg-accent" />
          <span class="shrink-0 font-bold text-error">Waiting for you</span>
          <a
            href={elem(@waiting_text, 0)}
            class="truncate font-semibold underline-offset-2 hover:underline"
          >
            {elem(@waiting_text, 1)}
          </a>
        <% _ -> %>
          <span class="shrink-0 font-bold">✓ Agent finished</span>
      <% end %>
      <span
        :if={@agent.message && @status != :waiting}
        id="agent-banner-message"
        class="truncate font-semibold"
      >
        {@agent.message}
      </span>
      <span
        :if={@agent.status == :working && is_binary(@thought) && is_nil(@agent.message)}
        class="truncate italic opacity-80"
      >
        {@thought}
      </span>
      <span class="flex-1" />
      <div :if={@agent.progress} id="agent-progress" class="flex shrink-0 items-center gap-2">
        <span class="text-xs font-semibold tabular-nums">
          {@agent.progress.done} / {@agent.progress.total}
        </span>
        <div class="h-1.5 w-28 overflow-hidden rounded-full bg-base-100/60">
          <div
            class="h-full rounded-full bg-primary transition-[width] duration-500"
            style={"width: #{round(@agent.progress.done / @agent.progress.total * 100)}%"}
          />
        </div>
      </div>
      <button
        :if={@agent.status == :done}
        type="button"
        phx-click="dismiss_agent_status"
        aria-label="Dismiss"
        class="shrink-0 text-lg leading-none cursor-pointer"
      >
        ×
      </button>
    </div>
    """
  end

  # ---------------------------------------------------------------- selections tray

  attr :cart, :map, required: true
  attr :filters, Filters, required: true

  defp selections(assigns) do
    ~H"""
    <section
      id="selections"
      class="fz-fade border-b border-base-300 bg-base-100 px-4 py-2.5 md:px-8"
      aria-label="Selected items"
    >
      <div class="mb-1.5 flex items-center justify-between">
        <span class="text-[11px] font-bold uppercase tracking-wider text-muted">
          ✦ Selected so far · {@cart.item_count} {if @cart.item_count == 1, do: "item", else: "items"} · {format_price(
            @cart.subtotal
          )}
        </span>
        <button
          type="button"
          phx-click="toggle_cart"
          class="text-xs font-semibold text-primary cursor-pointer hover:underline"
        >
          Review cart
        </button>
      </div>
      <div class="fz-scroll flex gap-2.5 overflow-x-auto pb-1">
        <article
          :for={item <- @cart.items}
          id={"selection-#{item.id}"}
          class="fz-pop flex w-[220px] shrink-0 items-center gap-2.5 rounded-xl border border-base-300 bg-base-200 p-2"
          data-label={item.label}
          data-variant-id={item.variant_id}
        >
          <.link patch={product_path(item.variant.product_id, @filters)} class="shrink-0">
            <.product_art
              name={item.variant.product.name}
              hex={item.variant.color_hex}
              class="size-12 rounded-lg [&>span:first-child]:text-sm"
            />
          </.link>
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-1.5">
              <span
                :if={item.label}
                class="rounded-full bg-accent px-1.5 py-px text-[9px] font-bold text-accent-content"
              >
                {item.label}
              </span>
              <span class="truncate text-[10px] font-bold uppercase tracking-wide text-primary">
                {item.variant.product.brand}
              </span>
            </div>
            <div class="truncate text-xs font-semibold">{item.variant.product.name}</div>
            <div class="text-[11px] text-muted">
              {humanize(item.variant.color)} / {item.variant.size} · {format_price(item.line_total)}{if item.quantity >
                                                                                                          1,
                                                                                                        do:
                                                                                                          " (×#{item.quantity})"}
            </div>
          </div>
        </article>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------- filter rail

  attr :filters, Filters, required: true
  attr :facets, :map, required: true
  attr :sizes, :list, required: true
  attr :labels, :list, default: []

  defp filter_rail(assigns) do
    ~H"""
    <aside
      id="filter-rail"
      class="fz-scroll hidden w-[224px] shrink-0 overflow-y-auto border-r border-base-300 bg-base-100 p-4 md:block"
      aria-label="Filters"
    >
      <section
        :if={@labels != []}
        id="fit-labels"
        class="fz-fade mb-5 rounded-[14px] border border-peach-dark bg-peach p-3.5"
      >
        <div class="mb-1.5 text-[11px] font-bold uppercase tracking-wider text-error">
          ✦ Matched by your agent
        </div>
        <p class="mb-2.5 text-[11px] leading-snug text-muted">
          Sizes and preferences came from your agent, not this store.
        </p>
        <ul class="flex flex-col gap-1.5">
          <li
            :for={entry <- @labels}
            id={"fit-label-#{dom_slug(entry.label)}"}
            class="flex items-center justify-between text-[13px]"
          >
            <span>
              <strong>Fits {entry.label}</strong>
              <span class="text-muted">· {entry.product_count} {if entry.product_count == 1,
                do: "product",
                else: "products"}</span>
            </span>
            <button
              type="button"
              phx-click="clear_label"
              phx-value-label={entry.label}
              aria-label={"Clear matches for #{entry.label}"}
              class="text-xs text-faint cursor-pointer hover:text-error"
            >
              ×
            </button>
          </li>
        </ul>
      </section>

      <.facet title="Category">
        <div id="filter-categories" class="flex flex-col gap-0.5">
          <button
            :for={category <- @facets.categories}
            type="button"
            id={"filter-category-#{category.id}"}
            phx-click="set_category"
            phx-value-value={category.id}
            data-filter-type="category"
            data-filter-value={category.id}
            aria-pressed={to_string(@filters.category == category.id)}
            class={[
              "flex items-center justify-between rounded-lg px-2.5 py-2 text-left text-[13px] cursor-pointer",
              if(@filters.category == category.id,
                do: "bg-mint font-bold text-secondary dark:bg-base-300",
                else: "font-medium hover:bg-base-200"
              )
            ]}
          >
            <span>{category.name}</span>
            <span class="text-xs font-medium text-faint">{category.product_count}</span>
          </button>
        </div>
      </.facet>

      <.facet title="Shop for">
        <div id="filter-genders" class="flex flex-wrap gap-1.5">
          <button
            :for={gender <- Filters.genders()}
            type="button"
            id={"filter-gender-#{gender}"}
            phx-click="set_gender"
            phx-value-value={gender}
            data-filter-type="gender"
            data-filter-value={gender}
            aria-pressed={to_string(@filters.gender == gender)}
            class={[
              "rounded-full border px-2.5 py-1.5 text-xs font-semibold transition cursor-pointer",
              if(@filters.gender == gender,
                do: "border-primary bg-primary text-primary-content",
                else: "border-base-300 bg-base-100 hover:border-primary/60"
              )
            ]}
          >
            {Filters.gender_label(gender)}
          </button>
        </div>
      </.facet>

      <.facet :if={@sizes != []} title="Size">
        <div id="filter-sizes" class="flex flex-wrap gap-1.5">
          <.facet_pill
            :for={size <- @sizes}
            id={"filter-size-#{dom_slug(size)}"}
            facet="size"
            value={size}
            selected={size in @filters.sizes}
            shape="square"
          >
            {size}
          </.facet_pill>
        </div>
      </.facet>

      <.facet title="Color">
        <div id="filter-colors" class="flex flex-wrap gap-2">
          <.color_swatch
            :for={color <- @facets.colors}
            id={"filter-color-#{dom_slug(color.name)}"}
            name={color.name}
            hex={color.hex}
            selected={color.name in @filters.colors}
          />
        </div>
      </.facet>

      <.facet title="Brand">
        <div id="filter-brands" class="flex flex-col gap-1.5">
          <label
            :for={brand <- @facets.brands}
            id={"filter-brand-#{dom_slug(brand)}"}
            data-filter-type="brand"
            data-filter-value={brand}
            class="flex cursor-pointer items-center gap-2 text-[13px]"
          >
            <input
              type="checkbox"
              class="checkbox checkbox-primary checkbox-xs rounded"
              checked={brand in @filters.brands}
              phx-click="toggle_filter"
              phx-value-facet="brand"
              phx-value-value={brand}
            />
            {brand}
          </label>
        </div>
      </.facet>

      <.facet title="Price">
        <form
          id="filter-price"
          phx-change="set_price"
          phx-debounce="500"
          class="flex items-center gap-2"
        >
          <input
            type="number"
            name="min"
            min="0"
            placeholder="Min"
            value={@filters.price_min && Decimal.to_string(@filters.price_min, :normal)}
            aria-label="Minimum price"
            class="w-[70px] rounded-lg border border-base-300 bg-base-100 px-2 py-1.5 text-[13px]"
          />
          <span class="text-faint">–</span>
          <input
            type="number"
            name="max"
            min="0"
            placeholder="Max"
            value={@filters.price_max && Decimal.to_string(@filters.price_max, :normal)}
            aria-label="Maximum price"
            class="w-[70px] rounded-lg border border-base-300 bg-base-100 px-2 py-1.5 text-[13px]"
          />
        </form>
      </.facet>

      <.facet title="Fit">
        <div id="filter-fits" class="flex flex-wrap gap-1.5">
          <.facet_pill
            :for={fit <- @facets.fits}
            id={"filter-fit-#{fit}"}
            facet="fit"
            value={fit}
            selected={fit in @filters.fits}
          >
            {fit}
          </.facet_pill>
        </div>
      </.facet>

      <.facet title="Activity">
        <div id="filter-activities" class="flex flex-wrap gap-1.5">
          <.facet_pill
            :for={activity <- @facets.activities}
            id={"filter-activity-#{activity}"}
            facet="activity"
            value={activity}
            selected={activity in @filters.activities}
          >
            {activity}
          </.facet_pill>
        </div>
      </.facet>
    </aside>
    """
  end

  # ---------------------------------------------------------------- results

  attr :filters, Filters, required: true
  attr :facets, :map, required: true
  attr :chips, :list, required: true
  attr :results_count, :integer, required: true
  attr :streams, :map, required: true
  attr :annotations, :map, default: %{}

  defp results(assigns) do
    ~H"""
    <div id="results" class="fz-fade">
      <div class="flex items-baseline justify-between gap-4">
        <h1 class="font-display text-[22px] font-semibold">
          {State.results_heading(@facets, @filters)}
        </h1>
        <span id="results-count" class="shrink-0 text-[13px] text-muted">
          {@results_count} {if @results_count == 1, do: "product", else: "products"} found
        </span>
      </div>

      <div :if={@chips != []} id="active-filters" class="mt-3 flex flex-wrap items-center gap-2">
        <span class="text-[11px] font-bold uppercase tracking-wider text-faint">Active:</span>
        <.active_chip
          :for={chip <- @chips}
          facet={chip.facet}
          value={chip.value}
          label={chip_label(@facets, chip)}
        />
        <button
          type="button"
          id="clear-filters"
          phx-click="clear_filters"
          class="text-xs text-muted underline cursor-pointer"
        >
          Clear all
        </button>
      </div>

      <div
        :if={@results_count == 0}
        id="results-empty"
        class="mt-5 rounded-2xl border border-base-300 bg-base-100 p-8 text-center"
      >
        <div class="mb-2 text-[15px] font-bold">No products found</div>
        <p class="text-[13px] text-muted">
          Nothing in the catalog matches every constraint at once.
          Try raising the budget, dropping a brand, or trying another color.
        </p>
        <button
          type="button"
          phx-click="clear_filters"
          class="mt-4 rounded-full bg-primary px-4 py-2 text-[13px] font-semibold text-primary-content cursor-pointer"
        >
          Clear filters
        </button>
      </div>

      <div
        id="results-grid"
        phx-update="stream"
        class={[
          "mt-4 grid gap-3.5 [grid-template-columns:repeat(auto-fill,minmax(160px,1fr))]",
          @results_count == 0 && "hidden"
        ]}
      >
        <.product_card
          :for={{dom_id, product} <- @streams.products}
          id={dom_id}
          product={product}
          href={product_path(product.id, @filters)}
          annotations={State.annotations_for(@annotations, product.id)}
        />
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------- product detail

  attr :product, :map, required: true
  attr :filters, Filters, required: true
  attr :selected_color, :string, default: nil
  attr :selected_size, :string, default: nil
  attr :variant, :map, default: nil
  attr :size_guide_open, :boolean, default: false
  attr :comparing, :boolean, default: false
  attr :annotations, :list, default: []

  defp product_detail(assigns) do
    colors = FitzyoWeb.StoreComponents.color_options(assigns.product)
    selected = Enum.find(colors, &(&1.name == assigns.selected_color))

    assigns =
      assign(assigns,
        colors: colors,
        hex: selected && selected.hex,
        sizes:
          FitzyoWeb.StoreComponents.variants_in_color(assigns.product, assigns.selected_color),
        guide: assigns.product.size_guide_entries,
        guide_columns: size_guide_columns(assigns.product.size_guide_entries)
      )

    ~H"""
    <div class="fz-fade" id={"product-detail-#{@product.id}"}>
      <.link
        patch={~p"/?#{Filters.to_params(@filters)}"}
        id="back-to-results"
        class="mb-4 inline-flex items-center gap-1 text-[13px] font-semibold text-primary hover:underline"
      >
        <.icon name="hero-arrow-left-micro" class="size-4" /> Back to results
      </.link>

      <div class="grid items-start gap-6 md:grid-cols-[minmax(200px,1fr)_minmax(260px,1.3fr)]">
        <.product_art
          name={@product.name}
          hex={@hex}
          caption={@product.category.name}
          class="aspect-square w-full rounded-[20px]"
        />

        <section
          id={"product-#{@product.id}"}
          data-product-id={@product.id}
          data-product-name={@product.name}
          data-brand={@product.brand}
          data-category={@product.category_id}
          data-selected-color={@selected_color}
          data-selected-size={@selected_size}
          data-selected-variant-id={@variant && @variant.id}
        >
          <div class="text-xs font-bold uppercase tracking-wider text-primary">{@product.brand}</div>
          <h1 class="mb-2 mt-1.5 font-display text-[28px] font-semibold leading-tight">
            {@product.name}
          </h1>
          <div class="mb-3.5 text-[22px] font-bold">{format_price(@product.price)}</div>
          <p class="mb-5 text-sm leading-relaxed text-muted">{@product.description}</p>

          <div
            :for={annotation <- @annotations}
            id={"fit-match-#{@product.id}-#{dom_slug(annotation.label)}-#{annotation.source}"}
            class="fz-fade mb-4 rounded-[14px] border border-peach-dark bg-peach p-3.5"
            data-label={annotation.label}
            data-variant-id={annotation.variant_id}
          >
            <div class="mb-1.5 flex items-center justify-between">
              <span class="text-xs font-bold text-error">
                ✦ {if annotation.source == :match, do: "FitzYo Match", else: "FitzYo Recommendation"} — {annotation.label}
              </span>
              <button
                type="button"
                phx-click="remove_annotation"
                phx-value-product_id={@product.id}
                phx-value-label={annotation.label}
                aria-label={"Dismiss for #{annotation.label}"}
                class="text-xs text-faint cursor-pointer hover:text-error"
              >
                ×
              </button>
            </div>
            <ul
              :if={annotation.match != %{}}
              class="flex flex-wrap gap-x-4 gap-y-1 text-[13px] text-[#4a3b33]"
            >
              <li :for={{key, ok?} <- annotation.match}>
                <span class="capitalize">{key}</span> {if ok?, do: "✓", else: "✗"}
              </li>
            </ul>
            <p :if={annotation.reason} class="text-[13px] leading-snug text-[#4a3b33]">
              {annotation.reason}
            </p>
            <p :if={annotation.variant_id} class="mt-1 text-[11px] text-muted">
              Variant {annotation.variant_id} · agent-generated
            </p>
          </div>

          <div class="mb-4">
            <div class="mb-2 text-[11px] font-bold uppercase tracking-wider text-muted">
              Color
              <span class="ml-1 font-semibold normal-case tracking-normal text-base-content">{humanize(
                @selected_color
              )}</span>
            </div>
            <div id="detail-colors" class="flex gap-2.5">
              <.color_swatch
                :for={color <- @colors}
                id={"variant-#{@product.id}-#{dom_slug(color.name)}"}
                facet="color"
                event="select_color"
                name={color.name}
                hex={color.hex}
                selected={color.name == @selected_color}
                size="size-[34px]"
                data-product-id={@product.id}
                data-color={color.name}
              />
            </div>
          </div>

          <div class="mb-4">
            <div class="mb-2 flex items-center justify-between">
              <span class="text-[11px] font-bold uppercase tracking-wider text-muted">Size</span>
              <button
                :if={@guide != []}
                type="button"
                id="toggle-size-guide"
                phx-click="toggle_size_guide"
                class="text-xs font-semibold text-primary cursor-pointer hover:underline"
                aria-expanded={to_string(@size_guide_open)}
                aria-controls="size-guide"
              >
                Size guide
              </button>
            </div>
            <div id="detail-sizes" class="flex flex-wrap gap-2">
              <button
                :for={variant <- @sizes}
                type="button"
                id={"variant-#{variant.id}"}
                phx-click="select_size"
                phx-value-value={variant.size}
                disabled={variant.inventory_quantity == 0}
                data-product-id={@product.id}
                data-variant-id={variant.id}
                data-color={variant.color}
                data-size={variant.size}
                data-available={to_string(variant.inventory_quantity > 0)}
                aria-pressed={to_string(variant.size == @selected_size)}
                class={[
                  "rounded-lg border px-3.5 py-2 text-[13px] font-semibold transition",
                  cond do
                    variant.inventory_quantity == 0 ->
                      "cursor-not-allowed border-base-300 bg-base-200 text-faint line-through"

                    variant.size == @selected_size ->
                      "cursor-pointer border-primary bg-primary text-primary-content"

                    true ->
                      "cursor-pointer border-base-300 bg-base-100 hover:border-primary/60"
                  end
                ]}
              >
                {variant.size}
                <span
                  :for={label <- variant_labels(@annotations, variant.id)}
                  class="ml-1 rounded-full bg-accent px-1.5 py-px text-[9px] font-bold text-accent-content"
                >
                  {label}
                </span>
              </button>
            </div>
          </div>

          <div :if={@size_guide_open} id="size-guide" class="fz-fade mb-4 overflow-x-auto">
            <table class="w-full border-collapse text-xs">
              <caption class="sr-only">Size guide in {@product.measurement_unit}</caption>
              <thead>
                <tr>
                  <th class="border-b-2 border-base-300 px-2 py-1.5 text-left text-muted">Size</th>
                  <th
                    :for={{label, _min, _max} <- @guide_columns}
                    class="border-b-2 border-base-300 px-2 py-1.5 text-left text-muted"
                  >
                    {label}
                  </th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={entry <- @guide}
                  class={entry.size == @selected_size && "bg-mint font-semibold dark:bg-base-300"}
                >
                  <td class="border-b border-base-200 px-2 py-1.5">{entry.size}</td>
                  <td
                    :for={{_label, min, max} <- @guide_columns}
                    class="border-b border-base-200 px-2 py-1.5"
                  >
                    {measurement(entry, min, max)}"
                  </td>
                </tr>
              </tbody>
            </table>
          </div>

          <dl
            id="fit-info"
            class="mb-5 grid grid-cols-2 gap-x-4 gap-y-1.5 text-[13px] text-muted sm:grid-cols-3"
          >
            <div>
              <dt class="inline font-semibold text-base-content">Fit:</dt>

              <dd class="inline capitalize">{@product.fit}</dd>
            </div>
            <div>
              <dt class="inline font-semibold text-base-content">Stretch:</dt>

              <dd class="inline capitalize">{@product.stretch}</dd>
            </div>
            <div :if={@product.cut}>
              <dt class="inline font-semibold text-base-content">Cut:</dt>

              <dd class="inline capitalize">{@product.cut}</dd>
            </div>
            <div :if={@product.weight}>
              <dt class="inline font-semibold text-base-content">Weight:</dt>

              <dd class="inline capitalize">{@product.weight}</dd>
            </div>
            <div :if={@product.material}>
              <dt class="inline font-semibold text-base-content">Material:</dt>

              <dd class="inline capitalize">{@product.material}</dd>
            </div>
            <div class="col-span-full">
              <dt class="inline font-semibold text-base-content">Activities:</dt>

              <dd class="inline capitalize">{Enum.join(@product.activities, ", ")}</dd>
            </div>
          </dl>

          <button
            type="button"
            id="add-to-cart"
            phx-click="add_to_cart"
            phx-value-variant_id={@variant && @variant.id}
            disabled={is_nil(@variant) or @variant.inventory_quantity == 0}
            class={[
              "w-full rounded-xl py-3.5 text-[15px] font-bold text-primary-content transition",
              if(@variant && @variant.inventory_quantity > 0,
                do: "bg-primary cursor-pointer hover:brightness-95",
                else: "bg-base-300 text-muted cursor-not-allowed"
              )
            ]}
          >
            <%= cond do %>
              <% is_nil(@variant) -> %>
                Select a size
              <% @variant.inventory_quantity == 0 -> %>
                Unavailable in this size
              <% true -> %>
                Add to Cart · {format_price(@variant.price)}
            <% end %>
          </button>
          <p
            :if={@variant && @variant.inventory_quantity in 1..3}
            class="mt-2 text-center text-xs text-error"
          >
            Only {@variant.inventory_quantity} left in {humanize(@variant.color)} / {@variant.size}
          </p>
        </section>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------- comparison

  attr :products, :list, required: true
  attr :filters, Filters, required: true

  defp comparison(assigns) do
    rows = [
      {"Price", fn p -> format_price(p.price) end},
      {"Fit", fn p -> humanize(p.fit) end},
      {"Stretch", fn p -> humanize(p.stretch) end},
      {"Material", fn p -> humanize(p.material) end},
      {"Colors", fn p -> p |> color_options() |> Enum.map_join(", ", &humanize(&1.name)) end},
      {"Sizes in stock",
       fn p ->
         p.variants
         |> Enum.filter(&(&1.inventory_quantity > 0))
         |> Enum.map(& &1.size)
         |> Enum.uniq()
         |> Fitzyo.Catalog.Sizes.sort()
         |> Enum.join(", ")
       end},
      {"Activities", fn p -> Enum.map_join(p.activities, ", ", &humanize/1) end}
    ]

    assigns = assign(assigns, rows: rows)

    ~H"""
    <section
      id="comparison"
      class="fz-fade mb-5 overflow-x-auto rounded-2xl border border-base-300 bg-base-100 p-4"
      aria-label="Product comparison"
      data-product-ids={Enum.map_join(@products, ",", & &1.id)}
    >
      <div class="mb-3 flex items-center justify-between">
        <h2 class="font-display text-lg font-semibold">
          Comparing {length(@products)} {if length(@products) == 1, do: "product", else: "products"}
        </h2>
        <button
          type="button"
          id="compare-clear"
          phx-click="compare_clear"
          class="text-xs text-muted underline cursor-pointer"
        >
          Clear comparison
        </button>
      </div>
      <table class="w-full border-collapse text-[13px]">
        <thead>
          <tr>
            <th class="w-28 border-b-2 border-base-300 px-2 py-2 text-left text-[11px] font-bold uppercase tracking-wider text-muted">
            </th>
            <th
              :for={product <- @products}
              id={"compare-#{product.id}"}
              data-product-id={product.id}
              class="border-b-2 border-base-300 px-2 py-2 text-left align-top"
            >
              <div class="text-[10px] font-bold uppercase tracking-wide text-primary">
                {product.brand}
              </div>
              <.link patch={product_path(product.id, @filters)} class="font-semibold hover:underline">
                {product.name}
              </.link>
              <button
                type="button"
                phx-click="compare_remove"
                phx-value-product_id={product.id}
                aria-label={"Remove #{product.name} from comparison"}
                class="ml-1 text-xs text-faint cursor-pointer hover:text-error"
              >
                ×
              </button>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr :for={{label, value} <- @rows}>
            <th
              scope="row"
              class="border-b border-base-200 px-2 py-1.5 text-left font-semibold text-muted"
            >
              {label}
            </th>
            <td :for={product <- @products} class="border-b border-base-200 px-2 py-1.5 align-top">
              {value.(product)}
            </td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  # ---------------------------------------------------------------- agent proposal

  attr :proposal, :map, required: true

  defp agent_proposal(assigns) do
    totals = Proposals.totals(assigns.proposal)
    assigns = assign(assigns, totals: totals, groups: Proposals.groups(assigns.proposal))

    ~H"""
    <section
      id="agent-proposal"
      class="fz-fade m-3 rounded-[14px] border-2 border-accent bg-base-100 p-3.5"
      role="group"
      aria-labelledby="agent-proposal-title"
      data-proposal-id={@proposal.id}
      data-selected-total={Decimal.to_string(@totals.total, :normal)}
      data-over-by={Decimal.to_string(@totals.over_by, :normal)}
    >
      <div class="mb-1 flex items-start justify-between gap-2">
        <div class="text-[11px] font-bold uppercase tracking-wider text-error">✦ Proposed basket</div>
        <span class="text-[10px] text-faint">
          {if @proposal.mode == "replace", do: "replaces cart", else: "adds to cart"}
        </span>
      </div>
      <h3 id="agent-proposal-title" class="font-display text-[15px] font-semibold leading-snug">
        {@proposal.title}
      </h3>
      <p :if={@proposal.subtitle} class="text-xs text-muted">{@proposal.subtitle}</p>

      <div
        id="proposal-total"
        class={[
          "mt-2 rounded-lg px-2.5 py-1.5 text-[13px] font-bold",
          if(Decimal.positive?(@totals.over_by),
            do: "bg-peach text-error",
            else: "bg-mint text-secondary dark:bg-base-300"
          )
        ]}
      >
        <%= if @proposal.budget[:total] do %>
          {format_price(@totals.total)} of {format_price(@proposal.budget.total)}
          <span :if={Decimal.positive?(@totals.over_by)}>· {format_price(@totals.over_by)} over</span>
          <span :if={!Decimal.positive?(@totals.over_by)}>· within budget</span>
        <% else %>
          {format_price(@totals.total)} selected
        <% end %>
      </div>

      <div :for={{label, lines} <- @groups} class="mt-3" data-label={label}>
        <div class="mb-1 flex items-center justify-between text-[11px] font-bold uppercase tracking-wider text-secondary">
          <span>{label || "For the cart"}</span>
          <span
            :if={label}
            class={[Decimal.positive?(@totals.over_by_label[label] || Decimal.new(0)) && "text-error"]}
          >
            {format_price(@totals.by_label[label] || Decimal.new(0))}
            <span :if={cap = get_in(@proposal.budget, [:by_label, label])}> / {format_price(cap)}</span>
          </span>
        </div>
        <ul class="flex flex-col gap-1.5">
          <li
            :for={line <- lines}
            id={"proposal-line-#{line.key}"}
            data-line-key={line.key}
            data-variant-id={line.chosen_variant_id}
            data-selected={to_string(line.selected)}
            class={[
              "rounded-xl border p-2 text-[12px]",
              if(line.selected,
                do: "border-base-300 bg-base-200",
                else: "border-dashed border-base-300 opacity-60"
              )
            ]}
          >
            <div class="flex items-start gap-2">
              <input
                type="checkbox"
                id={"proposal-tick-#{line.key}"}
                checked={line.selected}
                phx-click="proposal_toggle"
                phx-value-key={line.key}
                aria-label={"Include #{Proposals.chosen(line).name}"}
                class="checkbox checkbox-primary checkbox-sm mt-1 rounded"
              />
              <.product_art
                name={Proposals.chosen(line).name}
                hex={Proposals.chosen(line).hex}
                class="size-10 shrink-0 rounded-lg [&>span:first-child]:text-xs"
              />
              <div class="min-w-0 flex-1">
                <div class="font-semibold leading-snug">{Proposals.chosen(line).name}</div>
                <div class="text-[11px] text-muted">
                  {Proposals.chosen(line).brand} · {Proposals.chosen(line).detail}
                </div>
                <div :if={line.optional} class="text-[10px] uppercase tracking-wide text-faint">
                  optional
                </div>
              </div>
            </div>
            <div :if={line.reason} class="mt-1 pl-7 text-[11px] italic text-base-content/80">
              {line.reason}
            </div>
            <div
              :if={line.auto_swapped and line.chosen_variant_id != line.proposed_variant_id}
              class="mt-1 pl-7 text-[11px] font-semibold text-error"
            >
              Proposed {line.proposed_variant_id} is sold out; showing an alternative the agent offered
            </div>
            <div class="mt-1.5 flex items-center justify-between pl-7">
              <div class="flex items-center gap-0.5 rounded-full border border-base-300">
                <button
                  type="button"
                  phx-click="proposal_qty"
                  phx-value-key={line.key}
                  phx-value-delta="-1"
                  aria-label="Decrease quantity"
                  class="px-1.5 text-sm cursor-pointer"
                >
                  −
                </button>
                <span class="min-w-4 text-center text-xs font-semibold" data-quantity={line.quantity}>
                  {line.quantity}
                </span>
                <button
                  type="button"
                  phx-click="proposal_qty"
                  phx-value-key={line.key}
                  phx-value-delta="1"
                  aria-label="Increase quantity"
                  class="px-1.5 text-sm cursor-pointer"
                >
                  +
                </button>
              </div>
              <span class="text-[12px] font-bold">
                {format_price(Decimal.mult(Proposals.chosen(line).price, line.quantity))}
              </span>
            </div>
            <div :if={length(line.options) > 1} class="mt-1.5 flex flex-wrap gap-1 pl-7">
              <button
                :for={option <- line.options}
                type="button"
                id={"proposal-swap-#{line.key}-#{dom_slug(option.variant_id)}"}
                phx-click="proposal_swap"
                phx-value-key={line.key}
                phx-value-variant_id={option.variant_id}
                disabled={!option.available}
                title={option.reason}
                class={[
                  "rounded-full border px-2 py-0.5 text-[10px] font-semibold",
                  cond do
                    option.variant_id == line.chosen_variant_id ->
                      "border-primary bg-primary text-primary-content"

                    option.available ->
                      "border-base-300 bg-base-100 cursor-pointer hover:border-primary/60"

                    true ->
                      "border-base-300 text-faint line-through cursor-not-allowed"
                  end
                ]}
              >
                {option.name}{if option.detail, do: " · " <> option.detail} · {format_price(
                  option.price
                )}
              </button>
            </div>
          </li>
        </ul>
      </div>

      <ul
        :if={@proposal.unavailable != []}
        id="proposal-unavailable"
        class="mt-2 flex flex-col gap-0.5 text-[11px] text-faint"
      >
        <li :for={u <- @proposal.unavailable} class="line-through" data-variant-id={u.variant_id}>
          {u.variant_id} · {u.reason}
        </li>
      </ul>

      <div class="mt-3 flex gap-2">
        <button
          type="button"
          id="proposal-reject"
          phx-click="proposal_reject"
          class="rounded-xl border border-base-300 px-3 py-2 text-[12px] font-semibold cursor-pointer hover:bg-base-200"
        >
          Reject
        </button>
        <button
          type="button"
          id="proposal-accept"
          phx-click="proposal_accept"
          disabled={@totals.selected_count == 0}
          class={[
            "flex-1 rounded-xl py-2 text-[12px] font-bold text-primary-content",
            if(@totals.selected_count == 0,
              do: "bg-base-300 text-muted cursor-not-allowed",
              else: "bg-primary cursor-pointer hover:brightness-95"
            )
          ]}
        >
          Accept selected · {@totals.selected_count} · {format_price(@totals.total)}
        </button>
      </div>
      <p class="mt-2 text-[10px] text-faint">
        Accepting adds these to your cart. Nothing is ordered until you review and hold to place it.
      </p>
    </section>
    """
  end

  # ---------------------------------------------------------------- agent question

  attr :question, :map, required: true

  defp agent_question(assigns) do
    ~H"""
    <section
      id="agent-question"
      class="fz-fade m-3 rounded-[14px] border-2 border-accent bg-peach p-3.5 text-[#4a3b33]"
      role="group"
      aria-labelledby="agent-question-title"
      data-question-id={@question.id}
      phx-window-keydown="dismiss_question"
      phx-key="Escape"
    >
      <div class="mb-1 flex items-start justify-between gap-2">
        <div class="text-[11px] font-bold uppercase tracking-wider text-error">
          ✦ Your agent is asking
        </div>
        <button
          type="button"
          id="dismiss-question"
          phx-click="dismiss_question"
          class="shrink-0 text-xs font-semibold text-muted cursor-pointer hover:text-error"
        >
          Not now
        </button>
      </div>
      <h3 id="agent-question-title" class="font-display text-[15px] font-semibold leading-snug">
        {@question.question}
      </h3>
      <p :if={@question.subtitle} class="mt-0.5 text-xs text-muted">{@question.subtitle}</p>

      <form
        id="agent-question-form"
        phx-submit="answer_question"
        class="mt-3 flex flex-col gap-2"
      >
        <%= for {option, index} <- Enum.with_index(@question.options) do %>
          <%= if @question.allow_multiple do %>
            <label
              id={"question-option-#{dom_slug(option.id)}"}
              data-option-id={option.id}
              class="flex cursor-pointer items-start gap-2 rounded-xl border border-base-300 bg-base-100 p-2.5 text-[13px] hover:border-primary/60"
            >
              <input
                type="checkbox"
                name="selected[]"
                value={option.id}
                autofocus={index == 0}
                class="checkbox checkbox-primary checkbox-sm mt-0.5 rounded"
              />
              <.question_option option={option} />
            </label>
          <% else %>
            <button
              type="button"
              id={"question-option-#{dom_slug(option.id)}"}
              phx-click="answer_question"
              phx-value-option_id={option.id}
              data-option-id={option.id}
              autofocus={index == 0}
              class="flex w-full cursor-pointer items-start gap-2 rounded-xl border border-base-300 bg-base-100 p-2.5 text-left text-[13px] transition hover:border-primary hover:bg-mint focus:outline-none focus:ring-2 focus:ring-primary"
            >
              <.question_option option={option} />
            </button>
          <% end %>
        <% end %>

        <input
          :if={@question.allow_free_text}
          type="text"
          name="free_text"
          id="question-free-text"
          placeholder={if @question.options == [], do: "Type your answer…", else: "Other…"}
          autocomplete="off"
          autofocus={@question.options == []}
          class="w-full rounded-xl border border-base-300 bg-base-100 px-3 py-2 text-[13px]"
        />

        <button
          :if={@question.allow_multiple or @question.allow_free_text}
          type="submit"
          id="answer-question"
          class="mt-1 rounded-xl bg-primary py-2.5 text-[13px] font-bold text-primary-content cursor-pointer hover:brightness-95"
        >
          Answer
        </button>
      </form>
      <p class="mt-2.5 text-[10px] text-faint">
        The agent is paused until you answer. You can keep browsing and editing the cart meanwhile.
      </p>
    </section>
    """
  end

  attr :option, :map, required: true

  defp question_option(assigns) do
    ~H"""
    <%= if @option.product do %>
      <.product_art
        name={@option.product.name}
        hex={@option.product.hex}
        class="size-11 shrink-0 rounded-lg [&>span:first-child]:text-sm"
      />
      <span class="min-w-0 flex-1">
        <span class="block font-semibold leading-snug">{@option.label}</span>
        <span class="block truncate text-[11px] text-muted">
          {@option.product.brand} · {@option.product.name}{if @option.product.detail,
            do: " · " <> @option.product.detail} · {format_price(@option.product.price)}
        </span>
        <span :if={!@option.product.available} class="block text-[11px] font-semibold text-error">
          Sold out when asked
        </span>
        <span :if={@option.description} class="block text-[11px] text-muted">{@option.description}</span>
      </span>
    <% else %>
      <span class="min-w-0 flex-1">
        <span class="block font-semibold leading-snug">{@option.label}</span>
        <span :if={@option.description} class="block text-[11px] text-muted">{@option.description}</span>
      </span>
    <% end %>
    """
  end

  # ---------------------------------------------------------------- agent panel

  attr :open, :boolean, required: true
  attr :connected, :boolean, required: true
  attr :transport, :atom, default: nil
  attr :tool_count, :integer, required: true
  attr :activity, :list, required: true
  attr :plan, :map, default: nil
  attr :question, :map, default: nil
  attr :proposal, :map, default: nil

  defp agent_panel(assigns) do
    ~H"""
    <aside
      id="agent-panel"
      class={[
        "hidden shrink-0 flex-col border-l border-base-300 bg-base-200 transition-[width] duration-200 lg:flex",
        cond do
          !@open -> "w-8"
          @proposal || @question -> "w-[340px]"
          true -> "w-[260px]"
        end
      ]}
      aria-label="Agent activity"
      data-open={to_string(@open)}
    >
      <%= if @open do %>
        <div class="flex items-center justify-between border-b border-base-300 p-4">
          <span class="text-[13px] font-bold text-secondary">✦ Agent Activity</span>
          <button
            type="button"
            phx-click="toggle_agent_panel"
            aria-label="Collapse agent panel"
            class="text-muted cursor-pointer"
          >
            <.icon name="hero-chevron-right-micro" class="size-4" />
          </button>
        </div>
        <.agent_question :if={@question} question={@question} />
        <.agent_proposal :if={@proposal} proposal={@proposal} />
        <section
          :if={@plan}
          id="agent-plan"
          class="fz-fade m-3 rounded-[14px] border border-mint-dark bg-mint p-3.5 dark:bg-base-300"
          aria-label="Agent shopping plan"
        >
          <div class="mb-1 flex items-start justify-between gap-2">
            <div>
              <div class="font-display text-[15px] font-semibold leading-tight">{@plan.title}</div>
              <div :if={@plan.subtitle} class="text-[11px] text-muted">{@plan.subtitle}</div>
            </div>
            <button
              type="button"
              phx-click="dismiss_plan"
              aria-label="Dismiss plan"
              class="text-xs text-faint cursor-pointer hover:text-error"
            >
              ×
            </button>
          </div>
          <div :for={group <- @plan.groups} class="mt-2.5">
            <div class="text-[11px] font-bold uppercase tracking-wider text-secondary">
              {group.label}
            </div>
            <ul class="mt-1 flex flex-col gap-0.5 text-xs">
              <li :for={item <- group.items} class="flex gap-1.5" data-status={item.status}>
                <span class={[
                  "w-3 shrink-0 text-center font-bold",
                  case item.status do
                    "added" -> "text-primary"
                    "have" -> "text-faint"
                    "need" -> "text-accent"
                    _ -> "text-faint"
                  end
                ]}>
                  {case item.status do
                    "added" -> "✓"
                    "have" -> "✓"
                    "need" -> "•"
                    _ -> "–"
                  end}
                </span>
                <span class={[
                  item.status in ~w(have skipped) && "text-muted",
                  item.status == "skipped" && "line-through"
                ]}>
                  {item.text}
                </span>
              </li>
            </ul>
          </div>
          <p class="mt-2.5 text-[10px] text-faint">
            Plan written by your agent from your private context.
          </p>
        </section>
        <ol
          id="agent-activity"
          phx-hook="FzAutoScroll"
          class="fz-scroll flex flex-1 flex-col gap-2.5 overflow-y-auto px-4 py-3.5"
        >
          <li :if={@activity == []} class="text-xs leading-relaxed text-muted">
            No agent actions yet. When a WebMCP-connected agent searches, filters, or
            adds to the cart, each call shows up here.
          </li>
          <%= for entry <- @activity do %>
            <%= if entry.kind == :human do %>
              <li class="fz-fade" data-kind="human" data-status={entry.status}>
                <div class={[
                  "flex gap-1.5 text-[12px] font-semibold leading-snug",
                  if(entry.status == :ok, do: "text-base-content", else: "text-error")
                ]}>
                  <span aria-hidden="true">👤</span>
                  <span>{entry.text}</span>
                </div>
              </li>
            <% else %>
              <%= if entry.kind == :thought do %>
                <li class="fz-fade" data-kind="thought">
                  <div class="flex gap-1.5 text-[12px] italic leading-snug text-base-content/80">
                    <span aria-hidden="true">💭</span>
                    <span class="whitespace-pre-wrap">{entry.text}</span>
                  </div>
                </li>
              <% else %>
                <li class="fz-fade" data-kind="call" data-status={entry.status}>
                  <div class={[
                    "break-words font-mono text-[11px] font-bold",
                    if(entry.status == :ok, do: "text-secondary", else: "text-error")
                  ]}>
                    {if entry.status == :ok, do: "✓", else: "✗"} {entry.call}
                  </div>
                  <div class="mt-0.5 text-[11px] text-muted">{entry.result}</div>
                </li>
              <% end %>
            <% end %>
          <% end %>
        </ol>
        <div class="flex items-center gap-2 border-t border-base-300 px-4 py-3">
          <%= if @connected do %>
            <.status_dot class="size-[7px]" />
            <span class="text-[11px] text-muted">
              Agent connected · {@tool_count} WebMCP tools{if @transport == :native,
                do: " (native)",
                else: ""}
            </span>
          <% else %>
            <span class="inline-block size-[7px] rounded-full bg-faint" />
            <span class="text-[11px] text-muted">
              {@tool_count} WebMCP tools exposed · waiting for an agent
            </span>
          <% end %>
        </div>
      <% else %>
        <button
          type="button"
          phx-click="toggle_agent_panel"
          aria-label="Expand agent panel"
          class="h-full w-full text-xs font-semibold text-muted cursor-pointer [writing-mode:vertical-rl]"
        >
          ✦ Agent Activity ‹
        </button>
      <% end %>
    </aside>
    """
  end

  # ---------------------------------------------------------------- cart drawer

  attr :cart, :map, required: true

  defp cart_drawer(assigns) do
    ~H"""
    <div
      id="cart-drawer"
      class="fixed inset-0 z-40"
      role="dialog"
      aria-modal="true"
      aria-labelledby="cart-title"
    >
      <div class="absolute inset-0 bg-[#1e2b24]/35" phx-click="toggle_cart" aria-hidden="true" />
      <div class="absolute inset-y-0 right-0 flex w-full max-w-[400px] flex-col bg-base-100 shadow-[-8px_0_24px_rgba(30,43,36,0.12)]">
        <div class="flex items-center justify-between border-b border-base-300 p-5">
          <h2 id="cart-title" class="font-display text-lg">
            Cart
            <span :if={@cart.item_count > 0} class="ml-1 text-sm font-normal text-muted">
              ({@cart.item_count})
            </span>
          </h2>
          <div class="flex items-center gap-4">
            <button
              :if={@cart.items != []}
              type="button"
              id="cart-clear"
              phx-click="clear_cart"
              data-confirm="Remove every item from the cart?"
              class="text-xs font-semibold text-error cursor-pointer hover:underline"
            >
              Remove all
            </button>
            <button
              type="button"
              phx-click="toggle_cart"
              aria-label="Close cart"
              class="text-muted cursor-pointer"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>
        </div>

        <div id="cart-items" class="fz-scroll flex flex-1 flex-col gap-4 overflow-y-auto px-5 py-4">
          <p :if={@cart.items == []} id="cart-empty" class="py-10 text-center text-[13px] text-faint">
            Your cart is empty.
          </p>
          <section
            :for={{label, items} <- cart_groups(@cart.items)}
            id={"cart-group-#{dom_slug(label || "everyone")}"}
            data-label={label}
          >
            <h3 class="mb-2 text-[11px] font-bold uppercase tracking-wider text-primary">
              {label || "Your picks"}
            </h3>
            <ul class="flex flex-col gap-3.5">
              <li
                :for={item <- items}
                id={"cart-item-#{item.id}"}
                data-cart-item-id={item.id}
                data-variant-id={item.variant_id}
                data-product-id={item.variant.product_id}
                data-quantity={item.quantity}
                class="flex gap-3 border-b border-base-200 pb-3.5"
              >
                <.product_art
                  name={item.variant.product.name}
                  hex={item.variant.color_hex}
                  class="size-16 shrink-0 rounded-[10px] [&>span:first-child]:text-lg"
                />
                <div class="min-w-0 flex-1">
                  <.link
                    patch={~p"/products/#{item.variant.product_id}"}
                    phx-click="toggle_cart"
                    class="block truncate text-[13px] font-semibold hover:underline"
                  >
                    {item.variant.product.name}
                  </.link>
                  <div class="text-xs text-muted">
                    {humanize(item.variant.color)} / {item.variant.size}
                    <span
                      :if={item.source != :human}
                      class="ml-1 rounded-full bg-mint px-1.5 py-px text-[9px] font-bold uppercase tracking-wide text-secondary dark:bg-base-300"
                      title={
                        if item.source == :proposal,
                          do: "Proposed by your agent, accepted by you",
                          else: "Added by your agent"
                      }
                      data-source={item.source}
                    >
                      ✦ {if item.source == :proposal, do: "accepted", else: "agent"}
                    </span>
                  </div>
                  <div class="mt-1.5 flex items-center justify-between">
                    <div class="flex items-center gap-1 rounded-full border border-base-300">
                      <button
                        type="button"
                        phx-click="cart_decrement"
                        phx-value-id={item.id}
                        aria-label="Decrease quantity"
                        class="px-2 py-0.5 text-sm cursor-pointer"
                      >
                        −
                      </button>
                      <span class="min-w-4 text-center text-xs font-semibold">{item.quantity}</span>
                      <button
                        type="button"
                        phx-click="cart_increment"
                        phx-value-id={item.id}
                        aria-label="Increase quantity"
                        class="px-2 py-0.5 text-sm cursor-pointer"
                      >
                        +
                      </button>
                    </div>
                    <span class="text-[13px] font-bold">{format_price(item.line_total)}</span>
                  </div>
                  <button
                    type="button"
                    phx-click="remove_cart_item"
                    phx-value-id={item.id}
                    class="mt-1 text-xs text-error cursor-pointer hover:underline"
                  >
                    Remove
                  </button>
                </div>
              </li>
            </ul>
          </section>
        </div>

        <div class="border-t border-base-300 p-5">
          <div class="mb-3.5 flex justify-between text-sm font-bold">
            <span>Subtotal</span>
            <span id="cart-subtotal">{format_price(@cart.subtotal)}</span>
          </div>
          <button
            type="button"
            id="checkout"
            phx-click="checkout"
            disabled={@cart.items == []}
            class={[
              "w-full rounded-xl py-3.5 text-sm font-bold text-primary-content",
              if(@cart.items == [],
                do: "bg-base-300 text-muted cursor-not-allowed",
                else: "bg-primary cursor-pointer hover:brightness-95"
              )
            ]}
          >
            Review &amp; Approve Checkout
          </button>
          <p class="mt-2 text-center text-[11px] text-faint">
            Human approval required — the agent cannot check out for you.
          </p>
        </div>
      </div>
    </div>
    """
  end

  attr :cart, :map, required: true

  defp checkout_review(assigns) do
    ~H"""
    <div
      id="checkout-review"
      class="fixed inset-0 z-50 flex items-center justify-center bg-[#1e2b24]/45 p-4"
      role="dialog"
      aria-modal="true"
      aria-labelledby="checkout-review-title"
    >
      <div class="flex max-h-[85vh] w-full max-w-[440px] flex-col rounded-[20px] bg-base-100 p-6">
        <h2 id="checkout-review-title" class="font-display text-xl">Review your order</h2>
        <p class="mb-4 text-[13px] text-muted">
          Check every line before placing the order. This is the step no agent can take for you.
        </p>
        <ul class="fz-scroll flex-1 divide-y divide-base-200 overflow-y-auto">
          <li
            :for={item <- @cart.items}
            class="flex items-center justify-between gap-3 py-2 text-[13px]"
            data-variant-id={item.variant_id}
          >
            <span class="min-w-0">
              <span
                :if={item.label}
                class="mr-1 rounded-full bg-accent px-1.5 py-px text-[9px] font-bold text-accent-content"
              >
                {item.label}
              </span>
              <span class="font-semibold">{item.variant.product.name}</span>
              <span class="text-muted"> · {humanize(item.variant.color)} / {item.variant.size} × {item.quantity}</span>
            </span>
            <span class="shrink-0 font-bold">{format_price(item.line_total)}</span>
          </li>
        </ul>
        <div class="mt-4 flex justify-between border-t border-base-300 pt-3 text-sm font-bold">
          <span>Total</span>
          <span>{format_price(@cart.subtotal)}</span>
        </div>
        <div class="mt-4 flex gap-2">
          <button
            type="button"
            id="cancel-checkout"
            phx-click="cancel_checkout"
            class="flex-1 rounded-xl border border-base-300 py-3 text-sm font-semibold cursor-pointer hover:bg-base-200"
          >
            Back to cart
          </button>
          <button
            type="button"
            id="confirm-checkout"
            phx-hook="FzHoldToConfirm"
            data-hold-ms="700"
            aria-describedby="confirm-checkout-help"
            class="relative flex-1 select-none overflow-hidden rounded-xl bg-primary py-3 text-sm font-bold text-primary-content cursor-pointer hover:brightness-95"
          >
            <span
              class="absolute inset-y-0 left-0 w-0 bg-secondary/70 transition-[width] duration-75"
              data-hold-fill
              aria-hidden="true"
            />
            <span class="relative">Press and hold to place order</span>
          </button>
        </div>
        <p id="confirm-checkout-help" class="mt-2 text-center text-[11px] text-faint">
          Holding the button is your approval; an agent cannot do it for you. Demo only — no payment is processed.
        </p>
      </div>
    </div>
    """
  end

  attr :confirmation, :map, required: true

  defp order_confirmation(assigns) do
    ~H"""
    <div
      id="order-confirmation"
      class="fixed inset-0 z-50 flex items-center justify-center bg-[#1e2b24]/45 p-4"
      role="dialog"
      aria-modal="true"
    >
      <div class="max-w-[380px] rounded-[20px] bg-base-100 p-9 text-center">
        <div class="mx-auto mb-4 flex size-14 items-center justify-center rounded-full bg-mint text-[28px] text-primary dark:bg-base-300">
          ✓
        </div>
        <h2 class="mb-2 font-display text-xl">Order confirmed</h2>
        <p class="mb-1 text-[13px] text-muted">
          Order <strong class="text-base-content">{@confirmation.order_number}</strong>
          · {@confirmation.item_count} items · {format_price(@confirmation.subtotal)}
        </p>
        <p id="order-approved-by" class="mb-5 text-[13px] text-muted">
          Approved by {@confirmation.approved_by}. This is a demo — no payment was processed.
        </p>
        <button
          type="button"
          phx-click="close_confirmation"
          class="rounded-full bg-primary px-6 py-3 text-sm font-bold text-primary-content cursor-pointer"
        >
          Done
        </button>
      </div>
    </div>
    """
  end
end
