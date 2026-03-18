# ROADMAP.md — Fitzyo Development Roadmap

**Approach:** Vertical slices, not horizontal layers.
**Philosophy:** Each slice is independently demonstrable and shippable.
**Rule:** Never build a layer without the slice above and below it working.

---

## Development Philosophy

### Why Vertical Slices

```
❌ Horizontal (avoid)           ✅ Vertical slices (our approach)
─────────────────────           ─────────────────────────────────
Week 1-4:  All Ash resources    Slice 0: Full pipe, hardcoded data
Week 5-8:  All Reactor steps    Slice 1: One node, fully working
Week 9-12: All Oban workers     Slice 2: Full canvas, save/load
Week 13-16: All Svelte UI       Slice 3: NL generation, end-to-end
Week 17+:  Integration          Slice 4: Real video APIs
           (surprises here)     Slice 5: Human-in-the-loop
                                Slice 6: Marketplace
```

Integration surprises discovered in week 17 kill projects.
Integration surprises discovered in week 1 are Tuesday afternoon fixes.

### Frontend / Backend Balance

The ratio shifts as the product matures:

| Slice                | Backend | Frontend | Reason                              |
| -------------------- | ------- | -------- | ----------------------------------- |
| 0 — Walking skeleton | 80%     | 20%      | Proving the pipe works              |
| 1 — One node E2E     | 60%     | 40%      | Reactor/Oban/NIF are the hard parts |
| 2 — Full canvas      | 40%     | 60%      | UX is the hard part                 |
| 3 — NL generation    | 50%     | 50%      | Equal complexity each side          |
| 4 — Real video APIs  | 70%     | 30%      | API integration dominates           |
| 5 — Triggers + HITL  | 60%     | 40%      | Oban bridge is subtle               |
| 6 — Marketplace      | 50%     | 50%      | Rich domain + rich UI               |

### The Mockup Contract

The HTML mockups (`mockups/fitzyo-mockup.html`, `mockups/fitzyo-scene-generator.html`) are not
throwaway wireframes — they are the specification for every Svelte component.

When Claude Code implements a Svelte component, the workflow is:

1. Reference the relevant mockup section for the component
2. Extract exact CSS variables and design tokens
3. Implement with the specified props and events
4. Wire to LiveView — no redesign, no re-negotiation

The mockups define: component states, prop shapes, event names, visual design.

---

## Slice 0 — The Walking Skeleton

**Duration:** Day 1–3 (not a week — do this immediately)
**Goal:** Every layer of the stack talks to every other layer.
**Done when:** A button click in Svelte creates a Postgres record and
the UI updates, without any hardcoded state.

### What to build

```
Phoenix app created (mix phx.new fitzyo)
  ↓
live_svelte installed and configured
  ↓
SvelteFlow renders 3 hardcoded nodes on screen
  ↓
"Ping" button calls live.pushEvent("ping", {})
  ↓
WorkflowLive.handle_event("ping") creates an Ash record
  ↓
PubSub broadcasts {:pong, record_id}
  ↓
LiveView assigns update → live_svelte props update → Svelte shows it
  ↓
Rustler compiles — one trivial NIF function returns "ok"
  ↓
Oban starts — one trivial job logs "hello"
```

### Tasks

**Setup**

- [x] `mix phx.new fitzyo --no-html --no-assets` (we bring our own)
- [x] Add dependencies: `ash`, `ash_postgres`, `reactor`, `oban`, `live_svelte`,
      `rustler`, `ex_aws`, `stripity_stripe`
- [x] Configure AshPostgres, run `mix ash.setup`
- [x] Install live_svelte, configure esbuild for Svelte 5
- [x] Install `@xyflow/svelte` 1.x
- [ ] Configure Oban with basic queues
- [ ] Create first Rustler crate (`native/graph_algorithms`)
      with a single `hello/0` NIF

**Minimal Ash resource**

- [ ] `Fitzyo.Workflow.Workflow` — just `id`, `title`, `inserted_at`
- [ ] `Fitzyo.Workflow` domain with `:create` and `:read` actions
- [ ] Migration and `mix ash.setup`

**Minimal LiveView + Svelte**

- [ ] `WorkflowLive` — mounts, assigns 3 hardcoded nodes
- [ ] `WorkflowCanvas.svelte` — renders SvelteFlow with those nodes
- [ ] "Ping" button → `pushEvent` → `handle_event` → Ash create → PubSub → update

**Verify the pipe**

- [ ] All layers communicate end-to-end
- [ ] Rustler NIF compiles and is callable from Elixir
- [ ] Oban starts and processes a trivial job
- [ ] live_svelte hot reload works in dev

### Deliverable

A browser showing three hardcoded nodes on a dark canvas. A button that
creates a database record and updates the UI without a page refresh.
Ugly. That is fine. The architecture is proven.

### Exit criteria

