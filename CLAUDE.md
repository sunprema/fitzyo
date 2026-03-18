## Always read this fully before writing any code.

## What is Fitzyo?

Fitzyo is a **browser-based AI video workflow builder** with an integrated asset
marketplace. Users describe video production pipelines in natural language, which
are rendered as interactive node graphs, executed by a server-side workflow engine,
and produce AI-generated video scenes that are assembled into final cuts.

The platform has three interconnected surfaces:

1. **Workflow Builder** — a SvelteFlow canvas where users build, edit and execute
   video pipelines visually or via natural language prompts
2. **Video Engine** — an Ash Reactor execution backend that orchestrates AI video
   generation APIs, FFmpeg assembly, and S3 storage
3. **Asset Marketplace** — a creator economy where users sell background images,
   character references, VFX overlays, prompt templates, and workflow templates

---

## The Stack — Know This Before Touching Any File

| Layer               | Technology                        | Purpose                                                                   |
| ------------------- | --------------------------------- | ------------------------------------------------------------------------- |
| Language            | Elixir + Rust                     | Application + CPU-intensive NIFs                                          |
| Web framework       | Phoenix 1.7+                      | HTTP, WebSockets, LiveView                                                |
| Real-time UI bridge | live_svelte                       | Connects LiveView ↔ Svelte components                                     |
| Frontend canvas     | SvelteFlow (@xyflow/svelte 1.x)   | Workflow node graph, Svelte 5                                             |
| Frontend reactivity | Svelte 5 (Runes)                  | `$state`, `$derived`, `$effect`, `$props`                                 |
| Domain layer        | Ash Framework 3.x                 | Resources, actions, policies, calculations                                |
| Workflow execution  | Ash Reactor                       | DAG-based step execution with compensation                                |
| Background jobs     | Oban Pro                          | Durable job queue, triggers, human-in-loop                                |
| Database            | PostgreSQL (via AshPostgres)      | Primary data store                                                        |
| Object storage      | Tigris (via ExAws, S3-compatible) | All video, image, audio assets — globally cached, no CDN needed           |
| Payments            | Stripe (via stripity_stripe)      | Purchases, royalties, creator payouts                                     |
| AI workflows        | Anthropic Claude API              | NL → workflow graph generation                                            |
| AI video APIs       | Runway, Kling, Luma, Veo          | Scene generation                                                          |
| Native performance  | Rustler NIFs                      | Frame processing, graph algorithms, watermarking                          |
| DSL extensions      | Spark DSL                         | Compile-time validated node, provider, worker, and asset type definitions |
| Desktop (future)    | Tauri 2.0 (Phase 2)               | Optional creator desktop shell                                            |

---

## Project Structure

