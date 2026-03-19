<script lang="ts">
  import { Handle, Position } from "@xyflow/svelte";

  let { data } = $props<{
    data: {
      label: string;
      status?: "idle" | "pending" | "generating" | "complete" | "failed";
      progress?: number;
      thumbnail_url?: string | null;
    };
  }>();

  let status = $derived(data.status ?? "idle");
  let progress = $derived(data.progress ?? 0);
  let label = $derived(data.label ?? "Scene Generator");
  let thumbnail_url = $derived(data.thumbnail_url ?? null);
</script>

<div class="scene-node" class:generating={status === "generating"} class:complete={status === "complete"} class:failed={status === "failed"}>
  <Handle type="target" position={Position.Left} />

  <div class="node-header">
    <div class="node-icon icon-generation">🎬</div>
    <div class="node-meta">
      <div class="node-label">{label}</div>
      <div class="node-kind">scene_generator</div>
    </div>
    <div class="node-status-dot" class:dot-idle={status === "idle"} class:dot-pending={status === "pending"} class:dot-generating={status === "generating"} class:dot-complete={status === "complete"} class:dot-failed={status === "failed"}></div>
  </div>

  <div class="node-thumb">
    {#if status === "idle" || status === "pending"}
      <div class="thumb-placeholder">
        <span class="thumb-placeholder-icon">▶</span>
      </div>
    {:else if status === "generating"}
      <div class="thumb-generating">
        <span class="thumb-spinner">⟳</span>
        <span class="gen-label">{progress}%</span>
      </div>
      <div class="thumb-progress-bar" style="width: {progress}%"></div>
    {:else if status === "complete" && thumbnail_url}
      <img class="thumb-image" src={thumbnail_url} alt="Generated thumbnail" />
    {:else if status === "complete"}
      <div class="thumb-complete">
        <span class="thumb-check">✓</span>
      </div>
    {:else if status === "failed"}
      <div class="thumb-failed">
        <span>✗</span>
      </div>
    {/if}
  </div>

  <Handle type="source" position={Position.Right} />
</div>

<style>
  .scene-node {
    background: #1a1a2e;
    border: 1.5px solid rgba(139, 92, 246, 0.3);
    border-radius: 10px;
    width: 180px;
    overflow: hidden;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.5);
    transition: border-color 0.2s, box-shadow 0.2s;
  }

  .scene-node.generating {
    border-color: rgba(245, 158, 11, 0.6);
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.5), 0 0 0 2px rgba(245, 158, 11, 0.15);
    animation: pulse-border 1.5s ease-in-out infinite;
  }

  .scene-node.complete {
    border-color: rgba(16, 185, 129, 0.5);
  }

  .scene-node.failed {
    border-color: rgba(239, 68, 68, 0.5);
  }

  @keyframes pulse-border {
    0%, 100% { box-shadow: 0 4px 24px rgba(0,0,0,0.5), 0 0 0 2px rgba(245,158,11,0.15); }
    50% { box-shadow: 0 4px 24px rgba(0,0,0,0.5), 0 0 0 4px rgba(245,158,11,0.3); }
  }

  .node-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    border-bottom: 1px solid rgba(255, 255, 255, 0.06);
  }

  .node-icon {
    width: 26px;
    height: 26px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 13px;
    flex-shrink: 0;
  }

  .icon-generation {
    background: rgba(139, 92, 246, 0.15);
    border: 1px solid rgba(139, 92, 246, 0.2);
  }

  .node-meta {
    flex: 1;
    min-width: 0;
  }

  .node-label {
    font-size: 11px;
    font-weight: 600;
    color: #f0f4f8;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .node-kind {
    font-size: 9px;
    color: #4a5568;
    font-family: 'DM Mono', monospace;
  }

  .node-status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
  }

  .dot-idle { background: #4a5568; }
  .dot-pending { background: #8b5cf6; animation: blink 1s ease-in-out infinite; }
  .dot-generating { background: #f59e0b; animation: blink 0.8s ease-in-out infinite; }
  .dot-complete { background: #10b981; }
  .dot-failed { background: #ef4444; }

  @keyframes blink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.3; }
  }

  .node-thumb {
    position: relative;
    height: 90px;
    background: #0f0f18;
    overflow: hidden;
  }

  .thumb-placeholder {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #2d3748;
    font-size: 22px;
  }

  .thumb-generating {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    gap: 4px;
    background: #0f0f18;
  }

  .thumb-spinner {
    font-size: 18px;
    color: #f59e0b;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
  }

  .gen-label {
    font-size: 10px;
    color: #f59e0b;
    font-family: 'DM Mono', monospace;
    font-weight: 600;
  }

  .thumb-progress-bar {
    position: absolute;
    bottom: 0;
    left: 0;
    height: 2px;
    background: #f59e0b;
    border-radius: 0 0 0 0;
    transition: width 0.4s ease-out;
  }

  .thumb-image {
    width: 100%;
    height: 100%;
    object-fit: cover;
  }

  .thumb-complete {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #10b981;
    font-size: 24px;
  }

  .thumb-failed {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    color: #ef4444;
    font-size: 24px;
  }
</style>
