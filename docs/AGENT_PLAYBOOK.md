# FitzYo Agent Playbook

How an external AI agent drives the FitzYo store through WebMCP, and the
Hawaii scenario step by step. FitzYo itself has no intelligence: everything
below is what the *agent* does with its own private context
(`context/FAMILY.md`, `context/WARDROBE.md`, `context/TRIP.md`). The store
only ever sees the constraints the agent chooses to send.

## 1. Connecting

The store page registers its tools on whatever WebMCP surface the browser
provides:

- **Native WebMCP** — a browser or extension that exposes
  `navigator.modelContext` / `document.modelContext`. The page calls
  `registerTool` for every tool as soon as the surface exists (it also
  watches for a surface injected shortly after page load). The header flips
  to **Agent Connected ●** the moment that happens.
- **postMessage bridge** — for an embedding shell (iframe or opener). Send
  `{type: "tools/list", id}` to get `{type: "tools/list:result", id, tools}`,
  and `{type: "tools/call", id, tool, input}` to get
  `{type: "tools/call:result", id, result | error}`. The page broadcasts
  `{type: "tools/changed", tools}` whenever the surface changes. Only
  same-origin messages are accepted unless the hook element sets
  `data-webmcp-allowed-origins`.

Every call round-trips over the LiveView socket and executes inside the same
process that renders the human's page, so the UI updates in the same frame as
the reply.

## 2. The tool surface

| Tool | Kind | What it does |
| --- | --- | --- |
| `get_store_info` | read | Store facts, catalog size, facet vocabularies |
| `get_categories` | read | Category ids, names, counts |
| `search_products` | state | Sets the search box (clears filters unless `keep_filters`); returns matches |
| `filter_products` | state | Replaces the active filters; the sidebar shows them |
| `get_product` | read | Full product incl. structured fit |
| `get_variants` | read | Every size/color with price and availability |
| `get_size_guide` | read | Chest/waist/hip/neck/sleeve/inseam per size |
| `find_matching_variants` | state | In-stock variants for a set of constraints; optional `label` badges products "Fits Dad" |
| `compare_products` | state | Side-by-side table in the human's view |
| `get_cart` | read | Lines and totals |
| `add_to_cart` | write | Adds or increments a variant; optional `label` |
| `remove_from_cart` | write | Removes a line |
| `update_cart_item` | write | Sets quantity/label |
| `clear_cart` | write | Empties the cart |
| `recommend_product` | state | Shows an agent-written reason on a product |
| `present_plan` | state | Shows the agent's plan in the agent panel |
| `agent_update` | state | Banner status, progress, and streamed thoughts |
| `ask_human` | blocking | Ask the shopper a question in the agent panel; resolves when they answer |
| `propose_cart` | blocking | One priced, grouped basket the shopper accepts in a single action |
| `get_store_state` | read | What the human currently sees, including their overrides |
| `focus_product` | ui | Opens and highlights a product, optionally a variant |
| `focus_filter` | ui | Highlights a filter section |

There is no checkout tool. The human opens the cart drawer, reviews the
order line by line, and places it with a press-and-hold gesture that the
page only accepts from trusted input together with a single-use nonce
(WEBMCP_SPEC §52). A scripted click does nothing. Every review, cancel,
block, and approval is written to the activity feed as a human entry, so the
audit trail shows who did what. Opening a
product page preselects the variant an agent recommended for it (or the one
already in the cart), so the "Add to Cart" button always matches what the
recommendation card says.

Errors are structured. A rejected call carries a JSON string:

```json
{"success": false, "code": "VARIANT_UNAVAILABLE", "message": "…", "product_id": "prod_1005", "variant_id": "prod_1005_navy_xl"}
```

Codes: `PRODUCT_NOT_FOUND`, `VARIANT_NOT_FOUND`, `VARIANT_UNAVAILABLE`,
`INVALID_FILTER`, `INVALID_CATEGORY`, `INVALID_QUANTITY`,
`CART_ITEM_NOT_FOUND`, `INVALID_OPERATION`.

## 3. Privacy rule

Send constraints, never the profile. `find_matching_variants` for Dad is:

```json
{"category": "shirts", "gender": "men", "size": "XL", "color": ["blue", "black", "navy"],
 "brand": ["Columbia", "Patagonia"], "fit": "relaxed", "activity": ["travel", "beach"],
 "price_max": 80, "label": "Dad"}
```

The `label` is the only thing the store learns about "Dad", and it is only
used to render a badge for the human in this session.

## 4. The Hawaii scenario

> "We're going to Hawaii for seven days. Plan what everyone should wear and
> find what we're missing."

The agent reasons over `context/*.md` first (needs = itinerary × activities −
wardrobe), then executes against the store. A good sequence:

1. **Narrate**: `agent_update` with `status: "working"`, a `message`, and
   `progress`. Stream reasoning with `thought` (and `append: true` for
   chunks); it shows in the activity feed and the banner. Finish with
   `status: "done"`.
2. **Orient**: `get_store_info`, `get_categories`.
3. **Show the plan**: `present_plan` with one group per person, marking what
   they already `have` and what they `need`. The human sees it in the agent
   panel immediately.