```
fitzyo/
├── CLAUDE.md                     ← You are here
├── ARCHITECTURE.md               ← Full system design
├── mix.exs
├── config/
│   ├── config.exs
│   ├── dev.exs
│   ├── prod.exs
│   └── runtime.exs               ← S3, Stripe, API keys via System.get_env
├── lib/
│   ├── fitzyo/                   ← Core business logic (no web concerns)
│   │   ├── accounts/             ← User, CreatorProfile (Ash resources)
│   │   ├── workflow/             ← Workflow, Node, Edge, Execution resources
│   │   │   ├── node_registry.ex  ← Central registry — auto-populated by NodeStep DSL
│   │   │   ├── graph_compiler.ex ← nodes/edges → Reactor struct
│   │   │   ├── graph_validator.ex← DAG validation before execution
│   │   │   ├── oban_bridge.ex    ← Reactor ↔ Oban suspend/resume
│   │   │   ├── execution_context.ex ← Shared mutable blackboard struct
│   │   │   ├── context_server.ex    ← ETS-backed GenServer per execution
│   │   │   ├── node_context.ex      ← read/write API used by all NodeSteps
│   │   │   └── nodes/            ← One file per node type
│   │   ├── video/                ← Video generation and assembly
│   │   │   ├── model_router.ex   ← Selects Runway/Kling/Luma/Veo per scene
│   │   │   ├── s3_store.ex       ← All Tigris/S3 operations, S3Ref struct
│   │   │   ├── s3_ref.ex         ← Lightweight Tigris pointer struct
│   │   │   └── providers/        ← One file per video API provider (VideoProvider DSL)
│   │   ├── marketplace/          ← Asset marketplace domain
│   │   │   ├── asset.ex          ← Asset Ash resource
│   │   │   ├── purchase.ex       ← Purchase + royalty distribution
│   │   │   ├── royalty.ex
│   │   │   ├── asset_types/      ← One file per asset type (MarketplaceAsset DSL)
│   │   │   └── review_pipeline.ex← Auto-review Reactor workflow
│   │   └── nlp/                  ← Natural language → workflow
│   │       ├── generator.ex      ← Claude API call, structured output
│   │       └── prompt_builder.ex ← NodeRegistry → system prompt
│   ├── fitzyo_dsl/               ← Spark DSL extensions
│   │   ├── node_step/
│   │   │   ├── dsl.ex            ← Fitzyo.NodeStep.Dsl — node/input/output/config sections
│   │   │   ├── info.ex           ← Generated introspection helpers
│   │   │   └── transformers/
│   │   │       ├── generate_node_definition.ex   ← auto-generates node_definition/0
│   │   │       └── register_in_node_registry.ex  ← auto-registers at compile time
│   │   │   └── verifiers/
│   │   │       ├── require_at_least_one_output.ex
│   │   │       └── trigger_nodes_have_no_required_inputs.ex
│   │   ├── video_provider/
│   │   │   ├── dsl.ex            ← Fitzyo.VideoProvider.Dsl — model/polling/rate_limits
│   │   │   ├── info.ex
│   │   │   └── transformers/
│   │   │       └── generate_provider_client.ex   ← auto-generates submit/poll/cancel/capabilities
│   │   ├── oban_worker/
│   │   │   ├── dsl.ex            ← Fitzyo.ObanWorker.Dsl — queue/retry/progress sections
│   │   │   └── transformers/
│   │   │       └── generate_worker_wrapper.ex    ← timeout, progress broadcast, on_failure
│   │   ├── context_namespace/
│   │   │   ├── dsl.ex            ← Fitzyo.ContextNamespace.Dsl — declares reads/writes
│   │   │   └── verifiers/
│   │   │       └── detect_context_conflicts.ex   ← compile-time collision detection
│   │   └── marketplace_asset/
│   │       ├── dsl.ex            ← Fitzyo.MarketplaceAsset.Dsl — quality/thumbnail/pricing
│   │       └── transformers/
│   │           └── generate_review_workflow.ex   ← auto-generates Reactor review pipeline
│   ├── fitzyo_web/               ← Phoenix web layer
│   │   ├── live/
│   │   │   ├── workflow_live.ex  ← Main canvas LiveView
│   │   │   ├── marketplace_live.ex
│   │   │   └── creator_live.ex
│   │   ├── plugs/                ← Custom plugs (HTTP boundary only)
│   │   │   ├── verify_stripe_signature.ex
│   │   │   ├── verify_video_api_hmac.ex
│   │   │   ├── parse_stripe_event.ex
│   │   │   ├── parse_video_job_result.ex
│   │   │   ├── resolve_workflow_execution.ex
│   │   │   ├── authenticate_webhook_token.ex
│   │   │   ├── enforce_file_size_limits.ex
│   │   │   ├── validate_content_type.ex
│   │   │   ├── authenticate_api_token.ex
│   │   │   └── rate_limit.ex
│   │   ├── controllers/
│   │   │   └── webhook_controller.ex
│   │   ├── components/
│   │   └── router.ex
│   └── fitzyo_workers/           ← Oban worker modules
│       ├── scene_generation_worker.ex
│       ├── human_approval_worker.ex
│       ├── asset_review_worker.ex
│       └── royalty_payout_worker.ex
├── assets/
│   ├── js/
│   │   ├── app.js                ← Phoenix JS entrypoint
│   │   ├── hooks/                ← live_svelte hook registrations
│   │   └── components/           ← Svelte components
│   │       ├── WorkflowCanvas.svelte
│   │       ├── TimelinePanel.svelte
│   │       ├── AssetPicker.svelte
│   │       ├── ChatPanel.svelte  ← NL input
│   │       └── nodes/            ← One .svelte file per node type
│   └── css/
└── native/                       ← Rust NIF crates
    ├── video_processor/          ← Frame extraction, thumbnails, waveforms
    ├── graph_algorithms/         ← DAG validation, topological sort
    └── asset_processor/          ← Watermarking, quality analysis, colour extraction
```

