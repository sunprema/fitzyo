<script lang="ts">
  import { Handle, Position } from "@xyflow/svelte";
  import { getContext } from "svelte";

  let { id, data, type, selected = false } = $props<{
    id: string;
    data: { label?: string; [key: string]: any };
    type: string;
    selected?: boolean;
  }>();

  // Read node_states and node_registry from WorkflowCanvas context
  const getStates = getContext<() => Record<string, any>>('node_states');
  const getRegistry = getContext<() => any[]>('node_registry');

  let ns = $derived(getStates?.()[id] ?? { status: 'idle', progress: 0, thumbnail_url: null });
  let reg = $derived(getRegistry?.().find((r: any) => String(r.kind) === type));

  let status = $derived(ns.status ?? 'idle');
  let progress = $derived(ns.progress ?? 0);
  let thumbnail_url = $derived(ns.thumbnail_url ?? null);
  let label = $derived(data.label ?? reg?.label ?? type);

  // Color scheme per category
  const colorSchemes: Record<string, { accent: string; dim: string; border: string; iconBg: string }> = {
    violet: { accent: '#8B5CF6', dim: 'rgba(139,92,246,0.15)', border: 'rgba(139,92,246,0.3)', iconBg: 'rgba(139,92,246,0.12)' },
    amber:  { accent: '#F59E0B', dim: 'rgba(245,158,11,0.15)',  border: 'rgba(245,158,11,0.3)',  iconBg: 'rgba(245,158,11,0.12)' },
    blue:   { accent: '#3B82F6', dim: 'rgba(59,130,246,0.15)',  border: 'rgba(59,130,246,0.3)',  iconBg: 'rgba(59,130,246,0.12)' },
    teal:   { accent: '#14B8A6', dim: 'rgba(20,184,166,0.15)',  border: 'rgba(20,184,166,0.3)',  iconBg: 'rgba(20,184,166,0.12)' },
    gray:   { accent: '#888888', dim: 'rgba(139,139,139,0.1)',  border: 'rgba(139,139,139,0.2)', iconBg: 'rgba(139,139,139,0.1)' },
  };

  let scheme = $derived(colorSchemes[reg?.color ?? 'gray'] ?? colorSchemes.gray);

  let inputs = $derived(reg?.inputs ?? []);
  let outputs = $derived(reg?.outputs ?? []);

  let borderColor = $derived(
    status === 'generating' ? 'rgba(245,158,11,0.6)' :
    status === 'complete'   ? 'rgba(16,185,129,0.5)' :
    status === 'failed'     ? 'rgba(239,68,68,0.5)' :
    selected                ? scheme.accent :
    scheme.border
  );
</script>

<!-- Input handles (left side) -->
{#each inputs as input, i}
  <Handle
    type="target"
    position={Position.Left}
    id={String(input.name)}
    style={`top: ${(i + 0.5) / Math.max(inputs.length, 1) * 100}%`}
  />
{/each}

<div
  class="wf-node"
  class:generating={status === 'generating'}
  class:complete={status === 'complete'}
  class:failed={status === 'failed'}
  style={`--accent: ${scheme.accent}; --dim: ${scheme.dim}; --icon-bg: ${scheme.iconBg}; border-color: ${borderColor};`}
>
  <div class="node-header">
    <div class="node-icon">{reg?.icon ?? '⬜'}</div>
    <div class="node-meta">
      <div class="node-label">{label}</div>
      <div class="node-kind">{type}</div>
    </div>
    <div
      class="status-dot"
      class:dot-idle={status === 'idle'}
      class:dot-pending={status === 'pending'}
      class:dot-generating={status === 'generating'}
      class:dot-complete={status === 'complete'}
      class:dot-failed={status === 'failed'}
    ></div>
  </div>

  {#if status === 'generating'}
    <div class="node-thumb">
      <div class="thumb-generating">
        <span class="thumb-spinner">⟳</span>
        <span class="gen-pct">{progress}%</span>
      </div>
      <div class="thumb-progress-bar" style={`width: ${progress}%`}></div>
    </div>
  {:else if status === 'complete' && thumbnail_url}
    <div class="node-thumb">
      <img class="thumb-img" src={thumbnail_url} alt="output" />
    </div>
  {:else if status === 'complete'}
    <div class="node-thumb thumb-done">✓</div>
  {/if}
</div>

<!-- Output handles (right side) -->
{#each outputs as output, i}
  <Handle
    type="source"
    position={Position.Right}
    id={String(output.name)}
    style={`top: ${(i + 0.5) / Math.max(outputs.length, 1) * 100}%`}
  />
{/each}

<style>
  .wf-node {
    background: #131920;
    border: 1.5px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    width: 180px;
    overflow: visible;
    box-shadow: 0 4px 24px rgba(0,0,0,0.5);
    transition: border-color 0.2s, box-shadow 0.2s;
    cursor: grab;
  }

  .wf-node.generating {
    animation: pulse-border 1.5s ease-in-out infinite;
  }

  @keyframes pulse-border {
    0%, 100% { box-shadow: 0 4px 24px rgba(0,0,0,0.5), 0 0 0 2px rgba(245,158,11,0.15); }
    50%       { box-shadow: 0 4px 24px rgba(0,0,0,0.5), 0 0 0 4px rgba(245,158,11,0.3); }
  }

  .node-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 10px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
  }

  .node-icon {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    background: var(--icon-bg);
    border: 1px solid rgba(255,255,255,0.08);
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    flex-shrink: 0;
  }

  .node-meta { flex: 1; min-width: 0; }

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

  .status-dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .dot-idle       { background: #4a5568; }
  .dot-pending    { background: #8b5cf6; animation: blink 1s ease-in-out infinite; }
  .dot-generating { background: #f59e0b; animation: blink 0.8s ease-in-out infinite; }
  .dot-complete   { background: #10b981; }
  .dot-failed     { background: #ef4444; }

  @keyframes blink {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.3; }
  }

  .node-thumb {
    position: relative;
    height: 72px;
    background: #0d1117;
    overflow: hidden;
    border-radius: 0 0 8px 8px;
  }

  .thumb-generating {
    width: 100%;
    height: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    gap: 4px;
  }

  .thumb-spinner {
    font-size: 16px;
    color: #f59e0b;
    animation: spin 1s linear infinite;
  }
  @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

  .gen-pct {
    font-size: 10px;
    color: #f59e0b;
    font-family: 'DM Mono', monospace;
  }

  .thumb-progress-bar {
    position: absolute;
    bottom: 0; left: 0;
    height: 2px;
    background: #f59e0b;
    transition: width 0.4s ease-out;
  }

  .thumb-img {
    width: 100%; height: 100%;
    object-fit: cover;
  }

  .thumb-done {
    display: flex;
    align-items: center;
    justify-content: center;
    color: #10b981;
    font-size: 20px;
  }
</style>
