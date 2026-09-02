defmodule FitzyoWeb.StoreLive.Proposals do
  @moduledoc """
  The `propose_cart` tool: an agent presents one priced, grouped basket and
  the shopper accepts it in a single action, after unticking lines, changing
  quantities, or swapping to an alternative the agent offered.

  The store prices and validates; the agent decides. Every variant comes from
  the agent, including alternatives; the store never invents a substitute.
  Accepting writes the selected lines to the cart and never checks out.

  Like `ask_human`, the call is intercepted ahead of the AshWebMcp hook and
  held open until the shopper resolves it (`intercept/3`, `resolve/3`). Only
  one pending human decision exists at a time: opening a proposal supersedes
  an open question and vice versa.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias Fitzyo.Catalog
  alias Fitzyo.Commerce
  alias FitzyoWeb.StoreLive.{Presenter, Questions, State}

  @default_timeout 300_000
  @min_timeout 5_000
  @max_timeout 600_000
  @max_lines 40
  @max_alternatives 3

  # ---------------------------------------------------------------- spec

  def spec do
    %{
      name: "propose_cart",
      description:
        "Show the shopper a complete, priced basket to approve in one action, grouped by label, with a reason per line. Use it instead of many add_to_cart calls when you have assembled a whole outfit or trip. Accepting adds the selected lines to the cart — it never checks out. The shopper may untick lines, change quantities, or pick one of the alternatives you supplied, so read applied, declined, and substituted rather than assuming your proposal went through as sent. Send budget when the shopper gave you one; the store will show the overage rather than silently exceeding it. Put the reasoning in reason, never the shopper's private context. If the choice is which lines, propose; if it is which strategy, ask_human.",
      input_schema: %{
        type: "object",
        required: ["lines"],
        additionalProperties: false,
        properties: %{
          title: %{type: "string", description: "e.g. \"Beach trip — 3 person wardrobe\""},
          subtitle: %{type: "string", description: "e.g. \"Sun protection, swim, dinners\""},
          mode: %{
            type: "string",
            enum: ["replace", "add"],
            default: "add",
            description: "replace clears the cart on accept; add merges into it"
          },
          budget: %{
            type: "object",
            additionalProperties: false,
            properties: %{
              total: %{type: "number", minimum: 0},
              by_label: %{
                type: "object",
                additionalProperties: %{type: "number", minimum: 0},
                description: "e.g. {\"Dad\": 250, \"Mom\": 200}"
              }
            }
          },
          lines: %{
            type: "array",
            minItems: 1,
            maxItems: @max_lines,
            items: %{
              type: "object",
              required: ["variant_id"],
              additionalProperties: false,
              properties: %{
                variant_id: %{type: "string"},
                quantity: %{type: "integer", minimum: 1, default: 1},
                label: %{type: "string", description: "Who it is for, e.g. \"Milo\""},
                reason: %{type: "string", description: "One line the shopper will read"},
                optional: %{
                  type: "boolean",
                  default: false,
                  description: "Nice-to-have; renders unselected by default"
                },
                alternatives: %{
                  type: "array",
                  maxItems: @max_alternatives,
                  description:
                    "Swaps you would accept. The store prices them; it never invents its own.",
                  items: %{
                    type: "object",
                    required: ["variant_id"],
                    additionalProperties: false,
                    properties: %{
                      variant_id: %{type: "string"},
                      reason: %{type: "string", description: "e.g. \"same UPF, $16 less\""}
                    }
                  }
                }
              }
            }
          },
          timeout_ms: %{
            type: "integer",
            minimum: @min_timeout,
            maximum: @max_timeout,
            default: @default_timeout
          }
        }
      },
      annotations: %{
        readOnlyHint: false,
        destructive?: false,
        idempotentHint: false,
        blocking?: true
      }
    }
  end

  # ---------------------------------------------------------------- transport

  def intercept("webmcp:call", %{"id" => call_id, "tool" => "propose_cart"} = params, socket) do
    {:halt, propose(socket, call_id, params["input"] || %{})}
  end

  def intercept(_event, _params, socket), do: {:cont, socket}

  @doc "Opens a proposal for `call_id`, superseding any open proposal or question."
  def propose(socket, call_id, input) do
    case build(input) do
      {:ok, proposal} ->
        socket
        |> supersede()
        |> Questions.supersede()
        |> open(Map.put(proposal, :call_id, call_id))

      {:error, message} ->
        push_event(socket, "webmcp:result", %{
          id: call_id,
          status: "error",
          error: Jason.encode!(%{success: false, code: "INVALID_OPERATION", message: message})
        })
    end
  end

  @doc "Resolves an open proposal as superseded (used when a question opens)."
  def supersede(%{assigns: %{proposal: nil}} = socket), do: socket

  def supersede(socket),
    do: resolve(socket, %{accepted: false, reason: "superseded"}, nil)

  # ---------------------------------------------------------------- human edits

  def toggle_line(socket, key), do: update_line(socket, key, &%{&1 | selected: not &1.selected})

  def set_quantity(socket, key, quantity) when is_integer(quantity) and quantity >= 1,
    do: update_line(socket, key, &%{&1 | quantity: quantity})

  def set_quantity(socket, _key, _quantity), do: socket

  def swap(socket, key, variant_id) do
    update_line(socket, key, fn line ->
      if Enum.any?(line.options, &(&1.variant_id == variant_id and &1.available)),
        do: %{line | chosen_variant_id: variant_id, selected: true},
        else: line
    end)
  end

  defp update_line(%{assigns: %{proposal: nil}} = socket, _key, _fun), do: socket

  defp update_line(socket, key, fun) do
    proposal = socket.assigns.proposal

    lines =
      Enum.map(proposal.lines, fn
        %{key: ^key} = line -> fun.(line)
        line -> line
      end)

    assign(socket, proposal: %{proposal | lines: lines})
  end

  # ---------------------------------------------------------------- outcomes

  @doc "Applies the selected lines to the cart as it is now and resolves the call."
  def accept(%{assigns: %{proposal: nil}} = socket), do: socket

  def accept(socket) do
    proposal = socket.assigns.proposal
    cart_id = socket.assigns.cart_id

    if proposal.mode == "replace", do: Commerce.clear_cart(cart_id)

    {applied, failed} =
      proposal.lines
      |> Enum.filter(& &1.selected)
      |> Enum.reduce({[], []}, fn line, {ok, bad} ->
        case Commerce.add_to_cart(cart_id, line.chosen_variant_id, %{
               quantity: line.quantity,
               label: line.label,
               source: :proposal
             }) do
          {:ok, item} ->
            {[
               %{
                 variant_id: item.variant_id,
                 quantity: line.quantity,
                 label: line.label,
                 line_total: Presenter.number(Decimal.mult(item.unit_price, line.quantity))
               }
               | ok
             ], bad}

          {:error, error} ->
            {ok,
             [
               %{variant_id: line.chosen_variant_id, reason: Fitzyo.Errors.code(error) || "error"}
               | bad
             ]}
        end
      end)

    applied = Enum.reverse(applied)
    socket = State.load_cart(socket)
    cart = socket.assigns.cart

    declined =
      proposal.lines
      |> Enum.reject(& &1.selected)
      |> Enum.map(& &1.proposed_variant_id)

    substituted =
      proposal.lines
      |> Enum.filter(&(&1.selected and &1.chosen_variant_id != &1.proposed_variant_id))
      |> Enum.map(&%{proposed: &1.proposed_variant_id, chosen: &1.chosen_variant_id})

    result = %{
      accepted: true,
      applied: applied,
      declined: declined,
      substituted: substituted,
      unavailable: proposal.unavailable ++ Enum.reverse(failed),
      cart: Presenter.cart_totals(cart),
      budget: budget_result(proposal.budget, applied_total(applied), cart.subtotal)
    }

    note =
      [
        "Accepted proposal: #{length(applied)} #{plural(length(applied), "line")} added",
        declined != [] && "declined #{length(declined)}",
        substituted != [] && "swapped #{length(substituted)}",
        "cart now #{money(cart.subtotal)}"
      ]
      |> Enum.reject(&(&1 in [nil, false]))
      |> Enum.join(" · ")

    socket
    |> resolve(result, note)
    |> State.focus_element("cart-button")
  end

  def reject(socket) do
    resolve(socket, %{accepted: false, reason: "rejected"}, "Rejected the proposed basket")
  end

  def timeout(socket, proposal_id) do
    case socket.assigns.proposal do
      %{id: ^proposal_id} -> resolve(socket, %{accepted: false, reason: "timeout"}, nil)
      _ -> socket
    end
  end

  # ---------------------------------------------------------------- derived view data

  @doc "Selected total, per-label subtotals, and budget overage for the panel."
  def totals(proposal) do
    selected = Enum.filter(proposal.lines, & &1.selected)

    by_label =
      selected
      |> Enum.group_by(& &1.label)
      |> Map.new(fn {label, lines} -> {label, sum(lines)} end)

    total = sum(selected)

    %{
      selected_count: length(selected),
      total: total,
      by_label: by_label,
      over_by: over_by(proposal.budget[:total], total),
      over_by_label:
        Map.new(by_label, fn {label, subtotal} ->
          {label, over_by(get_in(proposal.budget, [:by_label, label]), subtotal)}
        end)
    }
  end

  @doc "Lines grouped by label, labelled groups first in first-seen order."
  def groups(proposal) do
    proposal.lines
    |> Enum.group_by(& &1.label)
    |> Enum.sort_by(fn {label, lines} -> {is_nil(label), hd(lines).key} end)
  end

  def chosen(line), do: Enum.find(line.options, &(&1.variant_id == line.chosen_variant_id))

  @doc "The open proposal for `get_store_state`, or nil. Needs the current cart for the projected total."
  def pending(nil, _cart), do: nil

  def pending(proposal, cart) do
    t = totals(proposal)
    projected = projected_cart_total(proposal, t.total, cart.subtotal)

    %{
      proposal_id: proposal.id,
      title: proposal.title,
      line_count: length(proposal.lines),
      selected_count: t.selected_count,
      selected_total: Presenter.number(t.total),
      projected_cart_total: Presenter.number(projected),
      budget: budget_result(proposal.budget, t.total, projected),
      unavailable: proposal.unavailable,
      asked_at_ms: DateTime.to_unix(proposal.asked_at, :millisecond),
      timeout_ms: proposal.timeout_ms
    }
  end

  # ---------------------------------------------------------------- internals

  defp open(socket, proposal) do
    timer = Process.send_after(self(), {:fz_proposal_timeout, proposal.id}, proposal.timeout_ms)
    t = totals(proposal)

    socket
    |> assign(proposal: Map.put(proposal, :timer, timer))
    |> State.log_activity(
      ~s|propose_cart("#{proposal.title}")|,
      "waiting for the shopper · #{length(proposal.lines)} #{plural(length(proposal.lines), "line")} · #{money(t.total)}" <>
        if(proposal.unavailable != [],
          do: " · #{length(proposal.unavailable)} unavailable",
          else: ""
        )
    )
    |> State.focus_element("agent-proposal")
  end

  defp resolve(%{assigns: %{proposal: nil}} = socket, _result, _note), do: socket

  defp resolve(socket, result, human_note) do
    proposal = socket.assigns.proposal
    Process.cancel_timer(proposal.timer)

    result =
      result
      |> Map.put(:proposal_id, proposal.id)
      |> Map.put_new_lazy(:cart, fn -> Presenter.cart_totals(socket.assigns.cart) end)

    socket
    |> push_event("webmcp:result", %{id: proposal.call_id, status: "ok", result: result})
    |> assign(proposal: nil)
    |> log_resolution(result, human_note)
  end

  defp log_resolution(socket, _result, note) when is_binary(note),
    do: State.log_human(socket, note)

  defp log_resolution(socket, %{reason: reason}, nil),
    do: State.log_activity(socket, "propose_cart", "not accepted (#{reason})", :error)

  # -- building ------------------------------------------------------------

  defp build(%{"lines" => lines} = input) when is_list(lines) and lines != [] do
    with :ok <- check(length(lines) <= @max_lines, "at most #{@max_lines} lines"),
         {:ok, mode} <- mode(input["mode"]),
         {:ok, budget} <- budget(input["budget"]),
         {:ok, timeout_ms} <- timeout_ms(input["timeout_ms"]),
         {:ok, raw_lines} <- normalize_lines(lines) do
      {built, unavailable} = resolve_lines(raw_lines)

      if built == [] do
        {:error, "none of the proposed variants exist and are in stock"}
      else
        {:ok,
         %{
           id: "p_" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false),
           title: blank_to_nil(input["title"]) || "Proposed basket",
           subtitle: blank_to_nil(input["subtitle"]),
           mode: mode,
           budget: budget,
           lines: built,
           unavailable: unavailable,
           timeout_ms: timeout_ms,
           asked_at: DateTime.utc_now()
         }}
      end
    end
  end

  defp build(_input), do: {:error, "propose_cart needs a non-empty lines array"}

  defp normalize_lines(lines) do
    normalized =
      Enum.map(lines, fn
        %{"variant_id" => id} = line when is_binary(id) and id != "" ->
          quantity = line["quantity"]

          alternatives =
            line["alternatives"]
            |> List.wrap()
            |> Enum.filter(&(is_map(&1) and is_binary(&1["variant_id"])))
            |> Enum.take(@max_alternatives)
            |> Enum.map(&%{variant_id: &1["variant_id"], reason: blank_to_nil(&1["reason"])})

          %{
            variant_id: id,
            quantity: if(is_integer(quantity) and quantity >= 1, do: quantity, else: 1),
            label: blank_to_nil(line["label"]),
            reason: blank_to_nil(line["reason"]),
            optional: line["optional"] == true,
            alternatives: alternatives
          }

        _ ->
          :invalid
      end)

    if :invalid in normalized do
      {:error, "every line needs a variant_id"}
    else
      # Duplicate variant_ids collapse into one line with summed quantity.
      {:ok,
       normalized
       |> Enum.reduce([], fn line, acc ->
         case Enum.find_index(acc, &(&1.variant_id == line.variant_id)) do
           nil -> acc ++ [line]
           i -> List.update_at(acc, i, &%{&1 | quantity: &1.quantity + line.quantity})
         end
       end)}
    end
  end

  # Resolves each line's variants against the catalog. A line whose proposed
  # variant is missing or sold out but has an in-stock alternative is kept
  # with that alternative preselected and clearly marked; a line with nothing
  # purchasable goes to `unavailable`.
  defp resolve_lines(lines) do
    lines
    |> Enum.with_index()
    |> Enum.reduce({[], []}, fn {line, index}, {ok, bad} ->
      options =
        [%{variant_id: line.variant_id, reason: nil} | line.alternatives]
        |> Enum.uniq_by(& &1.variant_id)
        |> Enum.map(&option(&1))

      proposed = hd(options)

      case Enum.find(options, & &1.available) do
        nil ->
          reason = if proposed.exists, do: "out_of_stock", else: "not_found"
          {ok, bad ++ [%{variant_id: line.variant_id, reason: reason}]}

        first_available ->
          swapped? = not proposed.available

          {ok ++
             [
               %{
                 key: index,
                 proposed_variant_id: line.variant_id,
                 chosen_variant_id: first_available.variant_id,
                 options: options,
                 quantity: line.quantity,
                 label: line.label,
                 reason: line.reason,
                 optional: line.optional,
                 selected: not line.optional,
                 auto_swapped: swapped?
               }
             ], bad}
      end
    end)
  end

  defp option(%{variant_id: id, reason: reason}) do
    case Catalog.get_variant(id, load: [:available, product: [:name, :brand]]) do
      {:ok, v} ->
        %{
          variant_id: v.id,
          product_id: v.product_id,
          exists: true,
          available: v.inventory_quantity > 0,
          name: v.product.name,
          brand: v.product.brand,
          detail: "#{String.capitalize(v.color)} / #{v.size}",
          hex: v.color_hex,
          price: v.price,
          reason: reason
        }

      {:error, _} ->
        %{
          variant_id: id,
          product_id: nil,
          exists: false,
          available: false,
          name: id,
          brand: nil,
          detail: nil,
          hex: nil,
          price: Decimal.new(0),
          reason: reason
        }
    end
  end

  defp mode(nil), do: {:ok, "add"}
  defp mode(mode) when mode in ["add", "replace"], do: {:ok, mode}
  defp mode(_), do: {:error, "mode must be add or replace"}

  defp budget(nil), do: {:ok, %{}}

  defp budget(%{} = budget) do
    total = budget["total"]
    by_label = budget["by_label"]

    with :ok <-
           check(
             is_nil(total) or (is_number(total) and total >= 0),
             "budget.total must be a non-negative number"
           ),
         :ok <-
           check(
             is_nil(by_label) or
               (is_map(by_label) and
                  Enum.all?(by_label, fn {k, v} -> is_binary(k) and is_number(v) and v >= 0 end)),
             "budget.by_label must map labels to non-negative numbers"
           ) do
      {:ok,
       %{
         total: total && decimal(total),
         by_label: Map.new(by_label || %{}, fn {k, v} -> {k, decimal(v)} end)
       }}
    end
  end

  defp budget(_), do: {:error, "budget must be an object"}

  defp timeout_ms(nil), do: {:ok, @default_timeout}

  defp timeout_ms(ms) when is_integer(ms) and ms >= @min_timeout and ms <= @max_timeout,
    do: {:ok, ms}

  defp timeout_ms(_),
    do: {:error, "timeout_ms must be between #{@min_timeout} and #{@max_timeout}"}

  # Two readings of the budget, named so an agent can tell them apart:
  # `selection_over_by` compares the proposed/applied lines alone to the
  # budget; `cart_over_by` compares the whole cart (projected during review,
  # actual at accept) to the same budget.
  defp budget_result(budget, _selection, _cart) when map_size(budget) == 0, do: nil
  defp budget_result(%{total: nil}, _selection, _cart), do: nil

  defp budget_result(%{total: limit}, selection_total, cart_total) do
    %{
      total: Presenter.number(limit),
      selection_over_by: Presenter.number(over_by(limit, selection_total)),
      cart_over_by: Presenter.number(over_by(limit, cart_total))
    }
  end

  @doc "What the cart would total if the current selection were accepted."
  def projected_cart_total(%{mode: "replace"}, selection_total, _cart_subtotal),
    do: selection_total

  def projected_cart_total(_proposal, selection_total, cart_subtotal),
    do: Decimal.add(cart_subtotal, selection_total)

  defp applied_total(applied) do
    Enum.reduce(applied, Decimal.new(0), &Decimal.add(&2, Decimal.from_float(&1.line_total)))
  end

  defp over_by(nil, _total), do: Decimal.new(0)

  defp over_by(limit, total) do
    diff = Decimal.sub(total, limit)
    if Decimal.negative?(diff), do: Decimal.new(0), else: diff
  end

  defp sum(lines) do
    Enum.reduce(lines, Decimal.new(0), fn line, acc ->
      Decimal.add(acc, Decimal.mult(chosen(line).price, line.quantity))
    end)
  end

  defp check(true, _message), do: :ok
  defp check(false, message), do: {:error, message}

  defp decimal(value) when is_integer(value), do: Decimal.new(value)
  defp decimal(value) when is_float(value), do: Decimal.from_float(value)

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp money(%Decimal{} = amount), do: "$" <> Decimal.to_string(Decimal.round(amount, 2), :normal)

  defp plural(1, word), do: word
  defp plural(_, word), do: word <> "s"
end
