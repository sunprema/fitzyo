#!/usr/bin/env node
// Plays the Hawaii scenario against a running FitzYo store the way an external
// WebMCP agent would, so the demo can be rehearsed without one.
//
//   mix phx.server
//   node scripts/agent_rehearsal.mjs http://localhost:4000
//
// It launches headless Chrome, injects a minimal `navigator.modelContext`
// (what a WebMCP-capable browser provides), waits for the page to register
// its tools, then calls them. There is no reasoning here: the "plan" below is
// the outcome an agent would reach from context/FAMILY.md, WARDROBE.md, and
// TRIP.md. Requires Node 22+ (global fetch/WebSocket) and Google Chrome.
//
// What it exercises, in order: the capability gate (a cart write is refused
// until the shopper grants `cart` with a ceiling), agent-side size derivation
// from `get_size_guide` (measurements never leave this file), party members
// with avoid-lists, member-resolved matching, ask_human, propose_cart, and
// the annotation lifecycle.
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";

const STORE = process.argv[2] || "http://localhost:4000/";
const CHROME =
  process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const OUT = process.env.OUT || "tmp/rehearsal";
const PORT = 9333;

// ---------------------------------------------------------------- private context
// Everything in this block stays in the agent. Only derived constraints reach
// the store, and `call` below refuses to send any of these keys by accident.
const MEASUREMENTS = {
  Dad: { chest: 45, waist: 36, inseam: 32 },
  Mom: { chest: 35.5, waist: 28.5, hip: 38.5 },
  Milo: { chest: 30, waist: 25.5 },
};
const PRIVATE_KEYS = ["chest", "waist", "hip", "inseam_in", "height", "weight", "age", "name", "measurements"];

// What the agent derived from private context. Sizes marked `derive` are
// worked out from the store's own size guide below, so the rehearsal shows
// the pattern on a letter system (tops) and a waist system (bottoms).
const FAMILY = {
  Dad: {
    gender: "men",
    sizes: { tops: "derive", bottoms: "derive", inseam: "32", shoes: "11", hats: "L/XL" },
    colors: ["blue", "black", "navy"], exclude_colors: ["red"],
    brands: ["Columbia", "Patagonia"], fit: "relaxed", budget: 300,
  },
  Mom: {
    gender: "women",
    sizes: { tops: "M", bottoms: "28", shoes: "8", hats: "S/M" },
    colors: ["navy", "teal", "coral", "white"], exclude_colors: ["yellow"],
    brands: ["Patagonia", "Roxy", "Tommy Bahama"], fit: "regular", budget: 250,
  },
  Milo: {
    gender: "boys",
    sizes: { tops: "L", shoes: "4Y", hats: "S/M" },
    colors: ["blue", "green", "navy"], exclude_colors: ["pink"], brands: [], budget: 150,
  },
};

// Needs = itinerary × activities − wardrobe (see context/*.md), essentials
// first so the budget protects sun protection over nice-to-haves. `search`
// is a keyword the agent uses to shortlist products before fit-matching.
// Sizes are not listed: the store resolves them from the registered member.
const NEEDS = [
  { who: "Milo", text: "UPF rash guard", category: "swimwear", search: "rash guard", activity: ["swim"], price_max: 40 },
  { who: "Milo", text: "Sandals", category: "shoes", search: "sandal", activity: ["beach"], price_max: 50 },
  { who: "Milo", text: "Sun hat", category: "accessories", search: "hat", activity: ["beach"], price_max: 20 },
  { who: "Mom", text: "Long-sleeve rash guard", category: "swimwear", search: "rash guard", activity: ["swim"], price_max: 80 },
  { who: "Dad", text: "2 lightweight travel shirts", category: "shirts", activity: ["travel", "beach"], qty: 2, price_max: 80 },
  { who: "Dad", text: "1 hiking short", category: "shorts", activity: ["hiking"], price_max: 90 },
  { who: "Dad", text: "New swim trunks", category: "swimwear", activity: ["swim"], price_max: 80 },
  { who: "Mom", text: "Sandals", category: "shoes", search: "sandal", brands: [], activity: ["beach"], price_max: 80 },
  { who: "Mom", text: "1 dinner dress", category: "dresses", search: "linen", activity: ["dinner"], price_max: 160 },
  { who: "Dad", text: "1 linen dinner shirt", category: "shirts", search: "linen", activity: ["dinner"], brands: [], price_max: 130 },
];
const HAVE = { Dad: ["3 casual shirts", "2 casual shorts"], Mom: ["2 tank tops", "1 casual sundress"], Milo: ["4 t-shirts", "boardshorts"] };
const BUDGET = 700;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function waitFor(fn, label, tries = 80) {
  for (let i = 0; i < tries; i++) { try { const v = await fn(); if (v) return v; } catch {} await sleep(250); }
  throw new Error(`timeout waiting for ${label}`);
}

