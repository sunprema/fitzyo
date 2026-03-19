<script lang="ts">
  import { SvelteFlow, Background, Controls, MiniMap, type Viewport } from "@xyflow/svelte";
  import "@xyflow/svelte/dist/style.css";
  import { setContext } from "svelte";

  import SceneNode from "./nodes/SceneNode.svelte";
  import WorkflowNode from "./nodes/WorkflowNode.svelte";
  import NodePalette from "./NodePalette.svelte";
  import NodeConfigPanel from "./NodeConfigPanel.svelte";
  import TimelineStrip from "./TimelineStrip.svelte";
  import ChatPanel from "./ChatPanel.svelte";
  import ReasoningPanel from "./ReasoningPanel.svelte";

  type ChatMessage = {
    id: number;
    role: 'user' | 'assistant';
    content: string;
    reasoning?: string;
    error?: boolean;
  };

  let {
    nodes = [],
    edges = [],
    last_pong = null,
    node_states = {},
    node_registry = [],
    workflow_id = null,
    chat_messages = [],
    generating = false,
    reasoning = null,
    live,
  } = $props<{
    nodes: any[];
    edges: any[];
    last_pong: string | null;
    node_states: Record<string, any>;
    node_registry: any[];
    workflow_id: string | null;
    chat_messages: ChatMessage[];
    generating: boolean;
    reasoning: string | null;
    live: any;
  }>();

  // Local mutable copies — SvelteFlow owns these via bind:
  // Initialized empty; $effect below handles both initial load and server updates.
  let localNodes = $state.raw<any[]>([]);
  let localEdges = $state.raw<any[]>([]);

  // Sync whenever the server pushes a new graph (initial mount + workflow switches)
  $effect(() => {
    localNodes = nodes;
    localEdges = edges;
  });

  // Expose state + registry to all descendant node components via context
  setContext('node_states', () => node_states);
  setContext('node_registry', () => node_registry);

  // Viewport tracked for drop-position calculation
  let viewport = $state<Viewport>({ x: 0, y: 0, zoom: 1 });

  // Selected node drives the right-hand config panel
  let selected_node = $state<any>(null);

  // Canvas element ref — needed for getBoundingClientRect on drop
  let canvasEl: HTMLDivElement;

  // NL prompt input (quick bar — delegates to chat panel in Slice 3)
  let nl_input = $state('');

  // Auto-save state indicator
  let save_pending = $state(false);

  // Left panel tab: 'palette' | 'chat'
  let left_tab = $state<'palette' | 'chat'>('palette');

  // Reasoning panel visibility
  let reasoning_visible = $state(false);
  let reasoning_text = $state('');

  // Show reasoning panel when a new reasoning arrives from the server
  $effect(() => {
    if (reasoning) {
      reasoning_text = reasoning;
    }
  });

  function showReasoning(text: string) {
    reasoning_text = text;
    reasoning_visible = true;
  }

  // ── Node type registry ──────────────────────────────────────────────────────
  const nodeTypes: Record<string, any> = {
    scene_generator:  SceneNode,
    webhook_trigger:  WorkflowNode,
    cron_trigger:     WorkflowNode,
    wait:             WorkflowNode,
    character_animate: WorkflowNode,
    background_gen:   WorkflowNode,
    vfx_overlay:      WorkflowNode,
    scene_stitch:     WorkflowNode,
    audio_mixer:      WorkflowNode,
    clip_trimmer:     WorkflowNode,
    final_export:     WorkflowNode,
    asset_loader:     WorkflowNode,
    prompt_template:  WorkflowNode,
    style_reference:  WorkflowNode,
    conditional:      WorkflowNode,
    parallel_merge:   WorkflowNode,
  };

  // ── Auto-save (debounced 2 s) ───────────────────────────────────────────────
  let saveTimer: ReturnType<typeof setTimeout> | null = null;

  function scheduleSave() {
    save_pending = true;
    if (saveTimer) clearTimeout(saveTimer);
    saveTimer = setTimeout(() => {
      live.pushEvent('save_graph', { nodes: localNodes, edges: localEdges });
      save_pending = false;
    }, 2000);
  }

  // ── SvelteFlow event handlers ───────────────────────────────────────────────

  function onconnect(connection: any) {
    const id = `e-${connection.source}-${connection.sourceHandle ?? 'out'}-${connection.target}-${connection.targetHandle ?? 'in'}-${Date.now()}`;
    localEdges = [
      ...localEdges,
      {
        id,
        source: connection.source,
        target: connection.target,
        sourceHandle: connection.sourceHandle,
        targetHandle: connection.targetHandle,
      },
    ];
    scheduleSave();
  }

  function onnodedragstop() {
    scheduleSave();
  }

  function onnodeclick({ node }: { node: any }) {
    selected_node = node;
  }

  function onpaneclick() {
    selected_node = null;
  }

  // ── Drag-from-palette ───────────────────────────────────────────────────────

  function ondragover(e: DragEvent) {
    e.preventDefault();
    if (e.dataTransfer) e.dataTransfer.dropEffect = 'move';
  }

  function ondrop(e: DragEvent) {
    e.preventDefault();
    const kind = e.dataTransfer?.getData('text/plain');
    if (!kind) return;

    const rect = canvasEl.getBoundingClientRect();
    const position = {
      x: (e.clientX - rect.left - viewport.x) / viewport.zoom,
      y: (e.clientY - rect.top  - viewport.y) / viewport.zoom,
    };

    const reg = node_registry.find((r: any) => String(r.kind) === kind);
    const newNode = {
      id:       `${kind}-${Date.now()}`,
      type:     kind,
      position,
      data:     { label: reg?.label ?? kind },
    };

    localNodes = [...localNodes, newNode];
    scheduleSave();
  }

  // ── Toolbar actions ─────────────────────────────────────────────────────────

  function runWorkflow() {
    live.pushEvent('execute_workflow', {});
  }

  function submitNL() {
    const prompt = nl_input.trim();
    if (!prompt) return;
    live.pushEvent('nl_generate', { prompt });
    nl_input = '';
  }
