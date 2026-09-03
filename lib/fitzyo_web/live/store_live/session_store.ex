defmodule FitzyoWeb.StoreLive.SessionStore do
  @moduledoc """
  Keeps the agent's session state alive across LiveView remounts.

  Members, capability grants, the lookbook, and the plan are all built up
  by the agent over a session and lived only in the LiveView process. A
  reload, a dropped socket, or a full navigation started a fresh process
  with none of it, while the cart (in Postgres, keyed by the session cookie)
  carried on: budgets came back null, the lookbook vanished, and granted
  capabilities silently reverted to the defaults.

  This store holds a snapshot per cart id in a public ETS table. The
  LiveView writes it after every render in which it changed and reads it
  back on mount. Entries expire `ttl_ms` after their last write; the owner
  process sweeps them periodically. It is per node, which is enough for
  the demo: a reconnect lands on the same machine the vast majority of
  the time, and a miss degrades to the old behaviour, never to a wrong
  answer.
  """

  use GenServer

  @table :fitzyo_agent_sessions
  @keys [:members, :capabilities, :lookbook, :plan]
  @default_ttl_ms :timer.hours(2)
  @sweep_ms :timer.minutes(10)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "The socket assigns the store snapshots."
  def keys, do: @keys

  @doc "The stored snapshot for a cart id, or an empty map."
  @spec get(String.t()) :: map()
  def get(cart_id) when is_binary(cart_id) do
    case :ets.lookup(@table, cart_id) do
      [{^cart_id, snapshot, _written_at}] -> snapshot
      [] -> %{}
    end
  end

  @doc "Stores a snapshot, refreshing its expiry."
  @spec put(String.t(), map()) :: :ok
  def put(cart_id, snapshot) when is_binary(cart_id) and is_map(snapshot) do
    :ets.insert(@table, {cart_id, snapshot, System.monotonic_time(:millisecond)})
    :ok
  end

  @doc "Forgets a session, as if it had expired."
  def delete(cart_id) when is_binary(cart_id) do
    :ets.delete(@table, cart_id)
    :ok
  end

  @doc """
  Snapshots the session keys from the socket if they differ from what is
  stored. Attached as an `:after_render` hook, so every change the agent or
  the human makes is captured without each call site remembering to.
  Capability timers are process-specific and are re-armed on restore.
  """
  def persist(socket) do
    cart_id = socket.assigns[:cart_id]

    if is_binary(cart_id) do
      snapshot = snapshot(socket.assigns)
      if snapshot != get(cart_id), do: put(cart_id, snapshot)
    end

    socket
  end

  defp snapshot(assigns) do
    @keys
    |> Map.new(&{&1, Map.get(assigns, &1)})
    |> Map.update!(:capabilities, fn
      grants when is_map(grants) ->
        Map.new(grants, fn
          {tier, %{} = grant} -> {tier, Map.delete(grant, :timer)}
          {tier, nil} -> {tier, nil}
        end)

      other ->
        other
    end)
  end

  # ---------------------------------------------------------------- server

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    Process.send_after(self(), :sweep, @sweep_ms)
    {:ok, %{ttl_ms: ttl_ms}}
  end

  @impl true
  def handle_info(:sweep, state) do
    cutoff = System.monotonic_time(:millisecond) - state.ttl_ms
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", cutoff}], [true]}])
    Process.send_after(self(), :sweep, @sweep_ms)
    {:noreply, state}
  end
end