- [ ] `mix phx.server` starts without errors
- [ ] SvelteFlow canvas renders in the browser
- [ ] One round-trip: Svelte → LiveView → Ash → PubSub → Svelte
- [ ] One Rustler NIF callable from IEx
- [ ] One Oban job executes successfully

---

## Slice 1 — One Node, End to End

**Duration:** Weeks 1–2
**Goal:** The complete execution pipeline working for a single node type.
**Done when:** A mocked SceneGeneratorStep runs through the full
Reactor → Oban → PubSub → Svelte pipeline and shows a thumbnail.

### What to build

```
Spark DSL: Fitzyo.NodeStep extension (core transformer)
  ↓
SceneGeneratorStep (uses the DSL, mocked API response)
  ↓
NodeRegistry (auto-populated by DSL transformer)
  ↓
GraphCompiler (single-node graph → Reactor struct)
  ↓
ObanBridge (suspend/resume contract)
  ↓
SceneGenerationWorker (mocked: returns a fixed MP4 url after 5s)
  ↓
VideoProcessor NIF: extract_thumbnail/3 on the returned clip
  ↓
S3Store + Tigris: store the clip, return S3Ref
  ↓
PubSub: {:step_complete, step_name, result} → LiveView
  ↓
SceneNode.svelte: idle → generating (progress bar) → complete (thumbnail)
```

### Tasks

**Spark DSL — NodeStep extension**

- [ ] `Fitzyo.NodeStep.Dsl` — `node/input/output/config` sections
- [ ] `Fitzyo.NodeStep.Transformers.GenerateNodeDefinition`
- [ ] `Fitzyo.NodeStep.Transformers.RegisterInNodeRegistry`
- [ ] `Fitzyo.NodeStep.Verifiers.RequireAtLeastOneOutput`
- [ ] `Fitzyo.NodeStep.Verifiers.TriggerNodesHaveNoRequiredInputs`
- [ ] `Fitzyo.NodeStep.Info` — generated introspection helpers

**Ash resources**

- [ ] `Fitzyo.Workflow.Node` — id, type, label, position, data (jsonb), status
- [ ] `Fitzyo.Workflow.WorkflowExecution` — id, workflow_id, status, started_at
- [ ] Migrations

**SceneGeneratorStep**

- [ ] Implement using `Fitzyo.NodeStep` DSL
- [ ] `run/3` calls `ObanBridge.suspend_for_oban/3` — does NOT call video API yet
- [ ] `compensate/4` cancels the in-flight job

**ObanBridge**

- [ ] `Fitzyo.Workflow.ObanBridge.suspend_for_oban/3`
- [ ] `Fitzyo.Workflow.ObanBridge.resume_reactor/2`
- [ ] `Fitzyo.Workflow.SuspendedReactors` ETS store

**SceneGenerationWorker**

- [ ] Uses `Fitzyo.ObanWorker` DSL (build minimal version of this DSL)
- [ ] Mocked: `Process.sleep(5_000)` then returns a fixed S3Ref
- [ ] Broadcasts `{:scene_progress, step_name, percent}` every second
- [ ] Calls `ObanBridge.resume_reactor/2` on completion

**Rust NIF — VideoProcessor**

- [ ] `native/video_processor` crate with `ffmpeg-next`
- [ ] `extract_thumbnail/3` — DirtyCpu scheduler
- [ ] Elixir wrapper: `Fitzyo.Video.FrameProcessor`

**S3Store + S3Ref**

- [ ] `%Fitzyo.Video.S3Ref{}` struct
- [ ] `Fitzyo.Video.S3Store.store_from_url/2`
- [ ] `Fitzyo.Video.S3Store.download_binary/1`
- [ ] `S3Ref.presigned_url/2`
- [ ] Tigris ExAws config in `runtime.exs`

**ContextServer**

- [ ] `Fitzyo.Workflow.ExecutionContext` struct
- [ ] `Fitzyo.Workflow.ContextServer` GenServer
- [ ] `Fitzyo.Workflow.NodeContext` API (read/write/merge/private)
- [ ] `Fitzyo.Workflow.ContextMiddleware` Reactor middleware

**GraphCompiler (single-node)**

- [ ] Compiles a single `:scene_generator` node to a Reactor struct
- [ ] Injects `execution_id` into Reactor context
- [ ] Starts `ContextServer` for the execution

**LiveView wiring**

- [ ] `WorkflowLive.handle_event("execute_workflow")` → GraphCompiler → Reactor.run
- [ ] Subscribe to `"workflow:{id}"` PubSub topic on mount
- [ ] `handle_info({:scene_progress, ...})` → update assigns
- [ ] `handle_info({:step_complete, ...})` → update assigns

**Svelte components**

- [ ] `SceneNode.svelte` — matches scene-generator mockup design
  - Props: `{data: {status, progress, thumbnail_url, model, duration}}`
  - States: idle, generating (progress bar + animation), complete (thumbnail)
- [ ] Wire `nodeTypes` in `WorkflowCanvas.svelte`
- [ ] Progress animation matches mockup amber pulsing border

