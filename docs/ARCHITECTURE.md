# ARCHITECTURE.md — Fitzyo System Design

**Last updated:** March 2026
**Status:** Living document — update when architectural decisions change

---

## 1. Product Overview

Fitzyo is a browser-based AI video workflow builder and asset marketplace.

**The core loop:**
1. User describes a video in natural language
2. Claude generates a visual node graph (the workflow)
3. User refines the graph visually on a SvelteFlow canvas
4. Fitzyo executes the graph — calling AI video APIs, assembling clips, mixing audio
5. Generated video scenes are stored in S3 and assembled into a final cut
6. Users can sell the assets and workflow templates they create in the marketplace

**What makes Fitzyo novel:**
- Natural language → executable workflow graph in ~2 seconds
- Model-agnostic: routes each scene to the optimal AI video API automatically
- Visual workflow IS the business logic — no hidden configuration
- Marketplace assets wire directly into scene nodes — buy and use in one click
- Ash Reactor's compensation/undo chains handle API failures automatically

---

## 2. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  BROWSER                                                            │
│                                                                     │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │  Svelte 5 Components (via live_svelte)                       │  │
│  │                                                              │  │
│  │  WorkflowCanvas     TimelinePanel    AssetPicker             │  │
│  │  (SvelteFlow 1.x)   (clip assembly)  (marketplace)          │  │
│  │                                                              │  │
│  │  ChatPanel          NodeConfigPanel  CreatorStudio           │  │
│  │  (NL input)         (node settings)  (upload + price)       │  │
│  └──────────────────────────────┬───────────────────────────────┘  │
└─────────────────────────────────│───────────────────────────────────┘
                                  │ WebSocket (live_svelte / Phoenix LiveView)
┌─────────────────────────────────▼───────────────────────────────────┐
│  PHOENIX SERVER                                                     │
│                                                                     │
│  Plug Pipelines (HTTP boundary)                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │ :webhook → :stripe_webhook | :video_api_webhook | :user_webhook│ │
│  │ :creator_upload → auth + size + content_type + metadata       │ │
│  │ :api → auth + rate_limit (free | pro tier)                    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  LiveView Layer          Ash Domain Layer      Oban Job Layer       │
│  ┌───────────────┐      ┌────────────────┐   ┌─────────────────┐  │
│  │WorkflowLive   │      │Fitzyo.Workflow  │   │SceneGenWorker   │  │
│  │MarketplaceLive│◀────▶│Fitzyo.Video    │◀─▶│ApprovalWorker   │  │
│  │CreatorLive    │      │Fitzyo.Market   │   │AssetReviewWorker│  │
│  └───────────────┘      │Fitzyo.Accounts │   │RoyaltyWorker    │  │
│                          └───────┬────────┘   └────────┬────────┘  │
│                                  │                     │           │
│  NLP Layer                       │ Ash Reactor         │           │
│  ┌───────────────┐      ┌────────▼────────┐            │           │
│  │NL Generator   │      │GraphCompiler    │            │           │
│  │PromptBuilder  │      │GraphValidator   │◀── ContextServer ──┐   │
│  │StructuredOutput│     │ObanBridge       │◀───────────┘       │   │
│  └───────────────┘      └────────┬────────┘                    │   │
│                                  │                              │   │
│  Spark DSL (compile time)        │ ModelRouter                  │   │
│  ┌───────────────┐      ┌────────▼────────┐                    │   │
│  │NodeStep DSL   │      │Video API Pool   │    NodeContext API  │   │
│  │VideoProvider  │      │Runway / Kling   │◀───────────────────┘   │
│  │ObanWorker DSL │      │Luma / Veo       │                        │
│  │ContextNamespace      └────────┬────────┘                        │
│  │MarketplaceAsset│                                                 │
│  └───────────────┘                                                  │
│                                                                     │
│  Rust NIFs                                                          │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  video_processor   graph_algorithms   asset_processor         │ │
│  └───────────────────────────────────────────────────────────────┘ │
└───────────────────────────────── │ ────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
         PostgreSQL             Tigris            Stripe API
    (workflows, assets,    (video clips,        (purchases,
     purchases, users)      images, audio)       payouts)