---

## The NodeStep DSL — Read Before Adding Any Node

Every node in the workflow builder uses the `Fitzyo.NodeStep` Spark DSL.
**Never write a raw `node_definition/0` function** — the DSL generates it automatically
at compile time, validates all values, and auto-registers in `NodeRegistry`.

```elixir
defmodule Fitzyo.Video.Nodes.SceneGeneratorStep do
  use Fitzyo.NodeStep       # Spark DSL — generates node_definition/0 + registers
  use Fitzyo.ContextNamespace

  node do
    type        :scene_generator
    label       "Scene Generator"
    category    :generation        # compile error if not a valid category atom
    color       :violet
    icon        "🎬"
    description "Generates a video scene using an AI video API"

    input :prompt,           type: :string,  required: true
    input :background_image, type: :s3_ref,  required: false
    input :duration_seconds, type: :integer, default: 5

    output :clip,      type: :s3_ref, doc: "Generated video clip in Tigris"
    output :thumbnail, type: :s3_ref, doc: "First frame of the clip"
    output :duration,  type: :float,  doc: "Actual clip duration in seconds"

    config do
      option :camera_move, type: :atom,
        values: [:static, :dolly_in, :pan_left, :pan_right, :crane_up, :handheld],
        default: :static
    end
  end

  context_namespace :scenes do
    writes :current_scene, type: :map
    reads  :active_style_pack, from: Fitzyo.Video.Nodes.StyleReferenceStep
  end

  # Only write run/3, compensate/4, undo/4 — everything else is generated
  def run(args, context, _step) do
    # ...
  end
end
```

**DSL compile-time guarantees:**

- Invalid `category`, `color`, or `type` atoms → compile error with clear message
- Trigger nodes with required inputs → compile error
- Missing output handle → compile error
- Context namespace collision with another node → compile error
- `node_definition/0` generated automatically — never write it manually
- Auto-registered in `NodeRegistry` — never add to registry manually

**Adding a new node type checklist:**

1. Create `lib/fitzyo/workflow/nodes/my_step.ex` using `use Fitzyo.NodeStep`
2. Declare `node do ... end` block with inputs, outputs, config
3. Declare `context_namespace do ... end` if node reads/writes shared context
4. Implement `run/3` (and `compensate/4` if the step has side effects)
5. Create `assets/js/components/nodes/MyNode.svelte`
6. Add to `nodeTypes` map in `WorkflowCanvas.svelte`
7. Write tests — the DSL itself is already tested by the framework

---

## Svelte 5 Conventions — Runes Only

All Svelte components use Svelte 5 Runes syntax. Never use Svelte 4 syntax.

```svelte
<!-- ✅ Correct -->
<script>
  let { count = 0, live } = $props();
  let doubled = $derived(count * 2);
  let local = $state('');
  $effect(() => { console.log(count) });
</script>

<!-- ❌ Never use -->
<script>
  export let count = 0;        // use $props()
  $: doubled = count * 2;      // use $derived()
  let local = 'foo';           // use $state() for reactive vars
</script>
```

**SvelteFlow nodes always use `$state.raw()` for nodes and edges** because
SvelteFlow manages their mutation internally:

```svelte
let nodes = $state.raw(workflow.nodes);
let edges = $state.raw(workflow.edges);
```

**Event handlers use HTML attribute syntax** (Svelte 5):

```svelte
<button onclick={handler}>   <!-- ✅ -->
<button on:click={handler}>  <!-- ❌ Svelte 4 syntax -->
```

---

## Execution Context — Rules for All NodeStep Implementations

Every NodeStep has access to a shared mutable execution context via `NodeContext`.
The context is owned by a per-execution `ContextServer` (ETS-backed GenServer).
Declare access in the `context_namespace` DSL block — this is validated at compile time.

```elixir
# Reading shared context
NodeContext.read(context, :key)
NodeContext.read(context, [:scenes, 1, :clip])   # nested path

# Writing shared context
NodeContext.write(context, [:scenes, scene_num], result)
NodeContext.merge(context, %{stats: %{api_calls: 1}})   # deep merge

# Private scratch — namespaced to this step, safe across retries
NodeContext.write_private(context, :job_id, id)
NodeContext.read_private(context, :job_id)
```

