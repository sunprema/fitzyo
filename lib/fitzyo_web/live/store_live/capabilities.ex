defmodule FitzyoWeb.StoreLive.Capabilities do
  @moduledoc """
  Capability scopes: which tiers of the tool surface an agent may use, and
  the `request_capability` tool an agent calls to earn one.

  Tools are grouped into three tiers. `read` and `suggest` are granted when
  the page loads; `cart` is not. A call into an ungranted tier fails cleanly
  with `CAPABILITY_NOT_GRANTED` and changes nothing. `request_capability` is
  a blocking call in the same mould as `ask_human`: the raw `webmcp:call` is
  intercepted ahead of the AshWebMcp hook, the call id is parked, and the
  reply is pushed when the human allows or denies it, or it times out.

  A grant may carry a scope: a spending ceiling (`max_spend`, enforced
  server-side at every cart write, including accepting a proposal) and an
  expiry (`expires_ms`), after which the tier is revoked mid-session. The
  human can revoke any tier from the agent panel at any time. Grants,
  denials, revocations, and expiries all land in the activity feed. No grant
  enables checkout: there is no checkout tool to grant.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias FitzyoWeb.StoreLive.State

  @default_timeout 120_000
  @min_timeout 5_000
  @max_timeout 600_000
  @min_expiry 10_000
  @max_expiry 86_400_000

  @tiers [
    {"read",
     ~w(get_store_info get_categories search_products filter_products get_product get_variants
        get_size_guide find_matching_variants compare_products get_cart get_store_state)},
    {"suggest",
     ~w(recommend_product clear_annotations present_plan agent_update ask_human focus_product
        focus_filter register_party_member remove_party_member)},
    {"cart", ~w(add_to_cart remove_from_cart update_cart_item clear_cart propose_cart)}
  ]

  @tier_names Enum.map(@tiers, &elem(&1, 0))
  @tier_of Map.new(for {tier, tools} <- @tiers, tool <- tools, do: {tool, tier})
  @default_granted ~w(read suggest)

  @type grant :: %{
          granted_at: DateTime.t(),
          by: :default | :human,
          max_spend: Decimal.t() | nil,
          expires_at: DateTime.t() | nil,
          timer: reference() | nil
        }

  # ---------------------------------------------------------------- vocabulary

  @doc "The tier names in order of trust."
  def tier_names, do: @tier_names

  @doc "Tier name to the tools in it, for `get_store_info`."
  def tiers, do: Map.new(@tiers)

  @doc "The tier a tool belongs to, or nil for tools outside the surface."
  def tier_of("request_capability"), do: "always"
  def tier_of(tool), do: Map.get(@tier_of, tool)

  # ---------------------------------------------------------------- spec

  def spec do
    %{
      name: "request_capability",
      description:
        "Ask the shopper to grant a tier of tools before using it. read and suggest are granted by default; cart (add_to_cart, remove_from_cart, update_cart_item, clear_cart, propose_cart) is not: call this first, say why, and offer a spending ceiling and an expiry so the shopper can scope what they allow. Blocks until they decide or it times out. granted: false means do not touch the cart; ask again only with a different reason or a smaller scope. The ceiling is enforced on every cart write; a write that would push the cart past it fails with CAPABILITY_SCOPE_EXCEEDED. Nothing grants checkout.",
      input_schema: %{
        type: "object",
        required: ["capability"],
        additionalProperties: false,
        properties: %{
          capability: %{type: "string", enum: @tier_names},
          reason: %{
            type: "string",
            description:
              "Why, in the shopper's words, e.g. \"to assemble the beach-trip basket you asked for\""
          },
          scope: %{
            type: "object",
            additionalProperties: false,
            properties: %{
              max_spend: %{
                type: "number",
                minimum: 0,
                description: "Ceiling for the whole cart in the store currency"
              },
              expires_ms: %{
                type: "integer",
                minimum: @min_expiry,
                maximum: @max_expiry,
                description: "Revoke automatically after this long; default is the session"
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
        idempotentHint: true,
        blocking?: true
      }
    }
  end

  # ---------------------------------------------------------------- state

  @doc "Initial grants: read and suggest by default, cart withheld."
  def initial(socket) do
    now = DateTime.utc_now()

    grants =
      Map.new(@tier_names, fn tier ->
        {tier, if(tier in @default_granted, do: default_grant(now), else: nil)}
      end)

    assign(socket, capabilities: grants, capability_request: nil)
  end

  defp default_grant(now),
    do: %{granted_at: now, by: :default, max_spend: nil, expires_at: nil, timer: nil}

  @doc "Whether `tier` is currently granted (and not expired)."
  def granted?(socket, tier), do: not is_nil(socket.assigns.capabilities[tier])

  @doc "The active grant for the tier containing `tool`, if any."
  def grant_for_tool(socket, tool) do
    case tier_of(tool) do
      nil -> nil
      "always" -> nil
      tier -> socket.assigns.capabilities[tier]
    end
  end

  # ---------------------------------------------------------------- transport

  @doc """
  Handles the raw `webmcp:call`: `request_capability` is parked here; any
  other tool in an ungranted tier is refused before the library sees it.
  Expired grants are revoked lazily on the first call after expiry, so the
  timer is belt and braces.
  """
  def intercept("webmcp:call", %{"id" => id, "tool" => "request_capability"} = params, socket) do
    {:halt, request(socket, id, params["input"] || %{})}
  end

  def intercept("webmcp:call", %{"id" => id, "tool" => tool}, socket) do
    socket = sweep_expired(socket)

    case tier_of(tool) do
      nil ->
        {:cont, socket}

      "always" ->
        {:cont, socket}

      tier ->
        if granted?(socket, tier) do
          {:cont, socket}
        else
          error = %{
            success: false,
            code: "CAPABILITY_NOT_GRANTED",
            capability: tier,
            message: "#{tool} needs the #{tier} capability, which the shopper has not granted",
            hint: "call request_capability first"
          }

          {:halt,
           socket
           |> push_event("webmcp:result", %{id: id, status: "error", error: Jason.encode!(error)})
           |> State.log_activity(
             "#{tool}()",
             "blocked: #{tier} capability not granted",
             :error
           )}
        end
    end
  end

  def intercept(_event, _params, socket), do: {:cont, socket}

  @doc "Opens a permission request for `call_id`, or answers it at once when the grant already covers it."
  def request(socket, call_id, input) do
    case build(input) do
      {:ok, request} ->
        current = socket.assigns.capabilities[request.capability]

        if current && covers?(current, request) do
          socket
          |> push_event("webmcp:result", %{
            id: call_id,
            status: "ok",
            result: grant_result(request.capability, current)
          })
          |> State.log_activity(
            ~s|request_capability("#{request.capability}")|,
            "already granted"
          )
        else
          socket
          |> supersede()
          |> FitzyoWeb.StoreLive.Questions.supersede()
          |> FitzyoWeb.StoreLive.Proposals.supersede()
          |> open(Map.put(request, :call_id, call_id))
        end

      {:error, message} ->
        push_event(socket, "webmcp:result", %{
          id: call_id,
          status: "error",
          error: Jason.encode!(%{success: false, code: "INVALID_OPERATION", message: message})
        })
    end
  end

  # A grant covers a request when it is at least as wide: no ceiling, or a
  # ceiling no lower than the one asked for; and no earlier expiry.
  defp covers?(grant, request) do
    spend_ok? =
      is_nil(grant.max_spend) or
        (not is_nil(request.max_spend) and
           Decimal.compare(grant.max_spend, request.max_spend) != :lt)

    expiry_ok? =
      is_nil(grant.expires_at) or
        (not is_nil(request.expires_ms) and
           DateTime.compare(
             grant.expires_at,
             DateTime.add(DateTime.utc_now(), request.expires_ms, :millisecond)
           ) != :lt)

    spend_ok? and expiry_ok?
  end

  # ---------------------------------------------------------------- human decisions

  @doc """
  The human allows the pending request, possibly with an edited ceiling
  (their version wins), or pre-authorises a tier from the panel when no
  request is open.
  """
  def allow(socket, capability, max_spend \\ nil, expires_ms \\ nil)
      when capability in @tier_names do
    request = socket.assigns.capability_request
    for_request? = not is_nil(request) and request.capability == capability

    max_spend =
      cond do
        for_request? and max_spend == :requested -> request.max_spend
        max_spend == :requested -> nil
        true -> max_spend
      end

    expires_ms = if for_request? and is_nil(expires_ms), do: request.expires_ms, else: expires_ms

    socket = revoke_silently(socket, capability)
    now = DateTime.utc_now()

    grant = %{
      granted_at: now,
      by: :human,
      max_spend: max_spend,
      expires_at: expires_ms && DateTime.add(now, expires_ms, :millisecond),
      timer:
        expires_ms &&
          Process.send_after(self(), {:fz_capability_expired, capability, now}, expires_ms)
    }

    socket =
      socket
      |> assign(capabilities: Map.put(socket.assigns.capabilities, capability, grant))
      |> State.log_human("Allowed #{capability} access#{scope_note(grant)}")

    if for_request?, do: resolve(socket, grant_result(capability, grant)), else: socket
  end

  @doc "The human denies the pending request; the tier stays blocked."
  def deny(socket) do
    case socket.assigns.capability_request do
      nil ->
        socket

      request ->
        socket
        |> State.log_human("Denied #{request.capability} access")
        |> resolve(%{granted: false, capability: request.capability, reason: "denied"})
    end
  end

  @doc "The human revokes a granted tier from the panel."
  def revoke(socket, capability) when capability in @tier_names do
    if granted?(socket, capability) do
      socket
      |> revoke_silently(capability)
      |> State.log_human("Revoked #{capability} access")
    else
      socket
    end
  end

  @doc "An expiry timer fired for the grant made at `granted_at`."
  def expire(socket, capability, granted_at) do
    case socket.assigns.capabilities[capability] do
      %{granted_at: ^granted_at} ->
        socket
        |> revoke_silently(capability)
        |> State.log_activity("#{capability} capability", "expired; access revoked", :error)

      _ ->
        socket
    end
  end

  @doc "The pending request's timer fired."
  def timeout(socket, request_id) do
    case socket.assigns.capability_request do
      %{id: ^request_id} = request ->
        socket
        |> State.log_activity("request_capability", "no decision (timeout)", :error)
        |> resolve(%{granted: false, capability: request.capability, reason: "timeout"})

      _ ->
        socket
    end
  end

  @doc "Resolves an open request as superseded (a question or proposal opened)."
  def supersede(%{assigns: %{capability_request: nil}} = socket), do: socket

  def supersede(socket) do
    request = socket.assigns.capability_request

    socket
    |> State.log_activity("request_capability", "no decision (superseded)", :error)
    |> resolve(%{granted: false, capability: request.capability, reason: "superseded"})
  end

  # ---------------------------------------------------------------- enforcement

  @doc """
  Server-side ceiling check for a cart write by the agent: `projected` is
  what the cart would total after the write. Returns a structured error the
  tool can hand back, leaving the cart untouched.
  """
  def check_spend(socket, %Decimal{} = projected) do
    case socket.assigns.capabilities["cart"] do
      %{max_spend: %Decimal{} = ceiling} ->
        if Decimal.compare(projected, ceiling) == :gt do
          {:error,
           %{
             code: "CAPABILITY_SCOPE_EXCEEDED",
             capability: "cart",
             message:
               "This write would take the cart to $#{money(projected)}, past the $#{money(ceiling)} the shopper allowed",
             max_spend: Decimal.to_float(ceiling),
             cart_subtotal: Decimal.to_float(socket.assigns.cart.subtotal),
             projected_total: Decimal.to_float(projected)
           }}
        else
          :ok
        end

      _ ->
        :ok
    end
  end

  @doc "The cart ceiling in force, if any (for the proposal panel)."
  def max_spend(socket) do
    case socket.assigns.capabilities["cart"] do
      %{max_spend: ceiling} -> ceiling
      _ -> nil
    end
  end

  # ---------------------------------------------------------------- state for agents

  @doc "Grants as `get_store_state` reports them."
  def summary(capabilities) do
    Map.new(capabilities, fn
      {tier, nil} ->
        {tier, nil}

      {tier, grant} ->
        {tier,
         %{
           granted_at_ms: DateTime.to_unix(grant.granted_at, :millisecond),
           by: to_string(grant.by),
           max_spend: grant.max_spend && Decimal.to_float(grant.max_spend),
           expires_at_ms: grant.expires_at && DateTime.to_unix(grant.expires_at, :millisecond)
         }}
    end)
  end

  @doc "The open request for `get_store_state`, or nil."
  def pending(nil), do: nil

  def pending(request) do
    %{
      request_id: request.id,
      capability: request.capability,
      reason: request.reason,
      max_spend: request.max_spend && Decimal.to_float(request.max_spend),
      expires_ms: request.expires_ms,
      asked_at_ms: DateTime.to_unix(request.asked_at, :millisecond),
      timeout_ms: request.timeout_ms
    }
  end

  @doc "A short human-readable scope, e.g. \" · up to $600 · 30 min\"."
  def scope_note(%{max_spend: nil, expires_at: nil}), do: ""

  def scope_note(grant) do
    [
      grant.max_spend && "up to $#{money(grant.max_spend)}",
      grant.expires_at && "until #{Calendar.strftime(grant.expires_at, "%H:%M UTC")}"
    ]
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.map_join("", &(" · " <> &1))
  end

  # ---------------------------------------------------------------- internals

  defp open(socket, request) do
    timer = Process.send_after(self(), {:fz_capability_timeout, request.id}, request.timeout_ms)

    socket
    |> assign(capability_request: Map.put(request, :timer, timer))
    |> State.log_activity(
      ~s|request_capability("#{request.capability}")|,
      "waiting for the shopper" <>
        if(request.max_spend, do: " · ceiling $#{money(request.max_spend)}", else: "")
    )
    |> State.focus_element("agent-capability-request")
  end

  defp resolve(%{assigns: %{capability_request: nil}} = socket, _result), do: socket

  defp resolve(socket, result) do
    request = socket.assigns.capability_request
    Process.cancel_timer(request.timer)

    socket
    |> push_event("webmcp:result", %{
      id: request.call_id,
      status: "ok",
      result: Map.put(result, :request_id, request.id)
    })
    |> assign(capability_request: nil)
  end

  defp revoke_silently(socket, capability) do
    case socket.assigns.capabilities[capability] do
      %{timer: timer} when is_reference(timer) -> Process.cancel_timer(timer)
      _ -> :ok
    end

    assign(socket, capabilities: Map.put(socket.assigns.capabilities, capability, nil))
  end

  defp sweep_expired(socket) do
    now = DateTime.utc_now()

    Enum.reduce(socket.assigns.capabilities, socket, fn
      {tier, %{expires_at: %DateTime{} = at, granted_at: granted_at}}, socket ->
        if DateTime.compare(at, now) == :lt, do: expire(socket, tier, granted_at), else: socket

      _, socket ->
        socket
    end)
  end

  defp grant_result(capability, grant) do
    %{
      granted: true,
      capability: capability,
      scope: %{
        max_spend: grant.max_spend && Decimal.to_float(grant.max_spend),
        expires_at_ms: grant.expires_at && DateTime.to_unix(grant.expires_at, :millisecond)
      }
    }
  end

  defp build(%{"capability" => capability} = input) when capability in @tier_names do
    scope = input["scope"] || %{}

    with :ok <- check(is_map(scope), "scope must be an object"),
         {:ok, max_spend} <- max_spend_arg(scope["max_spend"]),
         {:ok, expires_ms} <- expires_arg(scope["expires_ms"]),
         {:ok, timeout_ms} <- timeout_ms(input["timeout_ms"]) do
      {:ok,
       %{
         id: "c_" <> Base.url_encode64(:crypto.strong_rand_bytes(4), padding: false),
         capability: capability,
         reason: blank_to_nil(input["reason"]),
         max_spend: max_spend,
         expires_ms: expires_ms,
         timeout_ms: timeout_ms,
         asked_at: DateTime.utc_now()
       }}
    end
  end

  defp build(_input),
    do: {:error, "request_capability needs a capability of #{Enum.join(@tier_names, ", ")}"}

  defp max_spend_arg(nil), do: {:ok, nil}
  defp max_spend_arg(n) when is_integer(n) and n >= 0, do: {:ok, Decimal.new(n)}
  defp max_spend_arg(n) when is_float(n) and n >= 0, do: {:ok, Decimal.from_float(n)}
  defp max_spend_arg(_), do: {:error, "scope.max_spend must be a non-negative number"}

  defp expires_arg(nil), do: {:ok, nil}

  defp expires_arg(ms) when is_integer(ms) and ms >= @min_expiry and ms <= @max_expiry,
    do: {:ok, ms}

  defp expires_arg(_),
    do: {:error, "scope.expires_ms must be between #{@min_expiry} and #{@max_expiry}"}

  defp timeout_ms(nil), do: {:ok, @default_timeout}

  defp timeout_ms(ms) when is_integer(ms) and ms >= @min_timeout and ms <= @max_timeout,
    do: {:ok, ms}

  defp timeout_ms(_),
    do: {:error, "timeout_ms must be between #{@min_timeout} and #{@max_timeout}"}

  defp check(true, _message), do: :ok
  defp check(false, message), do: {:error, message}

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_), do: nil

  defp money(%Decimal{} = amount), do: Decimal.to_string(Decimal.round(amount, 2), :normal)
end