### Deliverable

Click "Run" on a single hardcoded scene node. Watch it animate through
pending → generating with a live progress counter → complete with a
thumbnail extracted from the mocked clip. The full pipeline in action.

### Exit criteria

- [ ] `SceneGeneratorStep.node_definition/0` is generated by DSL, not handwritten
- [ ] `NodeRegistry` auto-populated — confirmed via `NodeRegistry.all_nodes/0` in IEx
- [ ] ObanBridge suspend/resume works — Reactor suspends, Oban resumes it
- [ ] `extract_thumbnail/3` NIF runs on DirtyCpu scheduler — confirmed via `:observer`
- [ ] S3Ref stored in Tigris (or local mock) and presigned URL accessible
- [ ] ContextServer holds execution state — confirmed via `ContextServer.snapshot/1`
- [ ] SceneNode.svelte animates correctly through all three states
- [ ] No raw binaries passed between Reactor steps (only S3Refs)

---

## Slice 2 — The Full Canvas

**Duration:** Weeks 3–4
**Goal:** A fully interactive workflow canvas with persistence.
**Done when:** User can drag nodes, connect them, save, reload, and execute
a multi-node workflow.

### What to build

```
NodePalette populated from NodeRegistry
  ↓
All initial node types implemented (DSL, mocked run/3)
  ↓
GraphValidator Rust NIF — cycle detection on every edit
  ↓
GraphCompiler handles multi-node graphs with edges
  ↓
Ash persists graph JSON — save and load
  ↓
Canvas toolbar, minimap, zoom/pan
  ↓
Config panel wired to selected node
  ↓
Execution progress panel
  ↓
Timeline strip (static — shows nodes in topo order)
```

### Tasks

**Remaining node types (DSL + mocked run/3)**

- [ ] Trigger: `:webhook_trigger`, `:cron_trigger`, `:wait`
- [ ] Generation: `:character_animate`, `:background_gen`, `:vfx_overlay`
- [ ] Assembly: `:scene_stitch`, `:audio_mixer`, `:clip_trimmer`, `:final_export`
- [ ] Data: `:asset_loader`, `:prompt_template`, `:style_reference`
- [ ] Control: `:conditional`, `:parallel_merge`

**GraphValidator Rust NIF**

- [ ] `native/graph_algorithms` crate with `petgraph`
- [ ] `validate_dag/2` — cycle detection + topological sort
- [ ] `find_parallel_groups/2` — nodes at same execution depth
- [ ] `find_critical_path/2` — longest path for ETA estimate
- [ ] Called on every `onNodesChange` / `onEdgesChange` in Svelte
- [ ] Returns specific error messages shown on canvas

**GraphCompiler — multi-node**

- [ ] Handles arbitrary node/edge graphs
- [ ] Maps edges to Reactor argument dependencies
- [ ] Sets return node (terminal node detection)
- [ ] Validates before compile — rejects invalid graphs with clear errors

**Ash persistence**

- [ ] `Fitzyo.Workflow.Workflow` — full schema with nodes/edges jsonb
- [ ] `:save` action — upserts graph state
- [ ] `:load` action — rehydrates from DB
- [ ] Auto-save on canvas change (debounced 2s)

**Svelte canvas — full feature**

- [ ] `NodePalette.svelte` — grouped by category, populated from
      `node_registry` prop (serialised `NodeRegistry.all_nodes/0`)
- [ ] Drag from palette → new node on canvas
- [ ] `NodeConfigPanel.svelte` — shows config for selected node,
      matches right-panel in mockup
- [ ] `ExecutionProgressPanel.svelte` — floating left panel
- [ ] `TimelineStrip.svelte` — topological order, pending clips
- [ ] Minimap via SvelteFlow `<MiniMap />` component
- [ ] Canvas toolbar (select, pan, zoom, fit)
- [ ] Validation errors shown as node border highlights

**Remaining Svelte node components**

- [ ] `TriggerNode.svelte` — amber theme, clock/webhook icons
- [ ] `AssemblyNode.svelte` — blue theme
- [ ] `DataNode.svelte` — teal theme
- [ ] `ControlNode.svelte` — gray theme
- [ ] All match the established dark design system

### Deliverable

Full interactive canvas. Drag nodes from palette, connect them, save,
refresh the page, reload the same graph. Execute a 3-node workflow
(trigger → scene → export) with mocked steps and watch all three nodes
animate through their states.

### Exit criteria

- [ ] All 15 node types in palette, all draggable to canvas
- [ ] Graph saved to Postgres on every change (debounced)
- [ ] Graph reloads correctly after page refresh
- [ ] Cycle detection fires and highlights the problematic edge
- [ ] Multi-node execution: all nodes animate in correct order
- [ ] Parallel nodes animate simultaneously (Reactor concurrency visible)
- [ ] Config panel shows correct fields per node type

---

## Slice 3 — Natural Language Generation

**Duration:** Week 5
**Goal:** Type a sentence, get a working executable workflow graph.
**Done when:** NL input → valid graph on canvas → user can run it.

