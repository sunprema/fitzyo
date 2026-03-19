<script lang="ts">
  let { nodes = [], node_states = {}, node_registry = [] } = $props<{
    nodes: any[];
    node_states: Record<string, any>;
    node_registry: any[];
  }>();

  const colorMap: Record<string, string> = {
    violet: '#8B5CF6',
    amber:  '#F59E0B',
    blue:   '#3B82F6',
    teal:   '#14B8A6',
    gray:   '#888888',
  };

  // Sort nodes left-to-right by their x position (rough topo order for display)
  let sortedNodes = $derived(
    [...nodes].sort((a, b) => (a.position?.x ?? 0) - (b.position?.x ?? 0))
  );
</script>

<div class="timeline">
  <div class="timeline-header">
    <span class="timeline-title">Timeline</span>
    <span class="timeline-count">{nodes.length} node{nodes.length !== 1 ? 's' : ''}</span>
  </div>

  <div class="timeline-track">
    {#each sortedNodes as node}
      {@const ns = node_states[node.id] ?? { status: 'idle' }}
      {@const reg = node_registry.find(r => String(r.kind) === node.type)}
      {@const accent = colorMap[reg?.color ?? 'gray'] ?? '#888'}
      {@const label = node.data?.label ?? reg?.label ?? node.type}

      <div
        class="clip"
        class:clip-pending={ns.status === 'idle' || ns.status === 'pending'}
        class:clip-running={ns.status === 'generating'}
        class:clip-done={ns.status === 'complete'}
        style={`border-color: ${ns.status === 'generating' ? '#F59E0B' : ns.status === 'complete' ? 'rgba(16,185,129,0.4)' : 'rgba(255,255,255,0.06)'}`}
      >
        {#if ns.status === 'complete' && ns.thumbnail_url}
          <img class="clip-thumb" src={ns.thumbnail_url} alt={label} />
        {:else}
          <div class="clip-icon" style={`color: ${accent}`}>{reg?.icon ?? '⬜'}</div>
        {/if}

        <div class="clip-footer">
          <span class="clip-label">{label}</span>
          {#if ns.status === 'generating'}
            <span class="clip-pct">{ns.progress ?? 0}%</span>
          {:else if ns.status === 'complete'}
            <span class="clip-done-mark">✓</span>
          {/if}
        </div>

        {#if ns.status === 'generating'}
          <div class="clip-progress" style={`width: ${ns.progress ?? 0}%`}></div>
        {/if}
      </div>
    {/each}

    {#if nodes.length === 0}
      <div class="timeline-empty">Drop nodes onto the canvas to build your workflow</div>
    {/if}
  </div>
</div>

<style>
  .timeline {
    height: 96px;
    background: #0d1117;
    border-top: 1px solid rgba(255,255,255,0.06);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
  }

  .timeline-header {
    display: flex;
    align-items: center;
    padding: 5px 14px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
    gap: 8px;
  }

  .timeline-title {
    font-size: 10px;
    font-weight: 500;
    text-transform: uppercase;
    letter-spacing: 0.07em;
    color: #4a5568;
    flex: 1;
  }

  .timeline-count {
    font-size: 10px;
    color: #4a5568;
    font-family: 'DM Mono', monospace;
  }

  .timeline-track {
    flex: 1;
    display: flex;
    align-items: center;
    padding: 0 12px;
    gap: 6px;
    overflow-x: auto;
  }
  .timeline-track::-webkit-scrollbar { height: 3px; }
  .timeline-track::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }

  .clip {
    height: 52px;
    min-width: 72px;
    border-radius: 6px;
    border: 1px solid rgba(255,255,255,0.06);
    background: #131920;
    flex-shrink: 0;
    position: relative;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    transition: border-color 0.2s;
    cursor: pointer;
  }

  .clip-running { animation: clip-pulse 1.5s ease-in-out infinite; }
  @keyframes clip-pulse {
    0%, 100% { opacity: 1; }
    50%       { opacity: 0.7; }
  }

  .clip-thumb {
    position: absolute;
    inset: 0;
    width: 100%; height: 100%;
    object-fit: cover;
    opacity: 0.8;
  }

  .clip-icon { font-size: 16px; }

  .clip-footer {
    position: absolute;
    bottom: 0; left: 0; right: 0;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 2px 5px;
    background: rgba(0,0,0,0.5);
  }

  .clip-label {
    font-size: 9px;
    color: rgba(255,255,255,0.6);
    font-family: 'DM Mono', monospace;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    max-width: 55px;
  }

  .clip-pct {
    font-size: 9px;
    color: #F59E0B;
    font-family: 'DM Mono', monospace;
  }

  .clip-done-mark {
    font-size: 9px;
    color: #10b981;
  }

  .clip-progress {
    position: absolute;
    bottom: 0; left: 0;
    height: 2px;
    background: #F59E0B;
    transition: width 0.4s ease-out;
  }

  .timeline-empty {
    font-size: 11px;
    color: #4a5568;
    font-style: italic;
  }
</style>
