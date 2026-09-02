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
| `clear_annotations` | state | Removes the agent's own matches and recommendations, by label, product, or source |
| `register_party_member` | state | Registers one person as derived constraints; unlocks `member:` and per-member badges and budgets |
| `remove_party_member` | state | Forgets a registered person and clears their badges |
| `present_plan` | state | Shows the agent's plan in the agent panel |
| `agent_update` | state | Banner status, progress, and streamed thoughts |
| `ask_human` | blocking | Ask the shopper a question in the agent panel; resolves when they answer |
| `propose_cart` | blocking | One priced, grouped basket the shopper accepts in a single action |
| `request_capability` | blocking | Asks the shopper to grant a tier of tools (`cart`), with a ceiling and an expiry |
| `get_store_state` | read | What the human currently sees, including their overrides |
| `focus_product` | ui | Opens and highlights a product, optionally a variant |
| `focus_filter` | ui | Highlights a filter section |

Tools come in three tiers. `read` and `suggest` are yours on connect;
`cart` (`add_to_cart`, `remove_from_cart`, `update_cart_item`,
`clear_cart`, `propose_cart`) is not: a call into it fails with
`CAPABILITY_NOT_GRANTED` until the shopper allows it through
`request_capability` (§4d). `get_store_info.capability_tiers` lists the
grouping and `granted_capabilities` what you have now.

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
`CART_ITEM_NOT_FOUND`, `INVALID_OPERATION`, `CAPABILITY_NOT_GRANTED`
(carries `capability` and a `hint`), `CAPABILITY_SCOPE_EXCEEDED` (carries
`max_spend`, `cart_subtotal`, `projected_total`), `MEMBER_NOT_FOUND`,
`PRIVATE_CONTEXT_REJECTED` (names the fields that do not belong on a
retailer's server).

## 3. Privacy rule

Send constraints, never the profile. `find_matching_variants` for Dad is:

```json
{"category": "shirts", "gender": "men", "size": "XL", "color": ["blue", "black", "navy"],
 "brand": ["Columbia", "Patagonia"], "fit": "relaxed", "activity": ["travel", "beach"],
 "price_max": 80, "label": "Dad"}
```

The `label` is the only thing the store learns about "Dad", and it is only
used to render a badge for the human in this session. Avoid-lists are
constraints too: `exclude_color: ["red"]` and `exclude_brand` are hard
constraints the store never relaxes, and they show as `not Red` chips the
shopper can remove. Registering Dad once (§4e) sends the same derived
constraints and saves re-deriving them on every query; the store refuses
anything that is not a derived constraint.

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
3. **Earn the cart**: `request_capability` for `cart` with a reason, the
   trip budget as `max_spend`, and an expiry (§4d). Until it is granted,
   cart writes fail cleanly; everything else works.
4. **Sizes from the guide**: where the profile holds measurements rather
   than sizes, `get_size_guide` on a representative product and match
   locally (§4f). Only the resulting label leaves the agent.
5. **Register the party**: `register_party_member` per person with sizes,
   colours, avoid-lists, brands, fit, budget, and shopper group (§4e). The
   grid badges what fits whom at once.
6. **Show the plan**: `present_plan` with one group per person, marking what
   they already `have` and what they `need`. The human sees it in the agent
   panel immediately.
7. **Per need, per person**: `find_matching_variants` with `member` and the
   need's category, activity, and price. The store resolves the size. Read
   `strict` and `match` in the reply: a `strict: false` reply means no
   variant satisfied every preference; the closest ones come back with a
   per-constraint match map, so the agent can decide whether to relax a
   colour or brand. Exclusions are never relaxed.
8. **Choose**: `compare_products` on the finalists when it helps, then
   `recommend_product` with a one-sentence reason the human will read.
9. **Add**: `add_to_cart` with `label` so the cart drawer groups lines by
   person, with a per-member subtotal against the member's budget. A write
   past the granted ceiling fails with `CAPABILITY_SCOPE_EXCEEDED`; the cart
   is untouched.
10. **Tidy**: `clear_annotations` for a need the shopper skipped, so no
    stale "Fits" badge or recommendation lingers.
11. **Update the plan**: `present_plan` again with items marked `added`.
12. **Hand off**: `focus_product` on anything worth a second look, then tell
    the human the cart is ready for review.

Refinements arrive as plain requests and map to the same tools:

| Human says | Agent does |
| --- | --- |
| "Keep it under $500." | Re-plan; `remove_from_cart` / `update_cart_item` until `get_cart().subtotal` fits; `present_plan` |
| "Dad doesn't need another shirt." | `remove_from_cart` Dad's shirt lines; mark the need `skipped` in `present_plan` |
| "No red." | `exclude_color: ["red"]` on the next queries, or re-register the member with `exclude_colors`; the `not Red` chip shows the human it took |
| Human removed a chip you set | `get_store_state.removed_by_human` lists it; do not re-impose it (the feed flags it if you do) |
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
 "budget": {"total": 600, "selection_over_by": 0, "cart_over_by": 0}}
{"accepted": false, "reason": "rejected" | "timeout" | "superseded", "cart": {...}}
```

`budget` carries two readings with distinct names: `selection_over_by` is the
proposed (or, at accept, applied) lines alone against the budget;
`cart_over_by` is the whole cart against it — projected during review
(`pending_proposal.projected_cart_total`), actual at accept. The panel shows
both. `mode: "replace"` clears the cart on accept only. Lines added this way are
marked `source: "proposal"` in the cart, so the order record shows what the
human chose by hand, what an agent added, and what an agent proposed and the
human accepted. One pending decision at a time: a proposal supersedes an open
question and vice versa. Rule of thumb: if the choice is *which lines*,
propose; if it is *which strategy*, `ask_human`.

## 4d. Earning the cart: `request_capability`

Nothing in the cart tier works until the shopper grants it. Ask once, with
a reason in their words and a scope they can accept:

```json
{"capability": "cart", "reason": "to assemble the Hawaii basket you asked for",
 "scope": {"max_spend": 700, "expires_ms": 1800000}}