**Namespace ownership convention — never write outside your namespace:**

| Namespace            | Owner                         |
| -------------------- | ----------------------------- |
| `:trigger`           | Trigger nodes only            |
| `:scenes`            | SceneGeneratorStep            |
| `:characters`        | CharacterReferenceStep        |
| `:active_style_pack` | StyleReferenceStep            |
| `:approvals`         | HumanApprovalNode             |
| `:stats`             | Any node (increment counters) |

---

## Spark DSL Extensions — Know All Five

Fitzyo has five Spark DSL extensions. Use them — never bypass them with raw structs.

**`Fitzyo.NodeStep` (`use Fitzyo.NodeStep`)**
For all workflow node implementations. Generates `node_definition/0`, auto-registers
in NodeRegistry. See NodeStep DSL section above.

**`Fitzyo.VideoProvider` (`use Fitzyo.VideoProvider`)**
For all video API provider modules (Runway, Kling, Luma, Veo).
Generates `submit/2`, `poll/2`, `cancel/1`, `capabilities/0`.
ModelRouter introspects all providers via `Fitzyo.VideoProvider.Info` at runtime.

```elixir
provider do
  name :kling; api_base "https://api.klingai.com"; env_key "KLING_API_KEY"
  model "kling-2.6" do
    max_duration 10; supports_image_reference true; cost_per_second_usd 0.045
  end
  polling do; interval_ms 2_000; max_attempts 300; end
  webhook do
    signature_header "X-Kling-Signature"  # auto-generates verification plug
    signature_scheme :hmac_sha256
    secret_env_key   "KLING_WEBHOOK_SECRET"
  end
end
```

**`Fitzyo.ObanWorker` (`use Fitzyo.ObanWorker`)**
For all Oban workers. Generates timeout enforcement, progress broadcasting,
and failure handling. You only write the business logic in `perform/1`.

```elixir
worker do
  queue :video_generation; max_attempts 3; timeout :timer.minutes(15)
  retry_strategy do; backoff :exponential; base_delay 1_000; end
  progress do; topic "workflow:{workflow_id}"; interval :timer.seconds(5); end
  on_failure :compensate
end
```

**`Fitzyo.ContextNamespace` (`use Fitzyo.ContextNamespace`)**
Declares which shared context keys a node reads and writes.
Verified at compile time for collisions across all nodes.

**`Fitzyo.MarketplaceAsset` (`use Fitzyo.MarketplaceAsset`)**
For asset type definitions. Declares quality requirements, thumbnail strategy,
compatible node handles, and pricing tiers. Generates the Reactor auto-review
workflow for each asset type automatically.

---

## Phoenix Plug Pipelines — Where They Belong

Plugs are used at the **HTTP boundary only**. They are NOT used inside workflow
execution, asset review pipelines, or LiveView event handling.

**Three legitimate Plug surfaces in Fitzyo:**

1. **Webhook ingestion** — verify signatures, parse events, halt on bad auth
2. **Asset upload** — file size limits, content type validation, malware scan
3. **External API** — token auth, rate limiting per tier, batch enablement

```elixir
# ✅ Correct use of pipelines in router.ex
pipeline :stripe_webhook do
  plug FitzYoWeb.Plugs.VerifyStripeSignature   # halts with 400 on bad sig
  plug FitzYoWeb.Plugs.ParseStripeEvent        # puts event in conn.assigns
end

pipeline :creator_upload do
  plug FitzYoWeb.Plugs.AuthenticateCreator
  plug FitzYoWeb.Plugs.EnforceFileSizeLimits   # halts with 413 if too large
  plug FitzYoWeb.Plugs.ValidateContentType     # halts with 415 if wrong type
  plug FitzYoWeb.Plugs.ExtractUploadMetadata
end

pipeline :api_pro_tier do
  plug FitzYoWeb.Plugs.RateLimit, limit: 5_000, window: :hour
  plug FitzYoWeb.Plugs.EnableBatchOperations
end
```

**Note:** `VideoProvider` DSL with a `webhook` block auto-generates its verification
plug — you never write `VerifyRunwayHmac` or `VerifyKlingHmac` manually.

**Never use Plugs for:**