```

---

## 3. The Workflow Execution Pipeline

This is the core engine. Understanding this flow is essential.

### 3.1 NL → Graph Generation

```
User prompt (string)
        │
        ▼
Fitzyo.NLP.PromptBuilder
  - Serialises NodeRegistry to token-efficient JSON
  - Trims to Claude's context window via Rust NIF
  - Injects DAG rules ("every workflow starts with a trigger node")
        │
        ▼
Anthropic Claude API (claude-opus-4-5)
  - Structured output enforced via JSON Schema
  - Schema generated dynamically from live NodeRegistry
  - Schema enumerates only valid node type atoms
  - `reasoning` field captures LLM's architectural decisions
        │
        ▼
Fitzyo.Workflow.GraphValidator (via Rust NIF)
  - Checks all node types exist in registry
  - Checks all edge handle names are valid
  - Confirms graph is a DAG (no cycles)
  - Returns specific error messages for bad LLM output
        │
        ▼
Phoenix PubSub broadcast → LiveView → live_svelte → SvelteFlow canvas
```

### 3.2 Graph Compilation → Reactor

```
%{nodes: [...], edges: [...]}   (from SvelteFlow canvas state)
        │
        ▼
Fitzyo.Workflow.GraphCompiler
  - Traverses nodes, builds Reactor.Builder struct
  - Input nodes → Reactor.Builder.add_input/2
  - Step nodes  → Reactor.Builder.add_step/4
  - Edges       → argument dependencies {:result, :step_name}
  - Sets return to terminal node
        │
        ▼
%Reactor{}                       (valid, ready to execute)
```

### 3.3 Execution with Oban Bridge

```
Reactor.run(reactor, inputs, context)
        │
        ├── Concurrent leaf steps execute in parallel
        │
        ├── Steps completing < 1s: run inline in Reactor
        │
        └── Steps needing > 1s (video gen, human approval):
              │
              ▼
            ObanBridge.suspend_for_oban/3
              - Generates unique reactor_ref
              - Stores suspended Reactor state
              - Inserts Oban job with reactor_ref in args
              - Returns {:suspend, reactor_ref} to Reactor
              │
              ▼
            Oban Worker runs (may take minutes)
              - Polls video API / waits for human input
              - Broadcasts progress via PubSub
              │
              ▼
            ObanBridge.resume_reactor/2
              - Fetches suspended Reactor by ref
              - Calls Reactor.resume/2 with result
              - Reactor continues from suspension point
```

### 3.4 Error Handling — Three Tiers

```
Tier 1: Retry
  - Oban worker retries up to max_attempts on transient failures
  - Exponential backoff: 1s, 10s, 100s

Tier 2: Compensate
  - Reactor calls compensate/4 on the failed step
  - Step-specific cleanup (cancel in-flight API job, delete temp S3 file)
  - Returns :ok to continue compensation chain or :retry to retry

Tier 3: Undo
  - Reactor walks backwards through completed steps
  - Each step's undo/4 reverses its side effects
  - Example: payment taken → video gen failed → undo charges customer
