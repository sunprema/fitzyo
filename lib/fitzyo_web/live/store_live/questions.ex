defmodule FitzyoWeb.StoreLive.Questions do
  @moduledoc """
  The `ask_human` tool: an agent asks the shopper a question inside the store
  and the tool call stays open until the shopper answers, dismisses it, or it
  times out.

  ash_web_mcp replies to a view tool as soon as `handle_tool/3` returns, so a
  blocking question cannot go through it. Instead `FitzyoWeb.StoreLive`
  intercepts the raw `webmcp:call` event for this one tool before the library
  sees it (`intercept/3`), parks the call id here, and pushes the
  `webmcp:result` itself when the human acts (`resolve/3`). The wire protocol
  is the library's documented one, so agents notice no difference. Only one
  question can be open; a new one supersedes the old.

  Questions are presentation only: nothing in the cart or the filters changes
  by asking, and the shopper keeps full control of the store while one is open.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias FitzyoWeb.StoreLive.State

  @default_timeout 120_000
  @min_timeout 5_000
  @max_timeout 600_000

  @type option :: %{
          id: String.t(),
          label: String.t(),
          description: String.t() | nil,
          product: map() | nil
        }

  @doc "The tool spec, merged into the surface alongside the other view tools."
  def spec do
    %{
      name: "ask_human",
      description:
        "Ask the shopper a question and wait for their answer. Use it when a choice is genuinely theirs — spending more than the budget, which of two products, a size you cannot derive — not for things you can look up or reasonably default. Blocks until they answer, dismiss, or it times out; answered: false means proceed without them or stop, never assume a default. Phrase the question from what the store can see: never restate private context back into it.",
      input_schema: %{
        type: "object",
        required: ["question"],
        additionalProperties: false,
        properties: %{
          question: %{
            type: "string",
            description: "What you need decided, in the shopper's words"
          },
          subtitle: %{
            type: "string",
            description: "One line of context, e.g. \"Budget is $600; this puts you at $743\""
          },
          options: %{
            type: "array",
            minItems: 2,
            maxItems: 4,
            items: %{
              type: "object",
              required: ["id", "label"],
              additionalProperties: false,
              properties: %{
                id: %{type: "string", description: "Returned verbatim in the answer"},
                label: %{type: "string"},
                description: %{type: "string", description: "Trade-off this option implies"},
                product_id: %{type: "string", description: "Renders the option as a product card"},
                variant_id: %{type: "string"}
              }
            }
          },
          allow_multiple: %{type: "boolean", default: false},
          allow_free_text: %{
            type: "boolean",
            default: false,
            description: "Adds an \"Other…\" field"
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

  @doc """
  Handles the raw `webmcp:call` for `ask_human`. Returns `{:halt, socket}` so
  the library never replies to this call; the reply is pushed by `resolve/3`.
  """
  def intercept("webmcp:call", %{"id" => call_id, "tool" => "ask_human"} = params, socket) do
    {:halt, ask(socket, call_id, params["input"] || %{})}
  end

  def intercept(_event, _params, socket), do: {:cont, socket}

  @doc "Opens a question for `call_id`, superseding any open one."
  def ask(socket, call_id, input) do
    case build(input) do
      {:ok, question} ->
        socket
        |> supersede()
        |> FitzyoWeb.StoreLive.Proposals.supersede()
        |> FitzyoWeb.StoreLive.Capabilities.supersede()
        |> open(Map.put(question, :call_id, call_id))

      {:error, message} ->
        push_event(socket, "webmcp:result", %{
          id: call_id,
          status: "error",
          error: Jason.encode!(%{success: false, code: "INVALID_OPERATION", message: message})
        })
    end
  end

  @doc "The shopper picked option ids and/or typed an answer."
  def answer(socket, selected, free_text) when is_list(selected) do
    case socket.assigns.question do
      nil ->
        socket

      question ->
        valid_ids = Enum.map(question.options, & &1.id)
        selected = Enum.filter(selected, &(&1 in valid_ids))
        free_text = blank_to_nil(free_text)

        if selected == [] and is_nil(free_text) do
          socket
        else
          labels =
            question.options
            |> Enum.filter(&(&1.id in selected))
            |> Enum.map(& &1.label)

          summary =
            [Enum.join(labels, ", "), free_text && ~s("#{free_text}")]
            |> Enum.reject(&(&1 in [nil, ""]))
            |> Enum.join(" · ")

          socket
          |> resolve(
            %{answered: true, selected: selected, free_text: free_text},
            "Answered: #{summary}"
          )
        end
    end
  end

  @doc "The shopper declined to answer."
  def dismiss(socket) do
    resolve(socket, %{answered: false, reason: "dismissed"}, "Dismissed the question")
  end

  @doc "The question's timer fired."
  def timeout(socket, question_id) do
    case socket.assigns.question do
      %{id: ^question_id} ->
        resolve(socket, %{answered: false, reason: "timeout"}, nil)

      _ ->
        socket
    end
  end

  @doc "The open question for `get_store_state`, or nil."
  def pending(nil), do: nil

  def pending(question) do
    %{
      question_id: question.id,
      question: question.question,
      subtitle: question.subtitle,
      options: Enum.map(question.options, &Map.take(&1, [:id, :label, :description])),
      allow_multiple: question.allow_multiple,
      allow_free_text: question.allow_free_text,
      asked_at_ms: DateTime.to_unix(question.asked_at, :millisecond),
      timeout_ms: question.timeout_ms
    }
  end

  # ---------------------------------------------------------------- internals

  defp open(socket, question) do
    timer = Process.send_after(self(), {:fz_question_timeout, question.id}, question.timeout_ms)
    question = Map.put(question, :timer, timer)

    socket
    |> assign(question: question)
    |> State.log_activity(
      ~s|ask_human("#{truncate(question.question)}")|,
      "waiting for the shopper"
    )
    |> State.focus_element("agent-question")
  end

  @doc "Resolves an open question as superseded (also used when a proposal opens)."
  def supersede(%{assigns: %{question: nil}} = socket), do: socket

  def supersede(socket),
    do: resolve(socket, %{answered: false, reason: "superseded"}, nil)

  # Pushes the reply for the open question and clears it. `human_note` is the
  # audit entry when a person acted; nil for timeouts and supersession.
  defp resolve(%{assigns: %{question: nil}} = socket, _result, _note), do: socket

  defp resolve(socket, result, human_note) do
    question = socket.assigns.question
    Process.cancel_timer(question.timer)

    result = Map.put(result, :question_id, question.id)

    socket
    |> push_event("webmcp:result", %{id: question.call_id, status: "ok", result: result})
    |> assign(question: nil)
    |> log_resolution(result, human_note)
  end

  defp log_resolution(socket, _result, note) when is_binary(note),
    do: State.log_human(socket, note)

  defp log_resolution(socket, %{reason: reason}, nil),
    do: State.log_activity(socket, "ask_human", "no answer (#{reason})", :error)

  defp build(%{"question" => question} = input) when is_binary(question) and question != "" do
    with {:ok, options} <- build_options(input["options"]),
         {:ok, timeout_ms} <- timeout_ms(input["timeout_ms"]) do
      {:ok,
       %{
         id: "q_" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false),
         question: question,
         subtitle: blank_to_nil(input["subtitle"]),
         options: options,
         allow_multiple: input["allow_multiple"] == true,
         allow_free_text: input["allow_free_text"] == true or options == [],
         timeout_ms: timeout_ms,
         asked_at: DateTime.utc_now()
       }}
    end
  end

  defp build(_input), do: {:error, "ask_human needs a non-empty question"}

  defp build_options(nil), do: {:ok, []}

  defp build_options(options) when is_list(options) and length(options) in 2..4 do
    built =
      Enum.map(options, fn
        %{"id" => id, "label" => label} = option when is_binary(id) and is_binary(label) ->
          %{
            id: id,
            label: label,
            description: blank_to_nil(option["description"]),
            product: product_card(option["product_id"], option["variant_id"])
          }

        _ ->
          :invalid
      end)

    if :invalid in built or built |> Enum.map(& &1.id) |> Enum.uniq() |> length() != length(built) do
      {:error, "each option needs a unique id and a label"}
    else
      {:ok, built}
    end
  end

  defp build_options(_), do: {:error, "options must be a list of 2 to 4 items"}

  # A small, self-contained card so the option still renders if the product
  # changes later; availability is noted as of asking.
  defp product_card(nil, _variant_id), do: nil

  defp product_card(product_id, variant_id) do
    case State.fetch_product(product_id) do
      {:ok, product} ->
        variant = variant_id && Enum.find(product.variants, &(&1.id == variant_id))
        first = List.first(product.variants)

        %{
          product_id: product.id,
          variant_id: variant && variant.id,
          name: product.name,
          brand: product.brand,
          price: (variant && variant.price) || product.price,
          hex: (variant && variant.color_hex) || (first && first.color_hex),
          detail: variant && "#{String.capitalize(variant.color)} / #{variant.size}",
          available: if(variant, do: variant.inventory_quantity > 0, else: product.available)
        }

      {:error, _} ->
        nil
    end
  end

  defp timeout_ms(nil), do: {:ok, @default_timeout}

  defp timeout_ms(ms) when is_integer(ms) and ms >= @min_timeout and ms <= @max_timeout,
    do: {:ok, ms}

  defp timeout_ms(_),
    do: {:error, "timeout_ms must be between #{@min_timeout} and #{@max_timeout}"}

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp truncate(text) when byte_size(text) > 60, do: String.slice(text, 0, 57) <> "…"
  defp truncate(text), do: text
end