- Workflow step execution → use Reactor
- Asset review pipeline → use Reactor
- LiveView authentication → use `on_mount` hooks
- Oban job cross-cutting → use Oban telemetry middleware

---

- All resources live in a domain module — never use `Ash.get!` without a domain
- Policies are always explicit — never rely on implicit allow
- Use `calculations` with `expr/1` for derived data — avoid N+1 with `load`
- Actions that touch money (purchase, royalty) must be wrapped in `Ash.Transaction`
- Use `change relate_actor(:creator)` for creator ownership — never set manually
- All public-facing read actions must have explicit `filter` for status/visibility

```elixir
# ✅ Correct — explicit domain, explicit actor
Ash.get!(Fitzyo.Marketplace.Asset, id, domain: Fitzyo.Marketplace, actor: current_user)

# ❌ Never
Fitzyo.Repo.get(Fitzyo.Marketplace.Asset, id)
```

---

## Rust NIF Conventions

All NIFs live in `native/` and are exposed through wrapper modules in `lib/fitzyo/`.
Direct NIF calls should never appear in business logic — always go through the wrapper.

```elixir
# ✅ Correct — through wrapper module
Fitzyo.Video.FrameProcessor.extract_thumbnail(binary, 0, 320)

# ❌ Never call NIF module directly from business logic
Fitzyo.Video.FrameProcessor.Native.extract_thumbnail(binary, 0, 320)
```

**Scheduler rules — non-negotiable:**

- Any NIF that may take > 1ms: `#[rustler::nif(schedule = "DirtyCpu")]`
- Any NIF doing file/network IO: `#[rustler::nif(schedule = "DirtyIo")]`
- Fast, purely computational NIFs (< 1ms): `#[rustler::nif]`

All NIF inputs/outputs use owned types or `Binary<'a>` — never raw pointers.

---

## S3Ref — The Asset Currency

Every asset flowing between Reactor steps is an `%S3Ref{}` — a lightweight pointer.
Raw binaries are NEVER passed between steps or stored in the database.

```elixir
%Fitzyo.Video.S3Ref{
  bucket:           "fitzyo-video-clips",
  key:              "workflows/abc123/clips/scene_1.mp4",
  region:           "us-east-1",
  size_bytes:       4_200_000,
  content_type:     "video/mp4",
  duration_seconds: 5.0
}
```

To give the frontend access, always use `S3Ref.presigned_url/2` with an expiry.
Never expose raw S3 keys or bucket names to the client.

---

## Oban Job Conventions

- Video generation jobs go to the `:video_generation` queue (max 5 concurrency)
- Human approval jobs go to the `:approvals` queue (max 50 concurrency)
- Asset review jobs go to the `:asset_review` queue (max 10 concurrency)
- All workers implement `perform/1` returning `:ok` or `{:error, reason}`
- Jobs that suspend Reactor execution store `reactor_ref` in args
- Always broadcast progress via `Phoenix.PubSub` — never return data in job result

```elixir
defmodule Fitzyo.Workers.SceneGenerationWorker do
  use Oban.Pro.Worker,
    queue: :video_generation,
    max_attempts: 3,
    unique: [period: 60]  # Deduplicate rapid re-submissions
end
```

---

## Environment Variables

All secrets are in runtime.exs via `System.get_env/2`. Never hardcode.

```
ANTHROPIC_API_KEY       Claude API for NL → workflow generation
RUNWAY_API_KEY          Runway Gen-4 video generation
KLING_API_KEY           Kling video generation
LUMA_API_KEY            Luma Ray3 video generation
VEO_API_KEY             Veo video generation
TIGRIS_ACCESS_KEY_ID     Tigris access key (set by `fly storage create` automatically)
TIGRIS_SECRET_ACCESS_KEY Tigris secret key (set by `fly storage create` automatically)
AWS_ACCESS_KEY_ID        Alias — ExAws reads this, maps to TIGRIS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY    Alias — ExAws reads this, maps to TIGRIS_SECRET_ACCESS_KEY
AWS_REGION               Always "auto" for Tigris (globally distributed)
AWS_ENDPOINT_URL_S3      "https://fly.storage.tigris.dev" (on Fly) or "https://t3.storage.dev" (external)
STRIPE_SECRET_KEY       Stripe payments
STRIPE_WEBHOOK_SECRET   Stripe webhook validation
DATABASE_URL            PostgreSQL connection
SECRET_KEY_BASE         Phoenix session key
```

