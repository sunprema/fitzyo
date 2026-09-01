# AshWebMcp Usage Rules

AshWebMcp exposes Ash resource actions (and LiveView UI state) as WebMCP tools
that in-browser agents call via `document.modelContext` /
`navigator.modelContext`, or via a postMessage bridge when embedded in a shell.
Tool calls round-trip over the LiveView socket; the server executes them as
ordinary Ash actions.

## Declaring tools on a resource

- Add the extension: `use Ash.Resource, extensions: [AshWebMcp.Resource]`, then
  declare tools in a `web_mcp do ... end` block.
- `tool :name` maps to the action of the same name; use `action :other` inside
  the block to map to a differently named action. Referencing a missing action
  fails compilation (`AshWebMcp.Verifiers.ValidateTools`).
- Always give tools a `description` — it is what the agent reads to decide
  when to call the tool. Fallback order: tool description → action description
  → the bare tool name.
- Only `:read`, `:create`, and generic `:action` action types are supported.
  `:update` and `:destroy` are NOT supported yet — do not declare tools on
  them; the call will error at runtime.
- Mark anything irreversible with `annotations destructive?: true`. Such calls
  do not execute until a human approves them in the UI (see below).
- Hide server-filled arguments from the agent with
  `exclude_arguments [:actor_id, ...]`. Excluded arguments are omitted from
  the input schema, so supply them server-side (e.g. via changes/preparations
  reading the actor), never expect them in the input.
- Wire names default to `<resource module snake_cased>__<tool name>`
  (e.g. `my_app_notes_note__create_note`), guaranteeing cross-resource
  uniqueness. Set `qualified_name :stable_name` only when you need a pinned,
  stable wire name; the verifier still rejects duplicates within one resource.

```elixir
web_mcp do
  tool :create_note

  tool :find_notes do
    action :list
    description "Search notes by query string"
  end

  tool :purge do
    description "Deletes all notes"
    annotations destructive?: true
  end
end
```

## Exposing tools from a LiveView

- `use AshWebMcp.LiveView, resources: [MyApp.Note, ...]` — registers every
  declared tool of every listed resource on mount and handles `"webmcp:call"`
  events. No extra mount code needed; it installs its own `on_mount` hook.
- Options:
  - `view_tools: MyViewTools` — merge socket-aware tools (see below).
  - `scope: fn socket -> {actor, tenant} end` — defaults to
    `{assigns[:current_user], assigns[:current_tenant]}`. Every call runs with
    `authorize?: true`, so policies apply; set `scope` rather than bypassing
    authorization.
  - `activity_messages: true` — the LiveView receives
    `{AshWebMcp.LiveView, :activity, %{tool: name, status: "ok" | "error"}}`
    per resolved call. Only enable it if you implement a matching
    `handle_info`; unhandled messages crash the view.
  - `approval_timeout:` ms before a pending destructive call auto-denies
    (default 12_000). Keep it below ~15s — the client-side call timeout.
- Render a transport in the template, exactly one of:
  - `<AshWebMcp.Components.bridge />` (colocated hook; requires the
    `:phoenix_live_view` compiler in the consumer's `mix.exs`), or
  - any element with `phx-hook="WebMcp"` after registering the standalone hook
    from `assets/js/web_mcp.js` in `liveSocket` hooks. Use this one when you
    need the origin-allowlisted postMessage bridge or late-injected
    modelContext detection.
- With no transport element rendered, registration events go nowhere and no
  tools are exposed — this is the first thing to check when an agent sees no
  tools.

## Dynamic tool surface

- The advertised tool set is rebuilt by `AshWebMcp.LiveView.refresh_tools/1`.
  Call it (returning the socket) after any state change that should add or
  remove tools. Identical surfaces are a no-op, so call it freely.
- Every registration replaces the whole tool set (native registrations are
  torn down via their abort signals first). Never push a partial
  `"webmcp:register"` yourself — the framework owns that event.

## View tools (socket-aware tools)

- Implement the `AshWebMcp.ViewTools` behaviour for tools that need assigns or
  must drive the UI ("what is selected?", "scroll to X"):
  - `tools/0` for a static list, or `tools/1` (receives the socket) for
    state-dependent specs — define exactly one; `tools/1` wins if both exist.
    Pair `tools/1` with `refresh_tools/1` wherever that state changes.
  - `handle_tool(name, input, socket)` returns `{:ok, result}`,
    `{:ok, result, socket}` (to apply assigns/push_events — required for any
    UI change to be visible), or `{:error, reason}`.
- Spec shape: `%{name:, description:, input_schema:, annotations: (optional)}`
  with a JSON Schema map for `input_schema`. Names share one namespace with
  resource tools — avoid the `<module>__` pattern or collisions.
- Mark destructive view tools with `annotations: %{destructive?: true}` (atom
  or string key both work); they get the same approval gating.

## Destructive-call approval

- A `destructive?: true` call is parked in the
  `@__web_mcp_pending_approval__` assign (`%{id, tool, input, entry, timer}`).
  Render an approval UI from that assign and call
  `AshWebMcp.LiveView.approve_pending/1` or `deny_pending/2` from your own
  click handlers. Nothing executes until approval.
- Only one call can be pending; concurrent destructive calls error immediately
  telling the agent to retry. Timeout auto-denies with an explanatory error.

## Execution semantics

- Inputs arrive as JSON-decoded maps and are cast by the action
  (`for_read` / `for_create` / `for_action`); results are serialized to plain
  maps of public attributes only (Decimal/Date/DateTime → strings, atoms →
  strings). Private attributes never leak; don't rely on relationships or
  calculations appearing in results.
- Errors are formatted with `Exception.message/1` and become the agent-facing
  error string — Ash policy/validation messages are shown to the agent as-is.

## Agent-facing wire protocol (for shells and debugging)

- LiveView → hook events: `"webmcp:register"` (`%{tools: [spec]}`) and
  `"webmcp:result"` (`%{id, status: "ok" | "error", result | error}`).
  Hook → LiveView: `"webmcp:call"` (`%{id, tool, input}`).
- Native transport: each tool is `registerTool`-ed on
  `document.modelContext` and/or `navigator.modelContext` with
  `{name, title, description, inputSchema, annotations, execute}`.
- postMessage bridge (standalone hook, when no modelContext exists): the page
  answers `{type: "tools/list", id}` with `{type: "tools/list:result", id,
  tools}`, `{type: "tools/call", id, tool, input}` with
  `{type: "tools/call:result", id, result | error}`, and broadcasts
  `{type: "tools/changed", tools}` to `window.parent` / `window.opener` on
  every surface change. Set allowed origins via
  `data-webmcp-allowed-origins="https://a,https://b"` on the hook element
  (default: same origin only; `*` allows all — avoid in production).

## Common pitfalls

- Registering the hook but forgetting `use AshWebMcp.LiveView` (or vice versa)
  — both halves are required; neither warns about the other's absence.
- Declaring a tool on an `:update`/`:destroy` action — unsupported, runtime
  error.
- Enabling `activity_messages: true` without a `handle_info` clause — crashes.
- Client-side-only tools (pure browser state: speech voices, permission
  prompts) belong in the hook, not the server: wrap the standalone hook
  (`{...WebMcp, mounted() { this.localTools = {my_tool: fn}; WebMcp.mounted.call(this) }}`)
  and entries in `this.localTools` resolve without a server round-trip.
- Multiple LiveViews on one page each pushing registrations — keep one
  WebMCP-owning LiveView per page; the tool surface is page-global.
- Forgetting `refresh_tools/1` after state that `tools/1` depends on changes —
  the agent keeps seeing a stale tool surface.
