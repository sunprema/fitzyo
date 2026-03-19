<script lang="ts">
  let { node_registry = [] } = $props<{
    node_registry: Array<{
      kind: string | symbol;
      label: string;
      category: string | symbol;
      color: string | symbol;
      icon: string;
      description: string;
    }>;
  }>();

  let search = $state('');

  const categoryOrder = ['trigger', 'generation', 'assembly', 'data', 'control'];
  const categoryLabels: Record<string, string> = {
    trigger: 'Triggers',
    generation: 'Generation',
    assembly: 'Assembly',
    data: 'Data',
    control: 'Control',
  };

  const colorMap: Record<string, { icon: string; dot: string }> = {
    violet: { icon: 'icon-generation', dot: '#8B5CF6' },
    amber:  { icon: 'icon-trigger',    dot: '#F59E0B' },
    blue:   { icon: 'icon-assembly',   dot: '#3B82F6' },
    teal:   { icon: 'icon-data',       dot: '#14B8A6' },
    gray:   { icon: 'icon-control',    dot: '#888888' },
  };

  let filtered = $derived(
    search.trim()
      ? node_registry.filter(n =>
          n.label.toLowerCase().includes(search.toLowerCase()) ||
          String(n.kind).includes(search.toLowerCase())
        )
      : node_registry
  );

  let grouped = $derived(
    categoryOrder.reduce((acc, cat) => {
      const nodes = filtered.filter(n => String(n.category) === cat);
      if (nodes.length) acc[cat] = nodes;
      return acc;
    }, {} as Record<string, typeof node_registry>)
  );

  function onDragStart(event: DragEvent, kind: string) {
    event.dataTransfer!.effectAllowed = 'move';
    event.dataTransfer!.setData('text/plain', kind);
  }
</script>

<aside class="palette">
  <div class="palette-header">
    <span class="palette-title">Nodes</span>
  </div>

  <div class="palette-search">
    <div class="search-wrap">
      <span class="search-icon">⌕</span>
      <input
        class="search-input"
        placeholder="Search nodes…"
        bind:value={search}
      />
    </div>
  </div>

  <div class="palette-scroll">
    {#each Object.entries(grouped) as [cat, nodes]}
      <div class="palette-section">
        <div class="section-label">{categoryLabels[cat] ?? cat}</div>
        {#each nodes as node}
          <div
            class="palette-node"
            draggable="true"
            ondragstart={(e) => onDragStart(e, String(node.kind))}
            title={node.description}
          >
            <div class="node-icon {colorMap[String(node.color)]?.icon ?? 'icon-control'}">
              {node.icon}
            </div>
            <span class="node-label">{node.label}</span>
          </div>
        {/each}
      </div>
    {/each}

    {#if Object.keys(grouped).length === 0}
      <div class="no-results">No nodes match "{search}"</div>
    {/if}
  </div>
</aside>

<style>
  .palette {
    width: 220px;
    background: #0d1117;
    border-right: 1px solid rgba(255,255,255,0.06);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    overflow: hidden;
  }

  .palette-header {
    padding: 10px 14px 6px;
    flex-shrink: 0;
  }

  .palette-title {
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: #4a5568;
  }

  .palette-search {
    padding: 6px 12px 10px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .search-wrap { position: relative; }

  .search-icon {
    position: absolute;
    left: 8px;
    top: 50%;
    transform: translateY(-50%);
    font-size: 13px;
    color: #4a5568;
    pointer-events: none;
  }

  .search-input {
    width: 100%;
    background: #131920;
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 6px;
    padding: 5px 10px 5px 26px;
    font-size: 12px;
    color: #f0f4f8;
    outline: none;
    box-sizing: border-box;
  }
  .search-input:focus { border-color: #8B5CF6; }
  .search-input::placeholder { color: #4a5568; }

  .palette-scroll {
    flex: 1;
    overflow-y: auto;
    padding: 6px 0;
  }
  .palette-scroll::-webkit-scrollbar { width: 3px; }
  .palette-scroll::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }

  .palette-section { margin-bottom: 4px; }

  .section-label {
    font-size: 10px;
    font-weight: 500;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: #4a5568;
    padding: 6px 14px 3px;
  }

  .palette-node {
    display: flex;
    align-items: center;
    gap: 9px;
    padding: 6px 14px;
    cursor: grab;
    transition: background 0.1s;
    font-size: 12px;
    color: #8b97a8;
  }
  .palette-node:hover { background: #1a2230; color: #f0f4f8; }
  .palette-node:active { cursor: grabbing; }

  .node-icon {
    width: 24px;
    height: 24px;
    border-radius: 6px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 12px;
    flex-shrink: 0;
  }

  :global(.icon-trigger)    { background: rgba(245,158,11,0.12); border: 1px solid rgba(245,158,11,0.2); }
  :global(.icon-generation) { background: rgba(139,92,246,0.12); border: 1px solid rgba(139,92,246,0.2); }
  :global(.icon-assembly)   { background: rgba(59,130,246,0.12);  border: 1px solid rgba(59,130,246,0.2); }
  :global(.icon-data)       { background: rgba(20,184,166,0.12);  border: 1px solid rgba(20,184,166,0.2); }
  :global(.icon-control)    { background: rgba(139,139,139,0.1);  border: 1px solid rgba(139,139,139,0.15); }

  .node-label {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .no-results {
    padding: 20px 14px;
    font-size: 12px;
    color: #4a5568;
    text-align: center;
  }
</style>