---

## What Claude Code Should Never Do

- **Never** shell out to `ffmpeg` directly — use the Rustler NIF or FFmpex
- **Never** store video binaries in PostgreSQL — always Tigris via S3Ref
- **Never** call video generation APIs synchronously in a LiveView handler —
  always dispatch to an Oban worker
- **Never** bypass Ash actions to write to the DB directly via Ecto
- **Never** expose Tigris keys or presigned URLs without expiry to the client
- **Never** use Svelte 4 syntax in `.svelte` files
- **Never** write a `node_definition/0` function manually — use `Fitzyo.NodeStep` DSL
- **Never** add a node type to `NodeRegistry` manually — the DSL transformer does it
- **Never** write a video provider client manually — use `Fitzyo.VideoProvider` DSL
- **Never** write a `VerifyXxxHmac` plug manually for video providers — DSL generates it
- **Never** use Plugs inside workflow execution, asset review, or LiveView — HTTP boundary only
- **Never** read or write execution context directly via `context.shared` — use `NodeContext`
- **Never** run a Reactor step that takes > 1s without an Oban backing worker
- **Never** put API keys in config files — runtime.exs only

---

## Starting a New Feature — Checklist

1. Does it need a new Ash resource? → Define resource, domain, policies first
2. Does it need a new node type? → Use `Fitzyo.NodeStep` DSL — never write raw struct
3. Does it need a new video provider? → Use `Fitzyo.VideoProvider` DSL
4. Does it need a new Oban worker? → Use `Fitzyo.ObanWorker` DSL
5. Does it need a new asset type? → Use `Fitzyo.MarketplaceAsset` DSL
6. Does it read/write execution context? → Declare in `context_namespace` DSL block
7. Does it need a new Svelte component? → Create in `assets/js/components/nodes/`
8. Does it involve CPU-intensive work? → Check if a Rust NIF is warranted
9. Does it involve an HTTP entry point? → Consider if a Plug pipeline is appropriate
10. Does it involve user-generated assets? → Route through S3Store, return S3Ref
11. Does it involve money? → Wrap in Ash.Transaction, write the test first

---

## Running the Project

```bash
mix deps.get                  # Elixir deps
mix ash.setup                 # Create DB, run migrations, seed
cd assets && npm install      # JS deps including @xyflow/svelte
mix phx.server                # Start Phoenix + Svelte build watcher
```

### Provisioning Tigris Buckets (one-time, on Fly.io)

```bash
# Creates bucket AND automatically sets secrets on your Fly app
fly storage create --name fitzyo-asset-originals
fly storage create --name fitzyo-asset-previews
fly storage create --name fitzyo-video-clips
fly storage create --name fitzyo-video-exports

# Verify buckets exist
fly storage list
```

For local development, use the credentials output by `fly storage create`
and set `AWS_ENDPOINT_URL_S3=https://t3.storage.dev` in your `.env` file.

Rust NIFs compile automatically on `mix compile` via Rustler.
First compile takes ~60 seconds. Subsequent compiles are incremental.

---

## Key Contacts & Resources

- Architecture decisions: see `ARCHITECTURE.md`
- Ash docs: https://hexdocs.pm/ash
- Reactor docs: https://hexdocs.pm/reactor
- Oban Pro docs: https://getoban.pro/docs
- SvelteFlow docs: https://svelteflow.dev
- live_svelte docs: https://github.com/woutdp/live_svelte
- Rustler docs: https://github.com/rusterlium/rustler
- Spark DSL docs: https://hexdocs.pm/spark
- Tigris docs: https://www.tigrisdata.com/docs

To regenerate DSL cheat sheets after adding/modifying extensions:

```bash
mix spark.cheat_sheets
```

<!-- usage-rules-start -->
<!-- usage_rules-start -->

## usage_rules usage

_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should _thoroughly_ consult before taking any
action. These usage rules contain guidelines and rules _directly from the package authors_.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```

## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```

<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->

## usage_rules:elixir usage

# Elixir Core Usage Rules

## Pattern Matching

- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling

- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid

- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design

- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures

- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing

- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->

## usage_rules:otp usage

# OTP Usage Rules

## GenServer Best Practices

- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication

- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance

- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async

- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->