</script>

<div class="canvas-root">
  <!-- ── Three-column workspace ─────────────────────────────────────── -->
  <div class="workspace">

    <!-- Left: tabbed panel (Nodes | Chat) -->
    <div class="left-panel">
      <div class="left-tabs">
        <button
          class="left-tab"
          class:active={left_tab === 'palette'}
          onclick={() => (left_tab = 'palette')}
        >Nodes</button>
        <button
          class="left-tab"
          class:active={left_tab === 'chat'}
          onclick={() => (left_tab = 'chat')}
        >
          Chat
          {#if generating}
            <span class="tab-dot generating"></span>
          {:else if chat_messages.length > 0}
            <span class="tab-dot active-dot"></span>
          {/if}
        </button>
      </div>
      {#if left_tab === 'palette'}
        <NodePalette {node_registry} />
      {:else}
        <ChatPanel
          messages={chat_messages}
          {generating}
          {live}
          onshow_reasoning={showReasoning}
        />
      {/if}
    </div>

    <!-- Center: SvelteFlow canvas -->
    <div class="canvas-area" role="application" aria-label="Workflow canvas" bind:this={canvasEl} {ondragover} {ondrop}>
      <SvelteFlow
        bind:nodes={localNodes}
        bind:edges={localEdges}
        bind:viewport
        {nodeTypes}
        colorMode="dark"
        fitView
        {onconnect}
        {onnodedragstop}
        {onnodeclick}
        {onpaneclick}
      >
        <Background gap={20} color="rgba(255,255,255,0.03)" />
        <Controls />
        <MiniMap
          style="background: #0d1117; border: 1px solid rgba(255,255,255,0.06); border-radius: 6px;"
          nodeColor="#1a2230"
          maskColor="rgba(0,0,0,0.4)"
        />
      </SvelteFlow>

      <!-- Top-right toolbar overlay -->
      <div class="overlay-top">
        {#if save_pending}
          <span class="save-badge save-pending">Saving…</span>
        {:else if last_pong}
          <span class="save-badge save-ok">Saved</span>
        {/if}
        <div class="spacer"></div>
        <button class="run-btn" onclick={runWorkflow}>▶ Run</button>
      </div>

      <!-- Reasoning overlay inside canvas -->
      <ReasoningPanel
        reasoning={reasoning_text}
        visible={reasoning_visible}
        onclose={() => (reasoning_visible = false)}
      />

      <!-- Bottom: NL prompt bar -->
      <div class="nl-bar">
        <input
          class="nl-input"
          placeholder="Describe changes to your workflow…"
          bind:value={nl_input}
          onkeydown={(e) => e.key === 'Enter' && submitNL()}
        />
        <button class="nl-send" onclick={submitNL} disabled={!nl_input.trim()}>
          →
        </button>
      </div>
    </div>

    <!-- Right: node config panel -->
    <NodeConfigPanel {selected_node} {node_registry} />
  </div>

  <!-- Bottom: timeline strip -->
  <TimelineStrip nodes={localNodes} {node_states} {node_registry} />
</div>

<style>
  /* ── Root shell ─────────────────────────────────────────────────────────── */
  .canvas-root {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    background: #0d1117;
    overflow: hidden;
  }

  /* ── Three-column row ───────────────────────────────────────────────────── */
  .workspace {
    flex: 1;
    display: flex;
    flex-direction: row;
    overflow: hidden;
    min-height: 0;
  }

  /* ── Tabbed left panel ──────────────────────────────────────────────────── */
  .left-panel {
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    overflow: hidden;
    border-right: 1px solid rgba(255,255,255,0.06);
    background: #0d1117;
  }

  .left-tabs {
    display: flex;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .left-tab {
    flex: 1;
    padding: 7px 0;
    font-size: 11px;
    font-weight: 500;
    color: #4a5568;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: all 0.1s;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 5px;
  }

  .left-tab:hover:not(.active) { color: #8b97a8; }
  .left-tab.active { color: #f0f4f8; border-bottom-color: #8B5CF6; }

  .tab-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    display: inline-block;
  }

  .tab-dot.generating {
    background: #F59E0B;
    animation: dot-blink 1s ease-in-out infinite;
  }

  .tab-dot.active-dot { background: #8B5CF6; }

  @keyframes dot-blink {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.3; }
  }

  /* Palette and ChatPanel fill remaining space below tabs */
  .left-panel :global(.palette),
  .left-panel :global(.chat-panel) {
    border-right: none;
    flex: 1;
    min-height: 0;
  }

  /* ── SvelteFlow canvas column ───────────────────────────────────────────── */
  .canvas-area {
    flex: 1;
    position: relative;
    overflow: hidden;
    background: #0f1117;
  }

  /* SvelteFlow fills the entire canvas-area */
  .canvas-area :global(.svelte-flow) {
    width: 100%;
    height: 100%;
  }

  /* ── Top toolbar overlay ────────────────────────────────────────────────── */
  .overlay-top {
    position: absolute;
    top: 10px;
    left: 10px;
    right: 10px;
    display: flex;
    align-items: center;
    gap: 8px;
    pointer-events: none;
    z-index: 5;
  }

  .overlay-top > * { pointer-events: auto; }

  .spacer { flex: 1; }

  .save-badge {
    font-size: 10px;
    font-family: 'DM Mono', monospace;
    background: rgba(13, 17, 23, 0.85);
    padding: 3px 8px;
    border-radius: 4px;
    border: 1px solid rgba(255,255,255,0.06);
    backdrop-filter: blur(4px);
  }

  .save-pending { color: #F59E0B; }
  .save-ok      { color: #10b981; }

  .run-btn {
    padding: 6px 20px;
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.3);
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.15s;
    backdrop-filter: blur(4px);
  }

  .run-btn:hover { background: rgba(16, 185, 129, 0.28); }

  /* ── NL prompt bar ──────────────────────────────────────────────────────── */
  .nl-bar {
    position: absolute;
    bottom: 14px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 6px;
    z-index: 5;
    width: min(520px, 80%);
  }

  .nl-input {
    flex: 1;
    background: rgba(13, 17, 23, 0.9);
    border: 1px solid rgba(255, 255, 255, 0.1);
    border-radius: 8px;
    padding: 9px 14px;
    font-size: 13px;
    color: #f0f4f8;
    outline: none;
    backdrop-filter: blur(10px);
    box-sizing: border-box;
  }

  .nl-input:focus { border-color: rgba(139, 92, 246, 0.5); }
  .nl-input::placeholder { color: #4a5568; }

  .nl-send {
    padding: 9px 14px;
    background: rgba(139, 92, 246, 0.18);
    color: #8b5cf6;
    border: 1px solid rgba(139, 92, 246, 0.3);
    border-radius: 8px;
    cursor: pointer;
    font-size: 15px;
    transition: background 0.15s;
    line-height: 1;
  }

  .nl-send:hover:not(:disabled) { background: rgba(139, 92, 246, 0.32); }
  .nl-send:disabled { opacity: 0.35; cursor: default; }
</style>