let ws, seq = 0; const pending = new Map();
function send(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++seq; pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
}
async function evaluate(expression) {
  const { result, exceptionDetails } = await send("Runtime.evaluate", { expression, awaitPromise: true, returnByValue: true });
  if (exceptionDetails) throw new Error(exceptionDetails.exception?.description || exceptionDetails.text);
  return result.value;
}
async function screenshot(name) {
  const { data } = await send("Page.captureScreenshot", { format: "png" });
  writeFileSync(`${OUT}/${name}.png`, Buffer.from(data, "base64"));
  console.log(`  📸 ${OUT}/${name}.png`);
}

// Privacy guard: a store-bound payload must never carry a measurement or a
// profile field. Invariant 1 of the feature brief, checked on every call.
function assertDerivedOnly(tool, input) {
  const json = JSON.stringify(input);
  for (const key of PRIVATE_KEYS) {
    if (new RegExp(`"${key}"\\s*:`).test(json)) throw new Error(`privacy guard: ${tool} payload carries "${key}"`);
  }
}

// `allowError` returns the structured error instead of throwing, for calls
// the rehearsal expects to be refused (the capability gate).
async function call(tool, input = {}, { allowError = false } = {}) {
  assertDerivedOnly(tool, input);
  const r = await evaluate(
    `navigator.modelContext.tools.get(${JSON.stringify(tool)}).execute(${JSON.stringify(input)})` +
      `.then(r => ({ok: true, r}), e => ({ok: false, e: String(e.message || e)}))`
  );
  const shown = r.ok ? JSON.stringify(r.r) : "ERROR " + r.e;
  console.log(`▶ ${tool}(${JSON.stringify(input)})\n  ${shown.length > 220 ? shown.slice(0, 220) + "…" : shown}`);
  if (!r.ok) {
    let parsed = null; try { parsed = JSON.parse(r.e); } catch {}
    if (allowError && parsed) return { error: parsed };
    throw new Error(`${tool} failed: ${r.e}`);
  }
  return r.r;
}

// Blocking calls (ask_human, propose_cart, request_capability) resolve when the
// shopper acts. In this unattended rehearsal a stand-in "shopper" acts after
// a short pause so the hand-back is visible on screen; a real demo leaves it
// to the person.
const HUMAN_DELAY = process.env.HUMAN_DELAY_MS ? parseInt(process.env.HUMAN_DELAY_MS, 10) : 2500;
async function blocking(tool, input, slot, shot, act) {
  assertDerivedOnly(tool, input);
  await evaluate(`window.${slot} = {done: false}; navigator.modelContext.tools.get(${JSON.stringify(tool)}).execute(${JSON.stringify(input)})` +
    `.then(r => { window.${slot} = {done: true, r}; }, e => { window.${slot} = {done: true, e: String(e.message || e)}; }); true`);
  console.log(`▶ ${tool}(${JSON.stringify(input).slice(0, 160)}…)\n  (waiting for the shopper)`);
  await sleep(600);
  await screenshot(shot);
  await sleep(HUMAN_DELAY);
  await act();
  await waitFor(() => evaluate(`window.${slot}.done`), tool);
  const r = await evaluate(`window.${slot}`);
  console.log(`  ${JSON.stringify(r.r ?? r.e).slice(0, 260)}`);
  return r.r ?? { error: r.e };
}