### What to build

```
NodeRegistry → token-efficient prompt string (Rust NIF)
  ↓
Claude API call with JSON Schema structured output
  ↓
GraphValidator validates LLM output
  ↓
Generated graph renders on canvas with animation
  ↓
Conversational refinement: "add error handling" → updates graph
  ↓
ChatPanel.svelte — prompt input + message history + suggestions
```

### Tasks

**Rust NIF — token utilities**

- [ ] `compress_registry_for_prompt/2` in `native/graph_algorithms`
- [ ] `validate_generated_graph/2` — structural LLM output validation
- [ ] `count_tokens/1` — tiktoken-rs for prompt budget enforcement

**NLP.PromptBuilder**

- [ ] `Fitzyo.NLP.PromptBuilder.build_system_prompt/0`
      — serialises NodeRegistry to compact JSON
      — injects DAG rules and node handle documentation
      — enforces token budget via NIF
- [ ] `Fitzyo.NLP.GraphSchema.json_schema/0`
      — generated dynamically from live NodeRegistry
      — enumerates only valid node type atoms
      — includes `reasoning` field

**NLP.Generator**

- [ ] `Fitzyo.NLP.Generator.generate/1` — Claude API call
- [ ] `Fitzyo.NLP.Generator.refine/2` — refine existing graph
- [ ] Structured output via JSON Schema enforcement
- [ ] `GraphValidator.validate/1` on all LLM output before returning
- [ ] `Task.start` + PubSub for async generation (non-blocking LiveView)

**LiveView**

- [ ] `handle_event("generate", %{"prompt" => prompt})`
- [ ] `handle_event("refine", %{"instruction" => instruction})`
- [ ] `handle_info({:graph_generated, graph})` → update canvas assigns
- [ ] `handle_info({:generation_failed, reason})` → show error

**Svelte components**

- [ ] `ChatPanel.svelte` — matches left chat panel in main mockup
  - NL textarea with Enter-to-generate
  - Message history (user prompts + generation confirmations)
  - Suggestion chips ("add error handling", "parallelise fetches")
  - Generating spinner state
- [ ] `ReasoningPanel.svelte` — toggleable overlay on canvas showing
      LLM reasoning field ("why this graph?")
- [ ] Canvas graph animation — nodes appear one by one with stagger

### Deliverable

The headline demo moment. Type: "Monitor for new signups, enrich
with Clearbit, score leads, notify Slack if score > 80."
Watch the graph appear on the canvas in ~2 seconds. Click "Show reasoning"
to see the LLM's architectural decisions. Refine: "add a fallback if
Clearbit is down." Watch the graph update. Hit Run.

### Exit criteria

- [ ] Generation completes in < 3s for a 5-node workflow
- [ ] Generated graphs always pass `GraphValidator` (no invalid node types)
- [ ] `reasoning` field displayed in ReasoningPanel
- [ ] Refinement preserves unchanged nodes, modifies only what was asked
- [ ] Token budget never exceeded — NIF compression works
- [ ] Invalid LLM output is retried once, then shows a clear error message
- [ ] Graph animation feels smooth (staggered node appearance)

---

## Slice 4 — Real Video APIs

**Duration:** Weeks 6–7
**Goal:** Real AI-generated video clips appearing in the timeline.
**Done when:** A scene node generates a real video clip via Kling,
stores it in Tigris, and shows a real thumbnail in the canvas.

### What to build

```
VideoProvider DSL — Fitzyo.VideoProvider extension
  ↓
Kling provider implementation (first real API)
  ↓
Real SceneGenerationWorker — polls Kling until complete
  ↓
ModelRouter — routes based on declared capabilities
  ↓
VideoProcessor NIF — real thumbnail + waveform extraction
  ↓
SceneStitch step — FFmpeg via FFmpex
  ↓
FinalExport — encode + upload to Tigris
  ↓
Timeline panel — real clip thumbnails + waveforms
  ↓
Scene Generator screen — matches fitzyo-scene-generator.html mockup
```

### Tasks

**VideoProvider DSL**

- [ ] `Fitzyo.VideoProvider.Dsl` — model/polling/rate_limits/webhook sections
- [ ] `Fitzyo.VideoProvider.Transformers.GenerateProviderClient`
      — generates `submit/2`, `poll/2`, `cancel/1`, `capabilities/0`
- [ ] `Fitzyo.VideoProvider.Transformers.GenerateWebhookPlug`
      — auto-generates HMAC verification plug from `webhook` block
- [ ] `Fitzyo.VideoProvider.Info` — runtime introspection for ModelRouter

**Kling provider**

- [ ] `Fitzyo.Video.Providers.Kling` using `VideoProvider` DSL
- [ ] Real `submit/2` — calls Kling API
- [ ] Real `poll/2` — polls job status
- [ ] Real `cancel/1` — cancels in-flight job
- [ ] Error handling — rate limits, timeouts, API errors

