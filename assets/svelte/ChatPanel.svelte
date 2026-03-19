<script lang="ts">
  import { tick } from 'svelte';

  type Message = {
    id: number;
    role: 'user' | 'assistant';
    content: string;
    reasoning?: string;
    error?: boolean;
  };

  let {
    messages = [],
    generating = false,
    live,
    onshow_reasoning,
  } = $props<{
    messages: Message[];
    generating: boolean;
    live: any;
    onshow_reasoning?: (reasoning: string) => void;
  }>();

  let input = $state('');
  let listEl: HTMLDivElement;

  const suggestions = [
    'Add a style reference to control the aesthetic',
    'Parallelise the generation steps',
    'Add a cron trigger to run daily',
    'Insert an audio mixer before export',
  ];

  // Scroll to bottom whenever messages change
  $effect(() => {
    if (messages.length > 0) {
      tick().then(() => {
        if (listEl) listEl.scrollTop = listEl.scrollHeight;
      });
    }
  });

  function submit() {
    const prompt = input.trim();
    if (!prompt || generating) return;

    const event = messages.length === 0 ? 'nl_generate' : 'nl_refine';
    const payload = messages.length === 0
      ? { prompt }
      : { instruction: prompt };

    live.pushEvent(event, payload);
    input = '';
  }

  function useSuggestion(text: string) {
    input = text;
    submit();
  }
</script>

