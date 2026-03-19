<script lang="ts">
  import { SvelteFlow, Background, Controls } from "@xyflow/svelte";
  import "@xyflow/svelte/dist/style.css";
  import SceneNode from "./nodes/SceneNode.svelte";

  let { nodes = [], edges = [], last_pong = null, node_states = {}, live } = $props();

  // Merge server node_states into node data for SvelteFlow rendering
  let flowNodes = $derived.by(() => {
    return nodes.map((n) => ({
      ...n,
      data: {
        ...n.data,
        ...(node_states[n.id] ?? {}),
      },
    }));
  });

  let flowEdges = $state.raw(edges);

  const nodeTypes = {
    scene_generator: SceneNode,
  };

  const ping = () => {
    live.pushEvent("ping", {});
  };

  const run = () => {
    live.pushEvent("execute_workflow", {});
  };
</script>

<div class="canvas-wrapper">
  <SvelteFlow nodes={flowNodes} bind:edges={flowEdges} {nodeTypes} colorMode="dark" fitView>
    <Background />
    <Controls />
  </SvelteFlow>

  <div class="canvas-toolbar">
    <button class="run-button" onclick={run}>▶ Run</button>
    <button class="ping-button" onclick={ping}>Ping</button>
    {#if last_pong}
      <span class="pong-label">Pong! record_id={last_pong}</span>
    {/if}
  </div>
</div>

<style>
  .canvas-wrapper {
    position: absolute;
    inset: 0;
    background: #0f0f14;
    overflow: hidden;
  }

  .canvas-toolbar {
    position: absolute;
    bottom: 12px;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    gap: 10px;
    z-index: 10;
  }

  .run-button {
    padding: 6px 18px;
    background: rgba(16, 185, 129, 0.15);
    color: #10b981;
    border: 1px solid rgba(16, 185, 129, 0.3);
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.15s;
  }

  .run-button:hover {
    background: rgba(16, 185, 129, 0.25);
  }

  .ping-button {
    padding: 6px 18px;
    background: #6366f1;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
    font-size: 13px;
    font-weight: 500;
    transition: background 0.15s;
  }

  .ping-button:hover {
    background: #4f52c9;
  }

  .pong-label {
    color: #86efac;
    font-size: 12px;
    font-family: monospace;
    background: rgba(0, 0, 0, 0.5);
    padding: 4px 8px;
    border-radius: 4px;
  }
</style>