```

The request renders in the agent panel with the ceiling editable, so the
figure that comes back may be lower than the one you sent:

```json
{"granted": true, "capability": "cart", "scope": {"max_spend": 500, "expires_at_ms": 1788400000000}}
{"granted": false, "capability": "cart", "reason": "denied" | "timeout" | "superseded"}
```

`granted: false` means leave the cart alone; ask again only with a
different reason or a smaller scope. A request the current grant already
covers is answered immediately. The ceiling is enforced by the store on
every cart write, including a proposal the shopper accepts, and the shopper
can revoke any tier from the panel at any time (even `read`, as a kill
switch). `get_store_state.capabilities` tells you where you stand. No grant
enables checkout.

## 4e. The party: `register_party_member`

Derive each person once and register the result:

```json
{"label": "Dad", "gender": "men",
 "sizes": {"tops": "XL", "bottoms": "36", "inseam": "32", "shoes": "11", "hats": "L/XL"},
 "colors": ["blue", "black", "navy"], "exclude_colors": ["red"],
 "brands": ["Columbia", "Patagonia"], "fit": "relaxed", "budget": 300}
```

Then `find_matching_variants({"member": "Dad", "category": "shorts"})` or
`filter_products({"member": "Dad"})` fills the size for that category
(`36` for shorts, `36x32` or `36` for pants, `11` for shoes, `L/XL` for
hats, `XL` for shirts) and the colours, exclusions, brands, fit, gender, and
label, unless you pass them explicitly. With no category, every size system
goes as one list and the same-variant rule keeps it precise, so one call
replaces a per-category fan-out. The reply names `resolved_for` and
`constraints.sizes`.

The store refuses anything that is not a derived constraint
(`PRIVATE_CONTEXT_REJECTED` lists the offending fields). Product cards badge
every member a product fits, the size picker tags the member's size, the
cart and proposals show per-member subtotals against budgets, and
`get_store_state.members` echoes what is registered. `remove_party_member`
(or the shopper, from the panel) clears it all.

## 4f. Sizes from the size guide, without sending measurements

Profiles often hold measurements, not sizes. Do not send them: the store
serves per-size measurement ranges through `get_size_guide`, so match
locally and send only the label. This works on every size system, not just
S–XXL. A men's short's guide, for example:

```json
{"product_id": "prod_1009", "size_system": "US", "unit": "inches",
 "measurements": [{"size": "34", "waist_min": 34, "waist_max": 35, "hip_min": 40, "hip_max": 41},
                  {"size": "36", "waist_min": 36, "waist_max": 37, "hip_min": 42, "hip_max": 43}]}
```

Given `waist: 36` (kept in the agent), the entry whose range contains it is
`36`; register that as `sizes.bottoms`. For a shirt guide, match `chest`
against `chest_min..chest_max` to get `XL`. When no range contains the
measurement, take the nearest and say so in the recommendation. The
rehearsal script does exactly this (`deriveSize`) and its privacy guard
fails the run if a measurement key ever appears in a store-bound payload.

## 4g. Seeing your own constraints the way the shopper does

Every chip in the results header carries an origin (`✦ agent` or `you`) and
`hiding N`, the products that would appear if that facet were dropped. The
shopper can loosen any constraint from there. `get_store_state` returns the
same: `filter_origins` per facet, `excluded_by` per facet, and
`removed_by_human`, the constraints of yours the shopper removed. Treat
those as load-bearing corrections: re-applying one, or clearing a facet the
shopper set, is written to the feed as a warning.

## 4h. Provenance and lifecycle

Cart lines remember who put them there (`source`: `human`, `agent`, or
`proposal`) and, for a proposal line the shopper swapped, what you had
proposed. The order confirmation shows every line with that badge and a
summary such as "3 yours · 4 agent-added · 2 from a proposal (1 swapped)".
Your annotations have a lifecycle too: `clear_annotations` by label,
product, or source, and the shopper can dismiss any badge from a card.
Compare controls sit next to every set you assemble (a member's matches, a
proposal group), so `compare_products` has a human counterpart.

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
scripted outcome of the reasoning an external agent would do. It exercises
the capability gate (a refused `add_to_cart`, then `request_capability`
with a ceiling), agent-side size derivation from `get_size_guide`, party
registration with avoid-lists, `member:` matching, `ask_human`,
`clear_annotations`, `propose_cart` with per-member budgets, and a privacy
guard that fails the run if any measurement reaches a payload.