**ModelRouter**

- [ ] `Fitzyo.Video.ModelRouter.select_model/1`
- [ ] Introspects all providers via `VideoProvider.Info`
- [ ] Routes `:image_reference` tasks to Kling
- [ ] Fallback to default model on provider unavailability

**Real SceneGenerationWorker**

- [ ] Replaces mocked worker from Slice 1
- [ ] Submits to Kling via ModelRouter
- [ ] Polls every 2s with exponential backoff on failure
- [ ] Broadcasts real progress percentages via PubSub
- [ ] Downloads completed clip URL → `S3Store.store_from_url/2` → Tigris
- [ ] Extracts thumbnail via `FrameProcessor.extract_thumbnail/3` NIF
- [ ] Resumes Reactor with real `%S3Ref{}`

**VideoProcessor NIF — complete**

- [ ] `extract_thumbnail/3` — single frame (already in Slice 1)
- [ ] `extract_thumbnail_grid/3` — N evenly-spaced frames
- [ ] `probe_video_metadata/1` — duration, codec, fps, resolution
- [ ] `generate_waveform/2` — RMS amplitude array for timeline

**SceneStitch step**

- [ ] `Fitzyo.Video.Nodes.SceneStitchStep`
- [ ] FFmpeg filter graph via FFmpex
- [ ] `TransitionBuilder` — dissolve, cut, wipe transitions
- [ ] Downloads clips from Tigris → temp files → FFmpeg → upload result

**FinalExport step**

- [ ] `Fitzyo.Video.Nodes.FinalExportStep`
- [ ] Encodes to H.264 / H.265 via FFmpex
- [ ] Uploads final cut to `fitzyo-video-exports` bucket
- [ ] Returns presigned URL with 24h expiry

**Webhook pipelines**

- [ ] `FitzYoWeb.Plugs.VerifyKlingHmac` — auto-generated by DSL
- [ ] Webhook route wired in router
- [ ] `WebhookController.video_job_complete/2` — resumes Reactor

**Scene Generator screen**

- [ ] `SceneGeneratorLive` — dedicated LiveView for node detail
- [ ] Navigated to from canvas via node double-click
- [ ] `SceneGeneratorScreen.svelte` — matches `fitzyo-scene-generator.html`
      exactly: iteration strip, model selector, camera buttons, asset slots
- [ ] Real video preview when clip is complete
- [ ] "Use this" wires the selected iteration back to the workflow

**Timeline panel — real clips**

- [ ] Thumbnails from `VideoProcessor.extract_thumbnail/3` NIF
- [ ] Waveforms rendered as SVG from `generate_waveform/2` NIF
- [ ] Hover-to-preview via `<video>` element
- [ ] Topological ordering via `find_critical_path/2` NIF

### Deliverable

The first time you see an AI-generated video clip appear in your own canvas.
Type "a macro close-up of watch gears" → graph generates → click Run →
wait ~60s → a real clip thumbnail appears in the SceneNode → timeline
shows the real clip. This is the moment the product becomes real.

### Exit criteria

- [ ] Real Kling API called — confirmed in Kling dashboard
- [ ] Clip stored in Tigris — confirmed via `fly storage list`
- [ ] Real thumbnail displayed in SceneNode (not a placeholder)
- [ ] Real thumbnail displayed in timeline
- [ ] SceneStitch produces a valid concatenated MP4
- [ ] FinalExport produces a downloadable 4K H.264 file
- [ ] Webhook verification auto-generated by VideoProvider DSL
- [ ] ModelRouter correctly routes image-reference tasks to Kling

---

## Slice 5 — Trigger Nodes + Human-in-the-Loop

**Duration:** Week 8
**Goal:** Workflows that pause for real-world events and human decisions.
**Done when:** A workflow pauses at an approval node, shows inline
approve/reject buttons, and resumes correctly on either path.

### What to build

```
HumanApprovalWorker — Oban snooze/resume pattern
  ↓
HumanApprovalNode.svelte — pulsing amber, inline approve/reject
  ↓
CronTrigger — Oban cron plugin fires Reactor on schedule
  ↓
WebhookTrigger — Plug pipeline → Oban → Reactor
  ↓
WaitNode — Oban scheduled_at delay
  ↓
ContextMiddleware.halt/1 — persists context snapshot to DB on suspend
  ↓
ObanBridge.reload_and_resume/2 — survives server restart
```

### Tasks

**HumanApprovalWorker**

- [ ] `Fitzyo.Workers.HumanApprovalWorker` using `ObanWorker` DSL
- [ ] First run: broadcasts `{:approval_needed, job_id, prompt, payload}`
      to `"approvals:{user_id}"` PubSub topic, then `{:snooze, {24, :hour}}`
- [ ] On `["approved"]` tag: resumes Reactor with `{:ok, %{approved: payload}}`
- [ ] On `["rejected"]` tag: resumes Reactor with `{:ok, %{rejected: payload}}`
- [ ] On `["timed_out"]` tag: resumes Reactor with `{:ok, %{timed_out: true}}`