```

---

## 4. Node Architecture

### 4.1 Node Categories and Types

**Trigger Nodes** (Oban-backed, durable, can suspend)
| Type | Description | Oban Queue |
|---|---|---|
| `:cron_trigger` | Scheduled execution | :triggers |
| `:webhook_trigger` | External HTTP event | :triggers |
| `:human_approval` | Wait for user decision | :approvals |
| `:form_submission` | Wait for form data | :approvals |
| `:wait` | Fixed duration pause | :triggers |

**Generation Nodes** (AI video APIs via Oban)
| Type | Description | Preferred Model |
|---|---|---|
| `:scene_generator` | Full scene from prompt | ModelRouter decides |
| `:character_animate` | Animate a character ref | Kling O1 |
| `:background_gen` | Generate background image | Flux/SDXL |
| `:lipsync` | Sync audio to character | Veo 3.1 |
| `:vfx_overlay` | Add VFX to existing clip | Runway Gen-4.5 |

**Assembly Nodes** (FFmpeg via Rust NIF, fast)
| Type | Description |
|---|---|
| `:scene_stitch` | Concatenate clips with transitions |
| `:audio_mixer` | Mix background music + dialogue |
| `:clip_trimmer` | Cut clip to duration |
| `:transition` | Single transition between two clips |
| `:final_export` | Encode and upload final cut |

**Data Nodes** (Ash resource actions)
| Type | Description |
|---|---|
| `:asset_loader` | Load asset from marketplace by ID |
| `:prompt_template` | Apply a prompt template with variables |
| `:style_reference` | Apply style from reference images |
| `:s3_asset` | Reference a raw S3 object |

**Control Nodes** (Pure Reactor)
| Type | Description |
|---|---|
| `:conditional` | Route based on boolean expression |
| `:parallel_merge` | Wait for all parallel branches |
| `:loop` | Iterate over a list of inputs |
| `:error_handler` | Catch and handle step errors |

### 4.2 Adding a New Node Type

1. Create `lib/fitzyo/workflow/nodes/my_new_step.ex`
2. Implement `NodeStep` behaviour (`node_definition/0`)
3. Implement `Reactor.Step` (`run/3`, `compensate/4`, `undo/4`)
4. Register in `lib/fitzyo/workflow/node_registry.ex`
5. Create `assets/js/components/nodes/MyNewNode.svelte`
6. Add to `nodeTypes` map in `assets/js/components/WorkflowCanvas.svelte`
7. Write ExUnit tests in `test/fitzyo/workflow/nodes/my_new_step_test.exs`

---

## 5. Asset Marketplace Architecture

### 5.1 Asset Lifecycle

```
Creator uploads file
        │
        ▼
S3Store.upload_asset/3
  - Stores original in private bucket (fitzyo-asset-originals)
  - Generates watermarked preview via AssetProcessor NIF
  - Stores preview in public bucket (fitzyo-asset-previews)
        │
        ▼
Auto-Review Reactor Workflow
  1. QualityAnalysis NIF (resolution, blur, noise)
  2. ContentModeration (Claude API)
  3. AutoTagging (colour extraction NIF + Claude API)
  4. ThumbnailGeneration NIF
  5. CompatibilityCheck (which video models)
  → AutoPublish if all pass
  → HumanApproval node if borderline
        │
        ▼
Asset published to storefront
```

### 5.2 Purchase Flow

```
User clicks "Buy" in AssetPicker
        │
        ▼
LiveView: handle_event("purchase_asset")
        │
        ▼
Ash.create!(Purchase, %{asset_id: id}, actor: user)
        │
        ▼
Stripe.PaymentIntent.create (amount, currency, customer)
        │
        ▼
Client: Stripe.js confirms payment
        │
        ▼
Stripe Webhook → Phoenix endpoint
        │
        ▼
Ash.update!(purchase, :complete, %{stripe_pi_id: pi_id})
        │
        ▼ (after_action callback)
RoyaltyDistributor.distribute/1
  - Creates Royalty record (70% to creator)
  - Schedules Stripe Connect transfer via RoyaltyWorker

S3AccessGrant.provision/1
  - Generates download_key for purchase
  - Returns 24-hour presigned URL to client
```

### 5.3 Tigris Bucket Structure

Tigris is a globally distributed, S3-compatible object storage service with no egress fees, managed natively via `fly storage create` on Fly.io. Buckets are provisioned once via the Fly CLI — credentials are injected as Fly app secrets automatically, no manual configuration needed.

```
fitzyo-asset-originals/    (private, Tigris-managed access)
  assets/{asset_id}/original.{ext}

fitzyo-asset-previews/     (public, globally cached — no CDN needed)
  previews/{asset_id}/preview.{ext}
  previews/{asset_id}/thumbnail.webp

fitzyo-video-clips/        (private)
  workflows/{workflow_id}/clips/{step_name}.mp4

fitzyo-video-exports/      (private, presigned on completion)
  exports/{workflow_id}/final_cut.mp4

fitzyo-video-sources/      (private)
  uploads/{user_id}/{upload_id}.{ext}
```

**Tigris-specific behaviours Fitzyo exploits:**

Tigris decreased file download time by 55–60% in all regions versus S3, simply by changing the ExAws endpoint configuration. Objects are stored close to the uploader then cached close to every subsequent requester — meaning a creator in Tokyo uploading a background pack has it available at low latency to a buyer in London without any CDN configuration.

The `X-Tigris-Prefetch: true` header on list operations eagerly moves all listed objects to your region — used by Fitzyo to pre-warm all scene assets before a workflow execution begins:

```elixir
defmodule Fitzyo.Video.AssetPrefetcher do
  def prefetch_workflow_assets(workflow_id) do
    ExAws.S3.list_objects_v2("fitzyo-video-sources",
      prefix: "uploads/#{workflow_id}/",
      headers: %{"X-Tigris-Prefetch" => "true"}
    )
    |> ExAws.request!()
  end
