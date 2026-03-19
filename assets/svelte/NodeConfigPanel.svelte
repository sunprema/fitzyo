<script lang="ts">
  let { selected_node = null, node_registry = [] } = $props<{
    selected_node: any | null;
    node_registry: any[];
  }>();

  let active_tab = $state<'config' | 'info'>('config');

  let reg = $derived(
    selected_node
      ? node_registry.find((r: any) => String(r.kind) === selected_node.type)
      : null
  );

  const colorMap: Record<string, string> = {
    violet: '#8B5CF6',
    amber:  '#F59E0B',
    blue:   '#3B82F6',
    teal:   '#14B8A6',
    gray:   '#888888',
  };

  let accent = $derived(colorMap[reg?.color ?? 'gray'] ?? '#888');
</script>

<aside class="config-panel">
  {#if selected_node && reg}
    <!-- Node identity header -->
    <div class="panel-identity" style={`border-left: 3px solid ${accent}`}>
      <span class="panel-icon">{reg.icon}</span>
      <div class="panel-id-text">
        <div class="panel-node-label">{selected_node.data?.label ?? reg.label}</div>
        <div class="panel-node-kind">{selected_node.type}</div>
      </div>
    </div>

    <!-- Tabs -->
    <div class="panel-tabs">
      <button
        class="tab"
        class:active={active_tab === 'config'}
        onclick={() => (active_tab = 'config')}
      >Config</button>
      <button
        class="tab"
        class:active={active_tab === 'info'}
        onclick={() => (active_tab = 'info')}
      >Handles</button>
    </div>

    <div class="panel-body">
      {#if active_tab === 'config'}
        <!-- Data fields from the node -->
        {#if Object.keys(selected_node.data ?? {}).filter(k => !k.startsWith('_')).length > 0}
          <div class="section-title">Data</div>
          {#each Object.entries(selected_node.data ?? {}).filter(([k]) => !k.startsWith('_')) as [key, val]}
            <div class="config-row">
              <span class="config-label">{key}</span>
              <span class="config-value">{String(val).slice(0, 24)}</span>
            </div>
          {/each}
        {:else}
          <div class="empty-hint">No config data set for this node.</div>
        {/if}

        <!-- Description -->
        {#if reg.description}
          <div class="section-title" style="margin-top: 16px;">About</div>
          <p class="node-desc">{reg.description}</p>
        {/if}
      {:else}
        <!-- Inputs -->
        {#if reg.inputs.length > 0}
          <div class="section-title">Inputs</div>
          {#each reg.inputs as input}
            <div class="handle-row">
              <div class="handle-dot handle-target" style={`background: ${accent}`}></div>
              <span class="handle-name">{input.name}</span>
              <span class="handle-kind">{input.kind}</span>
              {#if input.required}<span class="handle-required">required</span>{/if}
            </div>
          {/each}
        {/if}

        <!-- Outputs -->
        {#if reg.outputs.length > 0}
          <div class="section-title" style="margin-top: 14px;">Outputs</div>
          {#each reg.outputs as output}
            <div class="handle-row">
              <div class="handle-dot handle-source" style={`border-color: ${accent}`}></div>
              <span class="handle-name">{output.name}</span>
              <span class="handle-kind">{output.kind}</span>
            </div>
            {#if output.doc}
              <div class="handle-doc">{output.doc}</div>
            {/if}
          {/each}
        {/if}
      {/if}
    </div>
  {:else}
    <div class="empty-panel">
      <div class="empty-icon">◈</div>
      <div class="empty-text">Select a node to view its config</div>
    </div>
  {/if}
</aside>

<style>
  .config-panel {
    width: 248px;
    background: #0d1117;
    border-left: 1px solid rgba(255,255,255,0.06);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    overflow: hidden;
  }

  .panel-identity {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 14px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .panel-icon { font-size: 18px; }

  .panel-id-text { flex: 1; min-width: 0; }

  .panel-node-label {
    font-size: 13px;
    font-weight: 600;
    color: #f0f4f8;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .panel-node-kind {
    font-size: 10px;
    color: #4a5568;
    font-family: 'DM Mono', monospace;
    margin-top: 1px;
  }

  .panel-tabs {
    display: flex;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .tab {
    flex: 1;
    padding: 8px 0;
    font-size: 11.5px;
    font-weight: 500;
    color: #4a5568;
    background: none;
    border: none;
    border-bottom: 2px solid transparent;
    cursor: pointer;
    transition: all 0.1s;
  }
  .tab:hover:not(.active) { color: #8b97a8; }
  .tab.active { color: #f0f4f8; border-bottom-color: #8B5CF6; }

  .panel-body {
    flex: 1;
    overflow-y: auto;
    padding: 14px;
  }
  .panel-body::-webkit-scrollbar { width: 3px; }
  .panel-body::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }

  .section-title {
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: #4a5568;
    margin-bottom: 8px;
  }

  .config-row {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
    gap: 8px;
  }

  .config-label {
    font-size: 12px;
    color: #8b97a8;
    font-family: 'DM Mono', monospace;
    flex-shrink: 0;
  }

  .config-value {
    font-size: 11px;
    color: #f0f4f8;
    background: #1a2230;
    padding: 2px 7px;
    border-radius: 4px;
    border: 1px solid rgba(255,255,255,0.06);
    max-width: 130px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    font-family: 'DM Mono', monospace;
  }

  .handle-row {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 6px;
  }

  .handle-dot {
    width: 8px;
    height: 8px;
    border-radius: 50%;
    flex-shrink: 0;
  }
  .handle-target { opacity: 0.9; }
  .handle-source { background: transparent; border: 2px solid; }

  .handle-name {
    font-size: 11.5px;
    color: #f0f4f8;
    font-family: 'DM Mono', monospace;
    flex: 1;
  }

  .handle-kind {
    font-size: 10px;
    color: #4a5568;
    font-family: 'DM Mono', monospace;
  }

  .handle-required {
    font-size: 9px;
    color: #F59E0B;
    background: rgba(245,158,11,0.1);
    border: 1px solid rgba(245,158,11,0.2);
    padding: 1px 5px;
    border-radius: 3px;
  }

  .handle-doc {
    font-size: 10px;
    color: #4a5568;
    margin: -2px 0 8px 16px;
    line-height: 1.4;
  }

  .node-desc {
    font-size: 12px;
    color: #8b97a8;
    line-height: 1.5;
    margin: 0;
  }

  .empty-hint {
    font-size: 12px;
    color: #4a5568;
    font-style: italic;
  }

  .empty-panel {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 10px;
    color: #4a5568;
  }

  .empty-icon { font-size: 28px; opacity: 0.4; }

  .empty-text {
    font-size: 12px;
    text-align: center;
    line-height: 1.5;
  }
</style>