**HumanApprovalStep**

- [ ] `Fitzyo.Workflow.Nodes.HumanApprovalStep` using `NodeStep` DSL
- [ ] Three output handles: `:approved`, `:rejected`, `:timed_out`
- [ ] Calls `ObanBridge.suspend_for_oban/3` with `HumanApprovalWorker`

**LiveView approval handling**

- [ ] Subscribe to `"approvals:{current_user.id}"` on mount
- [ ] `handle_event("approve", %{"job_id" => id})` → tag + resume Oban job
- [ ] `handle_event("reject", %{"job_id" => id})` → tag + resume Oban job

**HumanApprovalNode.svelte**

- [ ] Pulsing amber border when `status === "waiting"`
- [ ] Inline approve / reject buttons appear when waiting
- [ ] Three output handle positions (25%, 50%, 75% height)
- [ ] Status transitions: idle → waiting → approved/rejected/timed_out

**CronTrigger**

- [ ] `Fitzyo.Workers.CronTriggerWorker`
- [ ] Registered in Oban cron plugin from node config schedule
- [ ] Boots a new WorkflowExecution on each fire
- [ ] `CronTriggerNode.svelte` — shows next fire time countdown

**WebhookTrigger**

- [ ] `FitzYoWeb.Plugs.AuthenticateWebhookToken` — validates user tokens
- [ ] `FitzYoWeb.Plugs.RateLimitByToken` — prevents abuse
- [ ] `WebhookController.user_trigger/2` → inserts Oban job → boots Reactor
- [ ] Token management UI in node config panel

**WaitNode**

- [ ] `Fitzyo.Workers.WaitWorker` — `Oban.insert(scheduled_in: duration)`
- [ ] `WaitNode.svelte` — countdown timer showing time remaining

**Suspension persistence**

- [ ] `ContextMiddleware.halt/1` — persists context to `WorkflowExecution.context_snapshot`
- [ ] `ObanBridge.reload_and_resume/2` — rehydrates context from DB
      if ContextServer process has died (server restart scenario)
- [ ] Integration test: kill the server mid-execution, restart, verify it resumes

### Deliverable

A workflow that generates a video draft, pauses for human review with
an approve/reject button on the node itself, then either publishes to
S3 or sends feedback — all resuming correctly. Demonstrate that
restarting the Phoenix server mid-execution still resumes correctly.

### Exit criteria

- [ ] Approval node shows pulsing amber animation when waiting
- [ ] Approve/reject buttons visible and functional inline on the node
- [ ] All three output edges (approved/rejected/timed_out) routable
- [ ] Cron trigger fires at correct schedule — confirmed in Oban dashboard
- [ ] Webhook trigger fires from `curl` command — confirmed end-to-end
- [ ] Server restart mid-execution: workflow resumes correctly
- [ ] Context snapshot persisted to DB at every suspension point

---

## Slice 6 — Asset Marketplace

**Duration:** Weeks 9–13
**Goal:** A working creator economy — upload, buy, and use assets in scene nodes.
**Done when:** A creator uploads a background image, sets a price,
a buyer purchases it in the AssetPicker, and uses it in a SceneNode.

### Sub-slices (Slice 6 is large enough to break down)

#### 6a — Upload & Review (Week 9)

**Tasks**

- [ ] `Fitzyo.MarketplaceAsset` Spark DSL — `BackgroundImage`, `CharacterRef`,
      `StylePack`, `AudioTrack`, `VFXOverlay`, `PromptTemplate`, `WorkflowTemplate`
- [ ] `Fitzyo.Marketplace.Asset` Ash resource — full schema
- [ ] `Fitzyo.Marketplace.CreatorProfile` Ash resource
- [ ] `AssetProcessor` Rust NIF crate:
  - `add_watermark/3` — diagonal watermark on images
  - `generate_asset_thumbnail/4` — smart crop per asset type
  - `analyse_asset_quality/1` — resolution/blur/noise quality gate
  - `extract_dominant_colours/2` — k-means palette for auto-tagging
- [ ] Two-tier S3 structure: originals (private) + previews (public)
- [ ] `Fitzyo.Marketplace.S3Store.upload_asset/3` — stores both tiers
- [ ] Auto-review Reactor workflow (generated by `MarketplaceAsset` DSL):
  1. QualityAnalysis NIF
  2. ContentModeration (Claude API)
  3. AutoTagging (NIF + Claude)
  4. ThumbnailGeneration NIF
  5. AutoPublish or HumanReview
- [ ] Plug pipeline: `:creator_upload`
  - `AuthenticateCreator`
  - `EnforceFileSizeLimits`
  - `ValidateContentType`
  - `ExtractUploadMetadata`
- [ ] `CreatorStudio.svelte` — upload UI matching mockup design

**Exit criteria**