end
```

Objects under 128KB are cached globally by Tigris automatically — meaning asset thumbnails, prompt templates, and workflow template JSON blobs are served at near-zero latency worldwide with zero configuration. This is exploited for the asset marketplace: all thumbnail images and small JSON workflow templates fall under this threshold.

---

## 6. Spark DSL Extensions

Fitzyo has five custom Spark DSL extensions that eliminate boilerplate, enforce
conventions at compile time, and provide IDE autocomplete for all configuration.
Run `mix spark.cheat_sheets` to regenerate reference documentation after changes.

### 6.1 `Fitzyo.NodeStep` — Node Type Declaration

Used by every workflow node. Generates `node_definition/0` automatically and
registers the node in `NodeRegistry` at compile time via transformers. Verifiers
enforce that trigger nodes have no required inputs and every node has at least
one output handle.

Key transformers:
- `GenerateNodeDefinition` — produces `node_definition/0` from DSL state
- `RegisterInNodeRegistry` — calls `NodeRegistry.register/3` at compile time (runs after GenerateNodeDefinition)

Key verifiers:
- `RequireAtLeastOneOutput` — compile error if no output declared
- `TriggerNodesHaveNoRequiredInputs` — compile error if trigger has required input

### 6.2 `Fitzyo.VideoProvider` — Video API Provider Declaration

Used by all video provider modules (Runway, Kling, Luma, Veo). Generates the full
provider client (`submit/2`, `poll/2`, `cancel/1`, `capabilities/0`) from a
declarative spec. The `webhook` block additionally auto-generates the Phoenix Plug
for HMAC signature verification — no manual plug writing for new providers.

ModelRouter introspects all registered providers via `Fitzyo.VideoProvider.Info`
at runtime to make routing decisions based on declared capabilities.

### 6.3 `Fitzyo.ObanWorker` — Worker Configuration

Used by all Oban workers. Generates the `perform/1` wrapper that enforces timeout,
broadcasts progress on the configured interval via PubSub, and applies the
`on_failure` strategy. The developer only writes the business logic body.

### 6.4 `Fitzyo.ContextNamespace` — Execution Context Access Control

Used alongside `Fitzyo.NodeStep` by any node that reads or writes shared execution
context. Declares which keys a node writes (with type and shape) and which keys
it reads (with the source node declared for dependency tracking).

The `DetectContextConflicts` verifier runs across all compiled modules and raises
a compile error if two nodes declare writes to the same context key path — preventing
silent data corruption from concurrent steps.

### 6.5 `Fitzyo.MarketplaceAsset` — Asset Type Declaration

Used by all marketplace asset type modules. Declares quality requirements (used by
the NIF quality gate), thumbnail strategy (selects the right NIF crop algorithm),
compatible node handles (drives the AssetPicker filter), and pricing tiers.

The `GenerateReviewWorkflow` transformer automatically produces the Reactor
auto-review workflow for each asset type from its quality requirements — no
manual Reactor wiring needed when adding new asset types.

---

## 7. Execution Context Architecture

Every workflow execution has a dedicated `ContextServer` — an ETS-backed GenServer
that owns the mutable shared state for the lifetime of that execution.

### 7.1 Three Tiers of Context

```
Reactor context (immutable, per-step)
  - actor, tenant, current_step.name, retry_count
  - Set at execution start, never modified
  - Reactor's built-in — don't store custom data here

ExecutionContext.shared (mutable, ETS-backed)
  - Any node can read/write via NodeContext API
  - Writes are serialised through ContextServer GenServer
  - Deep merged on write — never replaced wholesale
  - Broadcast to LiveView via PubSub on every write
  - Persisted to DB at completion, suspension, and failure

ExecutionContext.private (mutable, namespaced by step)
  - Only readable/writable by the owning step
  - Used for retry scratch data (e.g. in-flight API job IDs)
  - Not broadcast to LiveView