4. **Per need, per person**: `find_matching_variants` with that person's
   constraints and `label`. Read `strict` and `match` in the reply: a
   `strict: false` reply means no variant satisfied every preference; the
   closest ones come back with a per-constraint match map, so the agent can
   decide whether to relax a color or brand.
5. **Choose**: `compare_products` on the finalists when it helps, then
   `recommend_product` with a one-sentence reason the human will read.
6. **Add**: `add_to_cart` with `label` so the cart drawer groups lines by
   person. Watch `cart.subtotal` against the budget in `TRIP.md`.
7. **Update the plan**: `present_plan` again with items marked `added`.
8. **Hand off**: `focus_product` on anything worth a second look, then tell
   the human the cart is ready for review.

Refinements arrive as plain requests and map to the same tools:

| Human says | Agent does |
| --- | --- |
| "Keep it under $500." | Re-plan; `remove_from_cart` / `update_cart_item` until `get_cart().subtotal` fits; `present_plan` |
| "Dad doesn't need another shirt." | `remove_from_cart` Dad's shirt lines; mark the need `skipped` in `present_plan` |
| "No red." | Constraints already exclude red; `filter_products` without red so the view matches |
| "Show me Mom's dress." | `focus_product` with the variant |

## 4b. Handing a decision back: `ask_human`

When a choice is genuinely the shopper's — spending past the budget, one of
two products, a size you cannot derive — call `ask_human` and await it. The
question renders in the agent panel with up to four options (options with a
`product_id` render as product cards), an optional "Other…" field, and a
"Not now" control. The banner switches to **Waiting for you** and the shopper
keeps full control of the store meanwhile. The call resolves with:

```json
{"answered": true, "selected": ["skip_shirt"], "free_text": null, "question_id": "q_7f3a"}
{"answered": false, "reason": "dismissed" | "timeout" | "superseded", "question_id": "q_7f3a"}
```

`answered: false` is a normal outcome: proceed without them or stop, never
assume a default. One question is open at a time; a new one supersedes the
old. If your side loses the reply, `get_store_state.pending_question` shows
whether a question is still open. Phrase questions from what the store can
see; a free-text question is the easiest place to leak private context.

The call blocks up to `timeout_ms` (default 2 minutes, max 10). The page's own
transport allows that; if your agent runtime has a shorter per-call limit,
raise it for this tool or poll `pending_question` instead.

## 4c. One basket, one decision: `propose_cart`

When you have assembled a whole outfit or trip, send it as one proposal
instead of many `add_to_cart` calls. Each line carries a `variant_id`, a
`quantity`, a `label`, a one-line `reason`, optionally `optional: true` for
nice-to-haves (rendered unticked) and up to three `alternatives` you would
accept. Send `budget` (total and per label) when the shopper gave you one.

The store prices everything at current prices, drops unknown or sold-out
variants into `unavailable` (preselecting an offered alternative when one is
in stock), groups by label with subtotals, and shows the budget overage live
as the shopper ticks and unticks lines, changes quantities, or swaps. The
banner shows **Waiting for you** and the store stays fully usable meanwhile.

Accepting adds the selected lines to the cart as it is *then* (the shopper
may have edited it) and never checks out. Read the result rather than
assuming your proposal went through:

```json
{"accepted": true, "applied": [...], "declined": ["prod_1024_white_m"],
 "substituted": [{"proposed": "prod_1012_navy_36", "chosen": "prod_1008_navy_xl"}],
 "unavailable": [{"variant_id": "prod_1024_coral_m", "reason": "out_of_stock"}],
 "cart": {"item_count": 12, "subtotal": 595, "currency": "USD"},
 "budget": {"total": 600, "over_by": 0}}
{"accepted": false, "reason": "rejected" | "timeout" | "superseded", "cart": {...}}
```

`mode: "replace"` clears the cart on accept only. Lines added this way are
marked `source: "proposal"` in the cart, so the order record shows what the
human chose by hand, what an agent added, and what an agent proposed and the
human accepted. One pending decision at a time: a proposal supersedes an open
question and vice versa. Rule of thumb: if the choice is *which lines*,
propose; if it is *which strategy*, `ask_human`.

## 5. Human override

Humans can change anything at any time: toggle a filter, pick another color,
remove a cart line, dismiss a badge or the plan. Before assuming the world is
as it was left, call `get_store_state`. It returns the current search,
filters, selected product/variant, comparison, cart totals, the agent's own
annotations, and the plan, all as the human currently sees them. Human
actions win over stale agent assumptions.

## 6. Rehearsing without an agent

`scripts/agent_rehearsal.mjs` plays the Hawaii scenario against a running
store using Chrome's DevTools protocol. It injects a minimal
`navigator.modelContext`, exactly what a WebMCP-capable browser provides,
and then calls the registered tools in the order above:

```sh
mix phx.server
node scripts/agent_rehearsal.mjs http://localhost:4000
```

It prints every call and reply and leaves screenshots in `tmp/rehearsal/`.
Use it to check the store before a demo; it contains no reasoning, only the
scripted outcome of the reasoning an external agent would do.