<div class="chat-panel">
  <div class="chat-header">
    <span class="chat-title">AI Architect</span>
    <span class="chat-badge">GPT</span>
  </div>

  <!-- Message list -->
  <div class="message-list" bind:this={listEl}>
    {#if messages.length === 0 && !generating}
      <div class="empty-state">
        <div class="empty-icon">✦</div>
        <div class="empty-title">Describe your workflow</div>
        <div class="empty-sub">I'll build the graph for you.</div>

        <div class="suggestions">
          {#each suggestions as s}
            <button class="suggestion-chip" onclick={() => useSuggestion(s)}>
              {s}
            </button>
          {/each}
        </div>
      </div>
    {:else}
      {#each messages as msg (msg.id)}
        <div class="message" class:user={msg.role === 'user'} class:assistant={msg.role === 'assistant'} class:error={msg.error}>
          <div class="bubble">
            {msg.content}
          </div>
          {#if msg.role === 'assistant' && msg.reasoning && !msg.error}
            <button
              class="reasoning-link"
              onclick={() => onshow_reasoning?.(msg.reasoning!)}
            >
              Show reasoning →
            </button>
          {/if}
        </div>
      {/each}

      {#if generating}
        <div class="message assistant">
          <div class="bubble generating-bubble">
            <span class="gen-dot"></span>
            <span class="gen-dot"></span>
            <span class="gen-dot"></span>
          </div>
        </div>
      {/if}
    {/if}
  </div>

  <!-- Input area -->
  <div class="chat-input-area">
    <textarea
      class="chat-input"
      placeholder={messages.length === 0 ? 'Describe your workflow…' : 'Refine the graph…'}
      bind:value={input}
      rows={2}
      disabled={generating}
      onkeydown={(e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
          e.preventDefault();
          submit();
        }
      }}
    ></textarea>
    <button
      class="send-btn"
      onclick={submit}
      disabled={!input.trim() || generating}
      aria-label="Send"
    >
      {#if generating}
        <span class="spinner">⟳</span>
      {:else}
        →
      {/if}
    </button>
  </div>
</div>

<style>
  .chat-panel {
    width: 220px;
    background: #0d1117;
    border-right: 1px solid rgba(255,255,255,0.06);
    display: flex;
    flex-direction: column;
    flex-shrink: 0;
    overflow: hidden;
  }

  .chat-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 10px 14px 8px;
    border-bottom: 1px solid rgba(255,255,255,0.06);
    flex-shrink: 0;
  }

  .chat-title {
    font-size: 11px;
    font-weight: 500;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: #4a5568;
    flex: 1;
  }

  .chat-badge {
    font-size: 9px;
    color: #8b5cf6;
    background: rgba(139,92,246,0.12);
    border: 1px solid rgba(139,92,246,0.2);
    padding: 1px 5px;
    border-radius: 3px;
    font-family: 'DM Mono', monospace;
  }

  /* ── Message list ─────────────────────────────────────────────────────────── */

  .message-list {
    flex: 1;
    overflow-y: auto;
    padding: 10px 10px 6px;
    display: flex;
    flex-direction: column;
    gap: 8px;
  }

  .message-list::-webkit-scrollbar { width: 3px; }
  .message-list::-webkit-scrollbar-thumb { background: rgba(255,255,255,0.08); border-radius: 3px; }

  /* ── Empty state ──────────────────────────────────────────────────────────── */

  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 20px 8px 10px;
    gap: 6px;
  }

  .empty-icon {
    font-size: 22px;
    color: #8b5cf6;
    opacity: 0.6;
  }

  .empty-title {
    font-size: 12px;
    font-weight: 600;
    color: #8b97a8;
  }

  .empty-sub {
    font-size: 11px;
    color: #4a5568;
    margin-bottom: 10px;
  }

  .suggestions {
    display: flex;
    flex-direction: column;
    gap: 5px;
    width: 100%;
  }

  .suggestion-chip {
    text-align: left;
    font-size: 10.5px;
    color: #8b97a8;
    background: #131920;
    border: 1px solid rgba(255,255,255,0.06);
    border-radius: 5px;
    padding: 5px 8px;
    cursor: pointer;
    line-height: 1.4;
    transition: background 0.1s, color 0.1s;
  }

  .suggestion-chip:hover {
    background: #1a2230;
    color: #f0f4f8;
  }

  /* ── Message bubbles ──────────────────────────────────────────────────────── */

  .message {
    display: flex;
    flex-direction: column;
    gap: 3px;
  }

  .message.user { align-items: flex-end; }
  .message.assistant { align-items: flex-start; }

  .bubble {
    max-width: 90%;
    font-size: 11.5px;
    line-height: 1.5;
    padding: 6px 9px;
    border-radius: 8px;
    word-break: break-word;
  }

  .message.user .bubble {
    background: rgba(139,92,246,0.18);
    color: #d4bcf5;
    border: 1px solid rgba(139,92,246,0.2);
    border-bottom-right-radius: 3px;
  }

  .message.assistant .bubble {
    background: #131920;
    color: #8b97a8;
    border: 1px solid rgba(255,255,255,0.06);
    border-bottom-left-radius: 3px;
  }

  .message.error .bubble {
    background: rgba(239,68,68,0.1);
    color: #f87171;
    border-color: rgba(239,68,68,0.2);
  }

  .reasoning-link {
    font-size: 10px;
    color: #8b5cf6;
    background: none;
    border: none;
    cursor: pointer;
    padding: 0 2px;
    opacity: 0.7;
    transition: opacity 0.1s;
  }

  .reasoning-link:hover { opacity: 1; }

  /* ── Generating animation ─────────────────────────────────────────────────── */

  .generating-bubble {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 10px 12px;
  }

  .gen-dot {
    width: 5px;
    height: 5px;
    border-radius: 50%;
    background: #4a5568;
    animation: dot-pulse 1.2s ease-in-out infinite;
  }

  .gen-dot:nth-child(2) { animation-delay: 0.2s; }
  .gen-dot:nth-child(3) { animation-delay: 0.4s; }

  @keyframes dot-pulse {
    0%, 80%, 100% { opacity: 0.3; transform: scale(0.8); }
    40%           { opacity: 1;   transform: scale(1); }
  }

  /* ── Input area ───────────────────────────────────────────────────────────── */

  .chat-input-area {
    flex-shrink: 0;
    display: flex;
    align-items: flex-end;
    gap: 6px;
    padding: 8px 10px;
    border-top: 1px solid rgba(255,255,255,0.06);
  }

  .chat-input {
    flex: 1;
    background: #131920;
    border: 1px solid rgba(255,255,255,0.08);
    border-radius: 6px;
    padding: 6px 8px;
    font-size: 11.5px;
    color: #f0f4f8;
    resize: none;
    outline: none;
    line-height: 1.4;
    font-family: inherit;
    box-sizing: border-box;
  }

  .chat-input:focus { border-color: rgba(139,92,246,0.4); }
  .chat-input::placeholder { color: #4a5568; }
  .chat-input:disabled { opacity: 0.5; }

  .send-btn {
    width: 28px;
    height: 28px;
    background: rgba(139,92,246,0.2);
    color: #8b5cf6;
    border: 1px solid rgba(139,92,246,0.3);
    border-radius: 6px;
    cursor: pointer;
    font-size: 14px;
    display: flex;
    align-items: center;
    justify-content: center;
    flex-shrink: 0;
    transition: background 0.15s;
    line-height: 1;
  }

  .send-btn:hover:not(:disabled) { background: rgba(139,92,246,0.35); }
  .send-btn:disabled { opacity: 0.35; cursor: default; }

  .spinner {
    display: inline-block;
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from { transform: rotate(0deg); }
    to   { transform: rotate(360deg); }
  }
</style>