```

### 7.2 Concurrency Safety

Reactor runs concurrent steps in separate processes. All `NodeContext` writes
are serialised through the `ContextServer` GenServer — there are no race
conditions on shared context, even with parallel branches.

```
SceneNode_1 (process A) ──write(:scenes, 1, clip)──▶ ContextServer (serialised)
SceneNode_2 (process B) ──write(:scenes, 2, clip)──▶       │
SceneNode_3 (process C) ──write(:scenes, 3, clip)──▶       │
                                                      ETS table (consistent)
```

### 7.3 Oban Suspension Persistence

When a Reactor step suspends for an Oban job (video generation, human approval),
the `ContextMiddleware` persists a full context snapshot to the database via the
`halt/1` callback. When the Oban worker resumes the Reactor, the context is
rehydrated from the snapshot — surviving server restarts transparently.

### 7.4 Live Canvas Context Inspector

Every `NodeContext.write` broadcasts `{:context_updated, key_path, value}` to
the `"execution:{id}:context"` PubSub topic. The LiveView subscribes and pushes
updates to the Svelte canvas, where a collapsible `ContextInspector` panel shows
the live state of the shared blackboard with recently-changed keys highlighted.
This is invaluable for debugging complex workflows.

---

## 8. Phoenix Plug Pipeline Architecture

Plugs are used exclusively at the **HTTP boundary**. They never appear inside
workflow execution, asset review, or LiveView handling.

### 8.1 The Three Legitimate Plug Surfaces

**Webhook Ingestion** — three sources, each with its own verification pipeline:

```
POST /webhooks/stripe/*
  :webhook → :stripe_webhook
  VerifyStripeSignature (halts 400 on bad sig)
  ParseStripeEvent

POST /webhooks/video/:provider
  :webhook → :video_api_webhook
  VerifyVideoApiHmac      ← auto-generated by VideoProvider DSL
  ParseVideoJobResult
  ResolveWorkflowExecution

POST /webhooks/triggers/:token
  :webhook → :user_webhook
  AuthenticateWebhookToken
  RateLimitByToken
  ParseUserWebhookPayload
```

**Asset Upload** — staged validation before hitting Ash:

```
POST /creator/upload
  :creator_upload
  AuthenticateCreator
  VerifyCreatorStatus      (must be verified creator)
  ParseMultipartUpload
  EnforceFileSizeLimits    (halts 413 — limits per asset type)
  ValidateContentType      (halts 415 — type must match declared asset_type)
  ExtractUploadMetadata    (dimensions, duration, codec via NIF)
```

**External API** — programmatic access with tier-based rate limiting:

```
/api/v1/* (all)
  :api
  AuthenticateApiToken
  LoadApiActor
  TrackApiUsage

/api/v1/execute, /api/v1/batch (pro tier only)
  :api_pro_tier
  RateLimit (5,000/hour)
  EnableBatchOperations
```

### 8.2 VideoProvider DSL → Auto-Generated Plugs

When a `VideoProvider` declares a `webhook` block, the Spark transformer
automatically generates and registers its HMAC verification plug:

```
# Declared in Fitzyo.Video.Providers.Runway:
webhook do
  signature_header "X-Runway-Signature"
  signature_scheme :hmac_sha256
  secret_env_key   "RUNWAY_WEBHOOK_SECRET"
end

# Auto-generated at compile time:
FitzYoWeb.Plugs.VerifyRunwayHmac
  → reads X-Runway-Signature header
  → verifies HMAC-SHA256 against RUNWAY_WEBHOOK_SECRET
  → halts 400 on failure
```

Adding a new video provider never requires writing a new verification plug.

### 8.3 What Is Explicitly NOT a Plug

| Concern | Why not a Plug | What to use instead |
|---|---|---|
| Workflow step execution | Non-linear, concurrent, needs compensation | Ash Reactor |
| Asset auto-review | Multi-stage pipeline with LLM calls | Reactor workflow |
| LiveView authentication | No Plug.Conn in WebSocket processes | `on_mount` hooks |
| Oban job cross-cutting | Different lifecycle from HTTP | Oban telemetry middleware |

---

Three separate Rustler crates. Each compiles independently.

### 6.1 `native/video_processor`
Key dependencies: `ffmpeg-next`, `image`, `symphonia`

| Function | Scheduler | Purpose |
|---|---|---|
| `extract_thumbnail/3` | DirtyCpu | Single frame from video at timestamp |
| `extract_thumbnail_grid/3` | DirtyCpu | N evenly-spaced frames in one pass |
| `probe_video_metadata/1` | DirtyCpu | Duration, codec, fps, resolution |
| `generate_waveform/2` | DirtyCpu | RMS amplitude array for timeline |
| `add_watermark_to_video/2` | DirtyCpu | Watermark VFX overlay previews |

### 6.2 `native/graph_algorithms`
Key dependencies: `petgraph`

| Function | Scheduler | Purpose |
|---|---|---|
| `validate_dag/2` | normal | Cycle detection + topological sort |
| `find_parallel_groups/2` | normal | Nodes at same execution depth |
| `find_critical_path/2` | normal | Longest path = min completion time |
| `compress_registry_for_prompt/2` | normal | Token-efficient registry serialisation |
| `validate_generated_graph/2` | normal | LLM output structural validation |

### 6.3 `native/asset_processor`
Key dependencies: `image`, `kmeans_colors`, `tiktoken-rs`

| Function | Scheduler | Purpose |
|---|---|---|
| `add_watermark/3` | DirtyCpu | Diagonal watermark on images |
| `generate_asset_thumbnail/4` | DirtyCpu | Smart crop per asset type |
| `analyse_asset_quality/1` | DirtyCpu | Resolution, blur, noise quality gate |
| `extract_dominant_colours/2` | DirtyCpu | k-means palette for auto-tagging |
| `count_tokens/1` | normal | Accurate token count for prompt budget |

---

## 9. Real-Time Architecture (PubSub)

All real-time updates from server → client flow through Phoenix PubSub topics.
LiveView subscribes on mount, pushes updates to Svelte via live_svelte props.

```
Topic: "workflow:{workflow_id}"
  Events:
    {:scene_progress, step_name, percent}   ← generation progress
    {:step_complete, step_name, result}     ← step finished
    {:step_failed, step_name, reason}       ← step error
    {:workflow_complete, result}            ← all done

Topic: "approvals:{user_id}"
  Events:
    {:approval_needed, job_id, prompt, payload}  ← human in the loop

Topic: "assets:{user_id}"
  Events:
    {:asset_reviewed, asset_id, :approved | :rejected}
    {:royalty_paid, amount_cents}
```

---

## 10. Authentication & Authorization

### Authentication
- Ash Authentication with password + OAuth2 (Google, GitHub)
- Session-based for browser, API tokens for webhook endpoints
- Creator verification is a separate step (email + payment method on file)

### Authorization (Ash Policies)
Key policy rules:
- Workflows: read own, no read others (unless shared)
- Assets: anyone reads published, only creator edits own
- Purchases: only buyer reads own purchases
- Royalties: only creator reads own royalties
- Admin role: can publish assets, suspend users, access all data

---

## 11. Build, Deploy & Infrastructure

### Development
```bash
mix phx.server      # Phoenix + Svelte build watcher + NIF compilation
mix test            # Full test suite including NIF tests
mix ash.setup       # Reset DB, run migrations, seed
```

### Production
- **Platform:** Fly.io (multi-region, close to video API endpoints)
- **DB:** Fly Postgres (primary + replica)
- **Object storage:** Tigris (provisioned via `fly storage create`, no egress fees, globally cached)
- **Oban:** Stored in Postgres — no separate Redis
- **Rust NIFs:** Compiled via Rustler Precompiled — no Rust toolchain in prod
- **No CDN needed:** Tigris provides CDN-like global caching automatically
- **Monitoring:** Fly metrics + Oban Web dashboard

### ExAws Configuration for Tigris

```elixir
# config/runtime.exs
config :ex_aws,
  access_key_id:     {:system, "AWS_ACCESS_KEY_ID"},
  secret_access_key: {:system, "AWS_SECRET_ACCESS_KEY"}

config :ex_aws, :s3,
  scheme: "https://",
  host:   System.get_env("AWS_ENDPOINT_URL_S3", "t3.storage.dev"),
  region: "auto"
  # "auto" is required for Tigris — it routes to optimal region
```

On Fly.io, `fly storage create` sets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`,
`AWS_ENDPOINT_URL_S3` (`fly.storage.tigris.dev`), and `BUCKET_NAME` as app secrets
automatically. No manual credential management required.

### Queue Configuration (Oban)
```elixir
queues: [
  video_generation: 5,    # Max 5 concurrent video generation jobs
  asset_review:    10,    # Asset moderation pipeline
  approvals:       50,    # Human-in-the-loop (mostly sleeping)
  triggers:        20,    # Cron + webhook triggers
  royalty_payouts:  5,    # Stripe Connect transfers
  default:         10
]
```

---

## 12. Build Phases

### Phase 1 — Core Workflow Builder (Weeks 1–6)
- Ash resources: Workflow, Node, Edge, WorkflowExecution
- NodeRegistry with 10 initial node types
- GraphCompiler + GraphValidator (Rust NIF)
- SvelteFlow canvas with live_svelte bridge
- Execute simple workflows end-to-end via Reactor

### Phase 2 — NL Generation + Oban Triggers (Weeks 7–10)
- Claude API structured output integration
- NodeRegistry → system prompt serialisation
- Human approval, cron, webhook trigger nodes
- ObanBridge suspend/resume
- Chat panel in Svelte UI

### Phase 3 — Video Engine (Weeks 9–14, overlaps Phase 2)
- S3Store + S3Ref struct
- SceneGeneratorStep with Kling (first provider)
- ModelRouter (add Runway, Luma, Veo)
- VideoProcessor Rust NIF (thumbnails, waveforms)
- Timeline panel in Svelte
- FFmpeg SceneStitch + FinalExport steps

### Phase 4 — Asset Marketplace (Weeks 13–18)
- Asset, Purchase, Royalty, Review Ash resources
- AssetProcessor Rust NIF (watermark, quality analysis)
- Auto-review Reactor workflow
- Stripe purchases + Stripe Connect payouts
- AssetPicker panel wired into scene nodes

### Phase 5 — Polish + Tauri Shell (Weeks 17–20)
- Performance profiling and NIF optimisation
- Tauri 2.0 wrapper for creator desktop app
- Native file picker for bulk uploads
- System tray generation notifications
- Public launch

---

## 13. Key Architectural Decisions & Rationale

| Decision | Rationale |
|---|---|
| Browser-first, Tauri optional | Platform's value (marketplace, sharing) requires the web. Desktop adds polish for creators only. |
| Ash over raw Ecto | Domain modelling, policies, and calculations are the complexity. Ash manages it declaratively. |
| Reactor for execution | The workflow graph IS a Reactor DAG. Compilation is trivial. Compensation is built in. |
| Oban for long-running steps | Video generation takes minutes. Oban provides durability, retries, and crash recovery. |
| Rust NIFs for media ops | Frame extraction, watermarking, waveforms are CPU-bound. Elixir cannot compete here. |
| S3Ref not raw binaries | Video files are 10–500MB. Passing binaries between steps would exhaust memory instantly. |
| Tigris over S3 | S3-compatible so ExAws works unchanged. Globally cached with no CDN config. No egress fees on Fly.io. 55–60% faster downloads globally. `fly storage create` handles all credential management. |
| Single Phoenix app | LiveView + live_svelte covers all real-time needs. No separate API server, no React SPA. |
| petgraph for DAG ops | Topological sort, cycle detection, critical path — all in one battle-tested Rust crate. |
| Model router | No single video API leads in all scenarios. Routing per scene requirement maximises quality. |
| Spark DSL extensions | Compile-time validation, IDE autocomplete, and auto-generation eliminate entire categories of boilerplate and runtime bugs. Five extensions cover nodes, providers, workers, context namespaces, and asset types. |
| Plugs at HTTP boundary only | Plugs are the right tool for stateless HTTP transform chains with short-circuit semantics. Reactor, not Plug, owns all business logic pipelines — they are fundamentally different execution models. |
| ContextServer for shared state | Reactor runs steps concurrently in separate processes. A GenServer serialises all context writes, preventing race conditions while keeping the API ergonomic via NodeContext helpers. |
| VideoProvider DSL → auto-generated plugs | New video providers should never require writing a new webhook verification plug. The DSL generates it from the signature scheme declaration. |
