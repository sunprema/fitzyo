<script lang="ts">
  let {
    reasoning = '',
    visible = false,
    onclose,
  } = $props<{
    reasoning: string;
    visible: boolean;
    onclose: () => void;
  }>();
</script>

{#if visible && reasoning}
  <div class="reasoning-overlay" role="dialog" aria-label="Generation reasoning">
    <div class="reasoning-card">
      <div class="reasoning-header">
        <span class="reasoning-title">✦ Reasoning</span>
        <button class="close-btn" onclick={onclose} aria-label="Close reasoning">✕</button>
      </div>
      <div class="reasoning-body">
        <p class="reasoning-text">{reasoning}</p>
      </div>
    </div>
  </div>
{/if}

<style>
  .reasoning-overlay {
    position: absolute;
    inset: 0;
    display: flex;
    align-items: center;
    justify-content: center;
    background: rgba(0,0,0,0.55);
    backdrop-filter: blur(3px);
    z-index: 20;
    padding: 20px;
  }

  .reasoning-card {
    background: #131920;
    border: 1px solid rgba(139,92,246,0.25);
    border-radius: 10px;
    width: 100%;
    max-width: 480px;
    max-height: 60vh;
    display: flex;
    flex-direction: column;
    box-shadow: 0 8px 40px rgba(0,0,0,0.6);
  }

  .reasoning-header {
    display: flex;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .reasoning-title {
    flex: 1;
    font-size: 12px;
    font-weight: 600;
    color: #8b5cf6;
    letter-spacing: 0.05em;
  }

  .close-btn {
    background: none;
    border: none;
    color: #4a5568;
    cursor: pointer;
    font-size: 14px;
    padding: 2px 4px;
    border-radius: 4px;
    transition: color 0.1s;
  }

  .close-btn:hover { color: #f0f4f8; }

  .reasoning-body {
    flex: 1;
    overflow-y: auto;
    padding: 16px;
  }

  .reasoning-body::-webkit-scrollbar { width: 3px; }
  .reasoning-body::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.1); border-radius: 3px; }

  .reasoning-text {
    font-size: 12.5px;
    color: #8b97a8;
    line-height: 1.7;
    margin: 0;
    white-space: pre-wrap;
  }
</style>