- [ ] Upload a JPG → quality gate passes → watermarked preview in Tigris
- [ ] Review workflow runs end-to-end in Oban dashboard
- [ ] Asset auto-tagged with dominant colour categories
- [ ] `MarketplaceAsset` DSL generates review workflow automatically
      (no manual Reactor wiring)

#### 6b — Storefront & Purchase (Weeks 10–11)

**Tasks**

- [ ] `Fitzyo.Marketplace.Purchase` Ash resource
- [ ] `Fitzyo.Marketplace.Royalty` Ash resource
- [ ] `Fitzyo.Marketplace.Review` Ash resource
- [ ] `MarketplaceLive` — storefront LiveView with filtering/search
- [ ] Stripe integration:
  - `Stripe.PaymentIntent.create` on purchase initiation
  - Stripe.js in Svelte for payment confirmation
  - Stripe webhook → `Purchase.complete` → `RoyaltyDistributor.distribute/1`
- [ ] `FitzYoWeb.Plugs.VerifyStripeSignature` plug
- [ ] `RoyaltyDistributor.distribute/1` — 70/30 split
- [ ] `Fitzyo.Workers.RoyaltyPayoutWorker` — Stripe Connect transfers
- [ ] `S3AccessGrant.provision/1` — generates download_key on purchase
- [ ] `AssetStorefront.svelte` — browse, preview, purchase

**Exit criteria**

- [ ] End-to-end purchase: buy an asset → Stripe payment → royalty created
- [ ] Creator receives 70% via Stripe Connect transfer
- [ ] Purchased assets accessible via presigned URL
- [ ] Stripe webhook verified by plug (reject bad signatures)

#### 6c — AssetPicker in Canvas (Week 12)

**Tasks**

- [ ] `AssetPicker.svelte` — slide-over panel matching mockup design
  - Filtered by compatible asset type for the target handle
  - Purchased assets show "Use" button, unpurchased show price
  - Hover preview for all asset types
  - Search with instant filtering
- [ ] `AssetLoader` node — wires purchased S3Ref into workflow
- [ ] Node config panel integration — "Add from marketplace" button
      opens AssetPicker slide-over
- [ ] One-click: purchase → automatically wired to scene node handle
- [ ] `AssetPrefetcher.prefetch_workflow_assets/1` — Tigris prefetch
      header called before workflow execution starts

**Exit criteria**

- [ ] AssetPicker opens inline on canvas without leaving workflow editor
- [ ] Purchased asset wires directly to scene node handle
- [ ] Asset type filter only shows compatible assets for each handle
- [ ] Tigris prefetch called at execution start — confirmed in network tab

#### 6d — Creator Dashboard (Week 13)

**Tasks**

- [ ] `CreatorDashboardLive` — earnings, asset performance, payout history
- [ ] `Fitzyo.Marketplace.Calculations.RevenueTotal` Ash calculation
- [ ] `Fitzyo.Marketplace.Calculations.AverageRating` Ash calculation
- [ ] `Fitzyo.Marketplace.Calculations.IsPurchasedByCurrentUser`
- [ ] Asset management: edit, unpublish, update pricing
- [ ] Review and rating system (buyers rate purchased assets)

**Exit criteria**

- [ ] Creator sees real-time earnings updated as purchases happen
- [ ] Asset can be edited and re-published
- [ ] Payout history shows all Stripe Connect transfers

---

## Slice 7 — Production Hardening

**Duration:** Weeks 14–16
**Goal:** Production-ready. Handles real traffic, fails gracefully.
**Done when:** Deployed to Fly.io, passing load tests, monitoring active.

### Tasks

**Performance**

- [ ] Add second video provider (Runway Gen-4.5)
- [ ] Add third video provider (Luma Ray3)
- [ ] `AssetPrefetcher` — Tigris prefetch for all workflow assets
- [ ] DB query optimisation — N+1 audit via `ash_sql` query plans
- [ ] LiveView socket connection pooling under load
- [ ] Oban queue tuning based on real job timing data

**Reliability**

- [ ] Integration test: server restart mid-execution resumes correctly
- [ ] Integration test: video API timeout → Oban retry → eventual success
- [ ] Integration test: payment taken → video gen fails → undo refunds
- [ ] Oban `max_attempts` tuned per queue based on real failure rates
- [ ] Dead letter queue monitoring — alert on repeated failures

**Security**

- [ ] Ash policy audit — verify no unauthorised data access paths
- [ ] All webhook signatures verified — integration tests for bad sigs
- [ ] Presigned URL expiry enforced — test expired URLs return 403
- [ ] Rate limiting on all API and webhook endpoints
- [ ] Creator verification flow — email + payment method required

**Observability**

- [ ] Fly.io metrics configured
- [ ] Oban Web dashboard deployed (admin-only route)
- [ ] Custom telemetry events for key business metrics:
  - `[:fitzyo, :workflow, :executed]`
  - `[:fitzyo, :scene, :generated]`
  - `[:fitzyo, :asset, :purchased]`
- [ ] Error alerting on Oban dead letter queue

**Deployment**

