defmodule FitzyoWeb.StoreLive.Lookbook do
  @moduledoc """
  The travel lookbook: an agent's plan laid out as a horizontal timeline of
  days, each with what every person wears that day, rendered by the store
  above the ordinary results grid (`present_lookbook`).

  The agent owns the plan: day labels and activities are opaque strings it
  chose, slots point at variants it picked, and "have" slots are things the
  family already owns, sent as plain text so the retailer never learns the
  wardrobe. The store owns the rendering and the pricing: it resolves each
  variant to a card, marks which slots are already in the cart, notes when
  one item is worn on several days, and totals what is still to buy.

  The human edits it in place: drop a slot, mark it "already have", or add
  it to the cart. Every edit is a human entry in the feed and shows up in
  `get_store_state.lookbook`, so the agent sees the corrected plan rather
  than the one it sent.
  """

  import Phoenix.Component, only: [assign: 2]

  alias FitzyoWeb.StoreLive.State

  @max_days 14
  @max_slots 12
  @statuses ~w(have need picked)

  # ---------------------------------------------------------------- spec

  def spec do
    %{
      name: "present_lookbook",
      description:
        "Lay the trip out as a timeline in the store: one column per day with a label and activities, and one slot per person per item worn that day. A slot is one of three things: status picked, a variant you chose (product_id, optional variant_id); status have, something the family already owns, as plain text (never describe the wardrobe beyond that text); or status need, something you are still looking for, as text or as a bare placeholder with just a label. The store prices each slot, marks what is already in the cart, notes items worn on several days, and totals what is still to buy. The shopper can drop a slot, mark it already owned, or add it to the cart; read get_store_state.lookbook to see their version. Replaces any earlier lookbook; send days: [] to clear it. Presentation only.",
      input_schema:
        object(
          %{
            title: %{type: "string", description: "e.g. \"Hawaii — 7 day lookbook\""},
            subtitle: %{type: "string", description: "e.g. \"Beach, hiking, one luau\""},
            days: %{
              type: "array",
              maxItems: @max_days,
              items:
                object(
                  %{
                    label: %{type: "string", description: "e.g. \"Day 2: Volcanic hike\""},
                    activities: string_array("e.g. [\"hiking\"]"),
                    slots: %{
                      type: "array",
                      maxItems: @max_slots,
                      items:
                        object(
                          %{
                            label: %{type: "string", description: "Who wears it, e.g. \"Dad\""},
                            product_id: %{type: "string"},
                            variant_id: %{type: "string"},
                            text: %{
                              type: "string",
                              description:
                                "For have: what they already own, e.g. \"navy swim trunks\"; for need: what you are still looking for, e.g. \"hiking shorts\". Optional for need."
                            },
                            status: %{
                              type: "string",
                              enum: @statuses,
                              default: "picked",
                              description:
                                "picked: a variant you chose (product_id) · have: already owned (text) · need: still looking (text, or nothing)"
                            },
                            note: %{
                              type: "string",
                              description: "One short line the shopper reads"
                            }
                          },
                          ["label"]
                        )
                    }
                  },
                  ["label", "slots"]
                )
            }
          },
          ["days"]
        ),
      annotations: %{readOnlyHint: false, destructive?: false, idempotentHint: true}
    }
  end

  # ---------------------------------------------------------------- building

  @doc "Validates and prices a lookbook. `{:ok, nil}` clears it."
  def build(%{"days" => []}), do: {:ok, nil}

  def build(%{"days" => days} = input) when is_list(days) do
    with :ok <- check(length(days) <= @max_days, "at most #{@max_days} days"),
         {:ok, days} <- build_days(days) do
      {:ok,
       %{
         id: "lb_" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false),
         title: blank_to_nil(input["title"]) || "Travel lookbook",
         subtitle: blank_to_nil(input["subtitle"]),
         days: days,
         presented_at: DateTime.utc_now()
       }}
    end
  end

  def build(_input), do: {:error, "present_lookbook needs a days array"}

  defp build_days(days) do
    days
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {day, index}, {:ok, acc} ->
      case build_day(day, index) do
        {:ok, built} -> {:cont, {:ok, acc ++ [built]}}
        {:error, message} -> {:halt, {:error, "day #{index + 1}: #{message}"}}
      end
    end)
  end

  defp build_day(%{"label" => label, "slots" => slots} = day, index)
       when is_binary(label) and label != "" and is_list(slots) do
    with :ok <- check(length(slots) <= @max_slots, "at most #{@max_slots} slots"),
         {:ok, slots} <- build_slots(slots) do
      {:ok,
       %{
         key: index,
         label: String.trim(label),
         activities: day["activities"] |> list() |> Enum.map(&String.downcase/1),
         slots: slots
       }}
    end
  end

  defp build_day(_day, _index), do: {:error, "needs a label and a slots array"}

  defp build_slots(slots) do
    slots
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {slot, index}, {:ok, acc} ->
      case build_slot(slot, index) do
        {:ok, built} -> {:cont, {:ok, acc ++ [built]}}
        {:error, message} -> {:halt, {:error, "slot #{index + 1}: #{message}"}}
      end
    end)
  end

  defp build_slot(%{"label" => label} = slot, index) when is_binary(label) and label != "" do
    status = slot["status"] || "picked"
    product_id = blank_to_nil(slot["product_id"])
    text = blank_to_nil(slot["text"])

    with :ok <- check(status in @statuses, "status must be one of #{Enum.join(@statuses, ", ")}"),
         :ok <-
           check(
             status == "need" or product_id != nil or text != nil,
             "needs a product_id (picked) or text (have); only a need slot may have neither"
           ),
         {:ok, product} <- card(product_id, blank_to_nil(slot["variant_id"])) do
      {:ok,
       %{
         key: index,
         label: String.trim(label),
         product: product,
         text: text,
         status: status,
         note: blank_to_nil(slot["note"]),
         edited_by_human: false
       }}
    end
  end

  defp build_slot(_slot, _index), do: {:error, "needs a label"}

  # A small, self-contained card so the slot still renders if the product
  # changes later. A product that does not exist is a hard error: the agent
  # sent a bad id and should know.
  defp card(nil, _variant_id), do: {:ok, nil}

  defp card(product_id, variant_id) do
    case State.fetch_product(product_id) do
      {:ok, product} ->
        variant = variant_id && Enum.find(product.variants, &(&1.id == variant_id))

        if variant_id && is_nil(variant) do
          {:error, "#{product_id} has no variant #{variant_id}"}
        else
          first =
            Enum.find(product.variants, &(&1.inventory_quantity > 0)) ||
              List.first(product.variants)

          {:ok,
           %{
             product_id: product.id,
             variant_id: variant && variant.id,
             name: product.name,
             brand: product.brand,
             price: (variant && variant.price) || product.price,
             hex: (variant && variant.color_hex) || (first && first.color_hex),
             image_url: product.image_url,
             detail: variant && "#{String.capitalize(variant.color)} / #{variant.size}",
             available: if(variant, do: variant.inventory_quantity > 0, else: product.available)
           }}
        end

      {:error, _} ->
        {:error, "no product #{product_id}"}
    end
  end

  # ---------------------------------------------------------------- human edits

  @doc "The shopper drops a slot from a day."
  def remove_slot(socket, day_key, slot_key) do
    edit(socket, day_key, slot_key, fn day, slot ->
      {%{day | slots: Enum.reject(day.slots, &(&1.key == slot.key))},
       "Dropped #{describe(slot)} from #{day.label}"}
    end)
  end

  @doc """
  The shopper marks a slot as something the family already owns (or undoes
  it). An owned variant is owned on every day it is worn, so the change
  applies to each slot carrying the same variant.
  """
  def toggle_have(%{assigns: %{lookbook: nil}} = socket, _day_key, _slot_key), do: socket

  def toggle_have(socket, day_key, slot_key) do
    lookbook = socket.assigns.lookbook

    case slot(lookbook, day_key, slot_key) do
      nil ->
        socket

      slot ->
        status = if slot.status == "have", do: "picked", else: "have"
        variant_id = slot.product && slot.product.variant_id

        same? = fn s ->
          (s.key == slot_key and Enum.any?(lookbook.days, &(&1.key == day_key and s in &1.slots))) or
            (variant_id != nil and s.product != nil and s.product.variant_id == variant_id)
        end

        {days, touched} =
          Enum.map_reduce(lookbook.days, [], fn day, touched ->
            {slots, hit?} =
              Enum.map_reduce(day.slots, false, fn s, hit? ->
                if same?.(s),
                  do: {%{s | status: status, edited_by_human: true}, true},
                  else: {s, hit?}
              end)

            {%{day | slots: slots}, if(hit?, do: touched ++ [day.label], else: touched)}
          end)

        note =
          if status == "have",
            do: "Marked #{describe(slot)} as already owned (#{Enum.join(touched, ", ")})",
            else: "Un-marked #{describe(slot)} as owned (#{Enum.join(touched, ", ")})"

        socket
        |> assign(lookbook: %{lookbook | days: days})
        |> State.log_human(note)
    end
  end

  defp edit(%{assigns: %{lookbook: nil}} = socket, _day_key, _slot_key, _fun), do: socket

  defp edit(socket, day_key, slot_key, fun) do
    lookbook = socket.assigns.lookbook

    with %{} = day <- Enum.find(lookbook.days, &(&1.key == day_key)),
         %{} = slot <- Enum.find(day.slots, &(&1.key == slot_key)) do
      {day, note} = fun.(day, slot)
      days = Enum.map(lookbook.days, fn d -> if d.key == day.key, do: day, else: d end)

      socket
      |> assign(lookbook: %{lookbook | days: days})
      |> State.log_human(note)
    else
      _ -> socket
    end
  end

  @doc "The slot at `{day_key, slot_key}`, or nil."
  def slot(nil, _day_key, _slot_key), do: nil

  def slot(lookbook, day_key, slot_key) do
    with %{} = day <- Enum.find(lookbook.days, &(&1.key == day_key)),
         %{} = slot <- Enum.find(day.slots, &(&1.key == slot_key)) do
      slot
    else
      _ -> nil
    end
  end

  def describe(%{product: %{name: name}, label: label}), do: "#{label}'s #{name}"
  def describe(%{text: text, label: label}) when is_binary(text), do: "#{label}'s #{text}"
  def describe(%{label: label}), do: "#{label}'s item"

  # ---------------------------------------------------------------- derived view data

  @doc """
  What the strip shows beyond the slots: which variants are in the cart,
  which are worn on more than one day, and what is still to buy.
  """
  def view_data(lookbook, cart) do
    in_cart = cart.items |> Enum.map(& &1.variant_id) |> MapSet.new()

    worn_on =
      for day <- lookbook.days,
          slot <- day.slots,
          slot.product && slot.product.variant_id,
          reduce: %{} do
        acc -> Map.update(acc, slot.product.variant_id, [day.label], &(&1 ++ [day.label]))
      end

    to_buy =
      lookbook.days
      |> Enum.flat_map(& &1.slots)
      |> Enum.filter(&buyable?(&1, in_cart))
      |> Enum.uniq_by(&(&1.product.variant_id || &1.product.product_id))

    %{
      in_cart: in_cart,
      worn_on: worn_on,
      to_buy_count: length(to_buy),
      to_buy_total: Enum.reduce(to_buy, Decimal.new(0), &Decimal.add(&2, &1.product.price))
    }
  end

  # Only a pick counts: "have" is owned and "need" is still being looked for.
  defp buyable?(%{status: "picked", product: %{} = product}, in_cart),
    do: product.available and not MapSet.member?(in_cart, product.variant_id)

  defp buyable?(_slot, _in_cart), do: false

  @doc "The lookbook as `get_store_state` reports it, with the human's edits."
  def summary(nil, _cart), do: nil

  def summary(lookbook, cart) do
    data = view_data(lookbook, cart)

    %{
      lookbook_id: lookbook.id,
      title: lookbook.title,
      to_buy_count: data.to_buy_count,
      to_buy_total: Decimal.to_float(Decimal.round(data.to_buy_total, 2)),
      days:
        Enum.map(lookbook.days, fn day ->
          %{
            key: day.key,
            label: day.label,
            activities: day.activities,
            slots:
              Enum.map(day.slots, fn slot ->
                %{
                  key: slot.key,
                  label: slot.label,
                  product_id: slot.product && slot.product.product_id,
                  variant_id: slot.product && slot.product.variant_id,
                  text: slot.text,
                  status: slot.status,
                  in_cart:
                    slot.product != nil and MapSet.member?(data.in_cart, slot.product.variant_id),
                  edited_by_human: slot.edited_by_human
                }
              end)
          }
        end)
    }
  end

  # ---------------------------------------------------------------- internals

  defp check(true, _message), do: :ok
  defp check(false, message), do: {:error, message}

  defp list(nil), do: []
  defp list(value) when is_binary(value), do: [String.trim(value)]

  defp list(values) when is_list(values),
    do:
      values |> Enum.filter(&is_binary/1) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp list(_), do: []

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp object(properties, required) do
    schema = %{type: "object", properties: properties, additionalProperties: false}
    if required == [], do: schema, else: Map.put(schema, :required, required)
  end

  defp string_array(description),
    do: %{type: "array", items: %{type: "string"}, description: description}
end