async function askHuman(input) {
  const target = process.env.HUMAN_ANSWER || input.options?.[0]?.id;
  const r = await blocking("ask_human", input, "__ask", "1c-ask-human", () =>
    evaluate(`document.querySelector(${JSON.stringify(`#agent-question [data-option-id="${target}"]`)})?.click(); true`));
  return r.error ? { answered: false, reason: "error" } : r;
}

async function requestCapability(input) {
  // The stand-in shopper reads the request and submits the Allow form (with
  // the ceiling the agent proposed; a person could lower it first).
  return blocking("request_capability", input, "__cap", "0-capability-request", () =>
    evaluate(`document.getElementById("capability-request-form")?.requestSubmit(); true`));
}

// ---------------------------------------------------------------- size derivation (agent-side)
// The store serves per-size measurement ranges; the agent matches its private
// measurements against them locally and sends only the resulting label.
function deriveSize(guide, m) {
  const ranges = [["chest", "chest_min", "chest_max"], ["waist", "waist_min", "waist_max"], ["hip", "hip_min", "hip_max"]];
  let best = null;
  for (const entry of guide.measurements) {
    let checks = 0, hits = 0, distance = 0;
    for (const [key, lo, hi] of ranges) {
      if (m[key] == null || entry[lo] == null) continue;
      checks++;
      const max = entry[hi] ?? entry[lo];
      if (m[key] >= entry[lo] && m[key] <= max) hits++;
      else distance += Math.min(Math.abs(m[key] - entry[lo]), Math.abs(m[key] - max));
    }
    if (checks === 0) continue;
    const score = { size: entry.size, exact: hits === checks, distance };
    if (!best || (score.exact && !best.exact) || (score.exact === best.exact && score.distance < best.distance)) best = score;
  }
  return best;
}

function plan(status) {
  return {
    title: "Hawaii — 7 day wardrobe",
    subtitle: `Beach, hiking, dinners · budget $${BUDGET}`,
    groups: Object.keys(FAMILY).map((who) => ({
      label: who,
      items: [
        ...HAVE[who].map((text) => ({ text, status: "have" })),
        ...NEEDS.filter((n) => n.who === who).map((n) => ({ text: n.text, status: status[n.text] || "need", product_id: status[`${n.text}:pid`] })),
      ],
    })),
  };
}

mkdirSync(OUT, { recursive: true });
const chrome = spawn(CHROME, [
  "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=1440,1000",
  `--remote-debugging-port=${PORT}`, "--remote-allow-origins=*", `--user-data-dir=${OUT}/chrome-profile`, "about:blank",
], { stdio: "ignore" });

try {
  await waitFor(() => fetch(`http://localhost:${PORT}/json/version`).then((r) => r.ok), "chrome");
  const target = await fetch(`http://localhost:${PORT}/json/new?${STORE}`, { method: "PUT" }).then((r) => r.json());
  ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r) => (ws.onopen = r));
  ws.onmessage = (m) => {
    const msg = JSON.parse(m.data);
    if (msg.id && pending.has(msg.id)) { const p = pending.get(msg.id); pending.delete(msg.id); msg.error ? p.reject(new Error(JSON.stringify(msg.error))) : p.resolve(msg.result); }
  };
  await send("Runtime.enable"); await send("Page.enable");
  await waitFor(() => evaluate(`!!document.querySelector("[data-phx-main].phx-connected")`), "LiveView");

  // The agent attaches. A real browser provides this object; the page detects it.
  await evaluate(`navigator.modelContext = { tools: new Map(), registerTool(t, o) { this.tools.set(t.name, t); o?.signal?.addEventListener("abort", () => this.tools.delete(t.name)); return Promise.resolve(); } }; true`);
  const n = await waitFor(async () => { const c = await evaluate(`navigator.modelContext.tools.size`); return c > 0 ? c : null; }, "tools");
  console.log(`\n✦ Agent attached — ${n} tools registered\n`);

  // Narrate like a coding agent: a banner, streamed thoughts, and progress.
  const think = async (text, chunk = 28) => {
    for (let i = 0; i < text.length; i += chunk) {
      await call("agent_update", { thought: text.slice(i, i + chunk), append: i > 0 });
      await sleep(90);
    }
  };
  const total = NEEDS.length;
  let done = 0;
  const say = (message) => call("agent_update", { status: "working", message, progress: { done, total } });

  await say("Reading the family's private context");
  await think("Seven days on Maui: beach, a muddy hike, sightseeing, and one nice dinner. Sun is the main risk, so UPF layers first. Budget is $700 for everyone.");
  const info = await call("get_store_info");
  await call("get_categories");

  // --- Trust first: the cart tier is not granted. Try, get refused, ask.
  const probe = await call("add_to_cart", { product_id: "prod_1001", variant_id: "prod_1001_blue_xl" }, { allowError: true });
  if (probe.error?.code !== "CAPABILITY_NOT_GRANTED") throw new Error("expected the cart gate to refuse add_to_cart");
  await think("The store will not let me touch the cart until you say so. Asking for cart access with a $700 ceiling for the next 30 minutes.");
  const grant = await requestCapability({
    capability: "cart",
    reason: "to assemble the Hawaii basket you asked for, within your $700 budget",
    scope: { max_spend: BUDGET, expires_ms: 30 * 60 * 1000 },
  });
  if (!grant.granted) throw new Error("the shopper did not grant cart access");
  console.log(`  ↳ cart allowed up to $${grant.scope.max_spend}`);

  // --- Sizes from the store's own guide, matched against private measurements here.
  await say("Working out Dad's sizes from the store's size guide");
  const shirtGuideProduct = (await call("search_products", { query: "shirt", limit: 5 })).results.find((p) => p.gender === "men" && p.category === "shirts");
  const shortGuideProduct = (await call("search_products", { query: "short", limit: 8 })).results.find((p) => p.gender === "men" && p.category === "shorts");
  const topsGuide = await call("get_size_guide", { product_id: shirtGuideProduct.product_id });
  const bottomsGuide = await call("get_size_guide", { product_id: shortGuideProduct.product_id });
  const tops = deriveSize(topsGuide, MEASUREMENTS.Dad);
  const bottoms = deriveSize(bottomsGuide, MEASUREMENTS.Dad);
  FAMILY.Dad.sizes.tops = tops.size;
  FAMILY.Dad.sizes.bottoms = bottoms.size;
  console.log(`  ↳ derived locally: tops ${tops.size} (${tops.exact ? "exact" : "nearest"}), bottoms ${bottoms.size} (${bottoms.exact ? "exact" : "nearest"}) — measurements never sent`);
  await think(`Dad is a ${tops.size} top and a ${bottoms.size} waist by this store's guide. Only those labels go to the store.`);

  // --- Register the party as derived constraints, then plan.
  await say("Registering who I am shopping for");
  for (const [label, p] of Object.entries(FAMILY)) {
    await call("register_party_member", { label, gender: p.gender, sizes: p.sizes, colors: p.colors, exclude_colors: p.exclude_colors, brands: p.brands, fit: p.fit, budget: p.budget });
  }
  await call("filter_products", {});
  await sleep(300);
  await screenshot("1a-party-fits");
  await think("Dad has three casual shirts and two shorts already; he needs quick-dry travel shirts, a hiking short, and new trunks. Mom lacks a rash guard and a dinner dress. Milo has no sandals, hat, or rash guard.");

  const status = {};
  await call("present_plan", plan(status));
  await sleep(300);
  await screenshot("1-plan");

  let subtotal = 0;
  for (const need of NEEDS) {
    await say(`Finding ${need.who}'s ${need.text.toLowerCase()}`);
    const p = FAMILY[need.who];
    await think(`${need.who}: ${p.colors.slice(0, 3).join("/")}, never ${p.exclude_colors.join("/")}${(need.brands ?? p.brands).length ? ", prefers " + (need.brands ?? p.brands).join(" or ") : ""}, under $${need.price_max}. Size comes from the member.`);
    // Shortlist by keyword first when the need is a specific kind of item,
    // then fit-match within the shortlist (spec §40: search → filter → match).
    let shortlist = null;
    if (need.search) {
      const hits = await call("search_products", { query: need.search, limit: 10 });
      shortlist = hits.results.filter((p) => p.category === need.category).map((p) => p.product_id);
    }
    const constraints = { member: need.who, category: need.category, activity: need.activity, price_max: need.price_max, ...(need.brands ? { brand: need.brands } : {}) };
    let found = { strict: false, matches: [] };
    for (const product_id of shortlist ?? [null]) {
      const attempt = await call("find_matching_variants", { ...constraints, ...(product_id ? { product_id } : {}), limit: 3 });
      if (attempt.strict || (attempt.matches.length && !found.matches.length)) found = attempt;
      if (attempt.strict) break;
    }
    const best = found.matches[0];
    if (!best) { status[need.text] = "skipped"; done += 1; await think(`Nothing in stock for ${need.who}'s ${need.text.toLowerCase()}; skipping.`); console.log(`  ↳ nothing in stock for ${need.who}: ${need.text}`); continue; }
    if (!found.strict) console.log(`  ↳ no exact match; closest is ${best.name} (${best.color}/${best.size}) score ${best.match_score}`);
    if (subtotal + best.price * (need.qty || 1) > BUDGET) {
      // The decision is the shopper's: hand it back inside the store and wait.
      const over = subtotal + best.price * (need.qty || 1) - BUDGET;
      await think(`${best.name} would put us $${over} over the $${BUDGET} budget. That is the shopper's call, not mine.`);
      await say(`Waiting for you: ${need.who}'s ${need.text.toLowerCase()}`);
      const answer = await askHuman({
        question: `${need.who}'s ${need.text.toLowerCase()} puts you $${over} over budget. What should I do?`,
        subtitle: `${best.name} is $${best.price}; cart is $${subtotal} of $${BUDGET}`,
        options: [
          { id: "skip", label: `Skip it`, description: `Stay at $${subtotal}` },
          { id: "add", label: `Add it anyway`, description: `Go to $${subtotal + best.price}`, product_id: best.product_id, variant_id: best.variant_id },
          { id: "cheaper", label: "Find something cheaper", description: "Search again without brand preferences" },
        ],
      });
      const choice = answer.answered ? answer.selected[0] : "skip";
      await think(`You chose "${choice}".`);
      if (choice === "add") {
        const added = await call("add_to_cart", { product_id: best.product_id, variant_id: best.variant_id, quantity: need.qty || 1, label: need.who }, { allowError: true });
        if (added.error) { console.log(`  ↳ refused: ${added.error.code}`); status[need.text] = "skipped"; done += 1; continue; }
        subtotal = added.cart.subtotal; status[need.text] = "added"; status[`${need.text}:pid`] = best.product_id; done += 1;
        continue;
      }
      // Skipped: the match badge for it should not linger in the UI.
      await call("clear_annotations", { label: need.who, product_id: best.product_id });
      status[need.text] = "skipped"; done += 1; console.log(`  ↳ over budget, ${choice === "skip" ? "skipped by the shopper" : "shopper asked for cheaper"}`); continue;
    }
    if (found.matches.length > 1) {
      await call("compare_products", { product_ids: [...new Set(found.matches.map((m) => m.product_id))].slice(0, 3) });
    }
    await call("recommend_product", { product_id: best.product_id, variant_id: best.variant_id, label: need.who,
      reason: `${need.text}: ${best.brand} in ${best.color}, size ${best.size}${found.strict ? ", every preference met" : ", closest available"}.` });
    const added = await call("add_to_cart", { product_id: best.product_id, variant_id: best.variant_id, quantity: need.qty || 1, label: need.who }, { allowError: true });
    if (added.error) {
      // The ceiling the shopper granted is enforced by the store, not by this script.
      console.log(`  ↳ refused by the store: ${added.error.code} (${added.error.message})`);
      await think(`The store refused: ${added.error.message}. Skipping ${need.who}'s ${need.text.toLowerCase()}.`);
      status[need.text] = "skipped"; done += 1; continue;
    }
    subtotal = added.cart.subtotal;
    status[need.text] = "added"; status[`${need.text}:pid`] = best.product_id;
    done += 1;
    await say(`Added ${best.name} for ${need.who} · $${subtotal} so far`);
    await sleep(900);
    if (done === 4) await screenshot("1b-agent-working");
  }

  // Nice-to-haves go in as one priced basket the shopper approves at once,
  // with the budget shown so the trade-off is visible instead of narrated.
  await say("Proposing a few extras as one basket");
  await think("Everything essential is in. A sun hat for Dad, water shorts for Mom, and spare shorts for Milo would be nice but push past the budget together; the shopper should pick.");
  const extras = [
    { who: "Dad", text: "Sun hat", category: "accessories", activity: ["beach"], brands: [], price_max: 40 },
    { who: "Mom", text: "Water shorts", category: "shorts", activity: ["swim"], price_max: 70 },
    { who: "Milo", text: "Spare athletic shorts", category: "shorts", activity: ["running"], price_max: 30, optional: true },
  ];
  const lines = [];
  for (const need of extras) {
    const found = await call("find_matching_variants", { member: need.who, category: need.category, activity: need.activity, price_max: need.price_max, ...(need.brands ? { brand: need.brands } : {}), limit: 3 });
    const best = found.matches[0];
    if (best) lines.push({ variant_id: best.variant_id, label: need.who, reason: `${need.text}: ${best.brand} in ${best.color}`, optional: !!need.optional,
      alternatives: found.matches.slice(1, 3).map((m) => ({ variant_id: m.variant_id, reason: `${m.brand} in ${m.color}, $${m.price}` })) });
  }
  if (lines.length) {
    // Per-member budgets come from the registered members; only the total is sent.
    const r = await blocking("propose_cart", { title: "Maui extras — your call", subtitle: "Tick what you want; the budget updates live", budget: { total: BUDGET }, lines }, "__prop", "1d-propose-cart", async () => {
      // Stand-in shopper: untick from the bottom until the basket fits the budget and the ceiling, then accept.
      for (let i = 0; i < 5; i++) {
        const over = await evaluate(`parseFloat(document.getElementById("agent-proposal")?.dataset.overBy || "0")`);
        const blocked = await evaluate(`!!document.querySelector("#proposal-accept[disabled]")`);
        if (!(over > 0) && !blocked) break;
        await evaluate(`(() => { const ticks = Array.from(document.querySelectorAll("#agent-proposal input[type=checkbox]:checked")); ticks.at(-1)?.click(); })(); true`);
        await sleep(600);
      }
      await evaluate(`document.getElementById("proposal-accept")?.click(); true`);
    });
    if (r.error) console.log(`  ↳ proposal error: ${r.error}`);
  }

  await call("present_plan", plan(status));
  const cart = await call("get_cart");
  const perMember = Object.entries(cart.cart.by_label).map(([who, b]) => `${who} $${b.subtotal}${b.budget ? ` of $${b.budget}` : ""}${b.over_by > 0 ? " (over)" : ""}`).join(", ");
  console.log(`\n🛍  Cart: ${cart.cart.item_count} items, $${cart.cart.subtotal} of $${BUDGET} budget — ${perMember}`);
  await call("agent_update", { status: "done", message: `Cart ready for review: ${cart.cart.item_count} items, $${cart.cart.subtotal} of $${BUDGET}`, progress: { done: total, total } });
  await call("filter_products", {});
  await sleep(400);
  await screenshot("2-results-with-fits");

  await call("focus_product", { product_id: cart.cart.items[0].product_id, variant_id: cart.cart.items[0].variant_id });
  await sleep(600);
  await screenshot("3-product-focus");

  await evaluate(`document.getElementById("cart-button").click(); true`);
  await sleep(400);
  await screenshot("4-cart-for-review");

  const state = await call("get_store_state");
  const caps = Object.entries(state.state.capabilities).map(([k, v]) => `${k}: ${v ? (v.max_spend ? `up to $${v.max_spend}` : "yes") : "no"}`).join(", ");
  console.log(`\n👀 Human view: ${state.state.view}, ${state.state.annotations.length} annotations, ${state.state.members.length} members, cart open: ${state.state.cart_open}`);
  console.log(`🔐 Capabilities — ${caps}`);
  console.log(`\nDone. The human reviews the cart and approves checkout in the drawer; the agent cannot. (Store advertises ${info.capability_tiers.cart.length} cart-tier tools behind the gate.)`);
} catch (e) {
  console.error("\nREHEARSAL FAILED:", e.message);
  process.exitCode = 1;
} finally {
  try { ws?.close(); } catch {}
  chrome.kill();
}