- [ ] `fly.toml` configured
- [ ] Fly Postgres provisioned (primary + replica)
- [ ] All Tigris buckets provisioned via `fly storage create`
- [ ] `Dockerfile` with Rustler Precompiled (no Rust toolchain in prod)
- [ ] `mix release` working — `PHX_SERVER=true` env var
- [ ] Health check endpoint responding
- [ ] Smoke test suite running against production URL

### Exit criteria

- [ ] `fly deploy` succeeds from clean checkout
- [ ] All Tigris buckets accessible from production
- [ ] End-to-end workflow execution working in production
- [ ] Oban Web accessible at `/admin/oban` (admin only)
- [ ] No N+1 queries on main LiveView pages
- [ ] Server restart on Fly doesn't lose in-progress executions

---

## Slice 8 — Tauri Desktop Shell (Optional)

**Duration:** Weeks 17–18 (only if creator feedback requests it)
**Goal:** Optional desktop app for power creators doing bulk uploads.
**Done when:** macOS `.app` downloadable from fitzyo.com, bulk upload working.

### Tasks

- [ ] `src-tauri/` scaffold with Tauri 2.0
- [ ] WebView pointed at production `app.fitzyo.com`
- [ ] Auth token injected from OS keychain into WebView session
- [ ] `tauri-plugin-fs` — native file picker for bulk asset upload
- [ ] `tauri-plugin-notification` — system tray generation notifications
- [ ] Cross-platform testing (macOS, Windows, Linux)
- [ ] Code signing for macOS and Windows distribution

### Exit criteria

- [ ] `.dmg` and `.exe` installers downloadable from fitzyo.com
- [ ] Bulk upload of 20 assets completes successfully
- [ ] System tray notification fires on scene generation complete
- [ ] WebKit / WebView2 / WebKitGTK CSS parity confirmed

---

## Key Milestones

| Milestone           | Slice   | Target  | What it proves                         |
| ------------------- | ------- | ------- | -------------------------------------- |
| 🔧 **Pipe works**   | Slice 0 | Day 3   | Stack is healthy, integration is sound |
| ⚡ **Engine runs**  | Slice 1 | Week 2  | Reactor/Oban/NIF pipeline validated    |
| 🎨 **Canvas ships** | Slice 2 | Week 4  | Core product usable                    |
| ✦ **NL generates**  | Slice 3 | Week 5  | Headline feature working               |
| 🎬 **Real video**   | Slice 4 | Week 7  | Product becomes real                   |
| 👤 **HITL works**   | Slice 5 | Week 8  | Complex workflows possible             |
| 🛒 **Market open**  | Slice 6 | Week 13 | Business model active                  |
| 🚀 **Production**   | Slice 7 | Week 16 | Public launch ready                    |
| 🖥 **Desktop**      | Slice 8 | Week 18 | Power creator experience               |

---

## Testing Strategy Per Slice

| Slice | Unit                              | Integration              | E2E                   |
| ----- | --------------------------------- | ------------------------ | --------------------- |
| 0     | Ash resource CRUD                 | Pipe round-trip          | —                     |
| 1     | NIF functions, NodeStep DSL       | Reactor + Oban execution | —                     |
| 2     | GraphCompiler, GraphValidator NIF | Multi-node execution     | —                     |
| 3     | PromptBuilder, GraphSchema        | Claude API (mock in CI)  | —                     |
| 4     | VideoProvider DSL                 | Kling API (mock in CI)   | First clip generated  |
| 5     | ObanBridge suspend/resume         | Server restart + resume  | Approval workflow     |
| 6     | Ash marketplace resources         | Stripe webhook (mock)    | Full purchase flow    |
| 7     | —                                 | Load test (k6)           | Full workflow in prod |

**CI rule:** Video API calls are always mocked in CI using recorded
responses. Real API calls only happen in manual integration tests and
production. This keeps CI under 2 minutes.

---

## What Claude Code Does Per Slice

Claude Code's role shifts across slices:

**Slice 0:** Generates Phoenix + live_svelte boilerplate and config.
You review the integration wiring.

**Slice 1–2:** Generates all NodeStep DSL implementations, Ash resources,
Oban worker boilerplate, Svelte component shells. You review the
Reactor/Oban bridge design and NIF scheduler choices.

**Slice 3:** Generates PromptBuilder serialisation logic and GraphSchema.
You review the prompt engineering and token budget strategy.

**Slice 4–5:** Generates VideoProvider implementations and webhook plugs.
You review API error handling and the Oban retry/backoff strategy.

**Slice 6:** Generates all marketplace Ash resources, Stripe integration,
AssetProcessor NIF bindings. You review the financial logic and policy rules.

**Slice 7–8:** You drive. Claude Code assists with specific optimisation
tasks and Tauri boilerplate. The hard work at this stage is judgment,
not generation.

**The constant:** You always write tests first for anything involving
money, security, or the Reactor/Oban bridge. Claude Code writes tests
for everything else.
