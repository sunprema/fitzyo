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
import { spawn } from "node:child_process";
import { mkdirSync, writeFileSync } from "node:fs";

const STORE = process.argv[2] || "http://localhost:4000/";
const CHROME =
  process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const OUT = process.env.OUT || "tmp/rehearsal";
const PORT = 9333;

// What the agent derived from private context. Only these constraints reach
// the store; names, measurements, and the wardrobe never do.
const FAMILY = {
  Dad: { gender: "men", size: "XL", waist: "36", shoe: "11", colors: ["blue", "black", "navy"],
         brands: ["Columbia", "Patagonia"], fit: "relaxed" },
  Mom: { gender: "women", size: "M", shoe: "8", colors: ["navy", "teal", "coral", "white"],
         brands: ["Patagonia", "Roxy", "Tommy Bahama"], fit: "regular" },
  Milo: { gender: "boys", size: "L", shoe: "4Y", colors: ["blue", "green", "navy"], brands: [] },
};

// Needs = itinerary × activities − wardrobe (see context/*.md), essentials
// first so the budget protects sun protection over nice-to-haves. `search`
// is a keyword the agent uses to shortlist products before fit-matching.
const NEEDS = [
  { who: "Milo", text: "UPF rash guard", category: "swimwear", size: "L", search: "rash guard", activity: ["swim"], price_max: 40 },
  { who: "Milo", text: "Sandals", category: "shoes", size: "4Y", search: "sandal", activity: ["beach"], price_max: 50 },
  { who: "Milo", text: "Sun hat", category: "accessories", size: "S/M", search: "hat", activity: ["beach"], price_max: 20 },
  { who: "Mom", text: "Long-sleeve rash guard", category: "swimwear", size: "M", search: "rash guard", activity: ["swim"], price_max: 80 },
  { who: "Dad", text: "2 lightweight travel shirts", category: "shirts", size: "XL", activity: ["travel", "beach"], qty: 2, price_max: 80 },
  { who: "Dad", text: "1 hiking short", category: "shorts", size: "36", activity: ["hiking"], price_max: 90 },
  { who: "Dad", text: "New swim trunks", category: "swimwear", size: "36", activity: ["swim"], price_max: 80 },
  { who: "Mom", text: "Sandals", category: "shoes", size: "8", search: "sandal", brands: [], activity: ["beach"], price_max: 80 },
  { who: "Mom", text: "1 dinner dress", category: "dresses", size: "M", search: "linen", activity: ["dinner"], price_max: 160 },
  { who: "Dad", text: "1 linen dinner shirt", category: "shirts", size: "XL", search: "linen", activity: ["dinner"], brands: [], price_max: 130 },
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
async function call(tool, input = {}) {
  const r = await evaluate(
    `navigator.modelContext.tools.get(${JSON.stringify(tool)}).execute(${JSON.stringify(input)})` +
      `.then(r => ({ok: true, r}), e => ({ok: false, e: String(e.message || e)}))`
  );
  const shown = r.ok ? JSON.stringify(r.r) : "ERROR " + r.e;
  console.log(`▶ ${tool}(${JSON.stringify(input)})\n  ${shown.length > 220 ? shown.slice(0, 220) + "…" : shown}`);
  if (!r.ok) throw new Error(`${tool} failed: ${r.e}`);
  return r.r;
}

// ask_human blocks until the shopper acts. In this unattended rehearsal a
// stand-in "shopper" clicks the first option after a short pause so the
// hand-back is visible on screen; a real demo leaves this to the person.
async function askHuman(input) {
  await evaluate(`window.__ask = {done: false}; navigator.modelContext.tools.get("ask_human").execute(${JSON.stringify(input)})` +
    `.then(r => { window.__ask = {done: true, r}; }, e => { window.__ask = {done: true, e: String(e.message || e)}; }); true`);
  console.log(`▶ ask_human(${JSON.stringify(input).slice(0, 160)}…)\n  (waiting for the shopper)`);
  await sleep(600);
  await screenshot("1c-ask-human");
  await sleep(process.env.HUMAN_DELAY_MS ? parseInt(process.env.HUMAN_DELAY_MS, 10) : 2500);
  const target = process.env.HUMAN_ANSWER || input.options?.[0]?.id;
  const selector = `#agent-question [data-option-id="${target}"]`;
  await evaluate(`document.querySelector(${JSON.stringify(selector)})?.click(); true`);
  await waitFor(() => evaluate(`window.__ask.done`), "answer");
  const r = await evaluate(`window.__ask`);
  console.log(`  ${JSON.stringify(r.r ?? r.e)}`);
  return r.r ?? { answered: false, reason: "error" };
}

function constraints(need) {
  const p = FAMILY[need.who];
  return {
    category: need.category, gender: p.gender, size: need.size,
    color: p.colors, brand: need.brands ?? p.brands, fit: p.fit, activity: need.activity,
    price_max: need.price_max, label: need.who,
  };
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
  await call("get_store_info");
  await call("get_categories");
  await think("Dad has three casual shirts and two shorts already; he needs quick-dry travel shirts, a hiking short, and new trunks. Mom lacks a rash guard and a dinner dress. Milo has no sandals, hat, or rash guard.");

  const status = {};
  await call("present_plan", plan(status));
  await sleep(300);
  await screenshot("1-plan");

  let subtotal = 0;
  for (const need of NEEDS) {
    await say(`Finding ${need.who}'s ${need.text.toLowerCase()}`);
    const p = FAMILY[need.who];
    await think(`${need.who}: size ${need.size}, ${p.colors.slice(0, 3).join("/")}${(need.brands ?? p.brands).length ? ", prefers " + (need.brands ?? p.brands).join(" or ") : ""}, under $${need.price_max}.`);
    // Shortlist by keyword first when the need is a specific kind of item,
    // then fit-match within the shortlist (spec §40: search → filter → match).
    let shortlist = null;
    if (need.search) {
      const hits = await call("search_products", { query: need.search, limit: 10 });
      shortlist = hits.results.filter((p) => p.category === need.category).map((p) => p.product_id);
    }
    let found = { strict: false, matches: [] };
    for (const product_id of shortlist ?? [null]) {
      const attempt = await call("find_matching_variants", { ...constraints(need), ...(product_id ? { product_id } : {}), limit: 3 });
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
        const added = await call("add_to_cart", { product_id: best.product_id, variant_id: best.variant_id, quantity: need.qty || 1, label: need.who });
        subtotal = added.cart.subtotal; status[need.text] = "added"; status[`${need.text}:pid`] = best.product_id; done += 1;
        continue;
      }
      status[need.text] = "skipped"; done += 1; console.log(`  ↳ over budget, ${choice === "skip" ? "skipped by the shopper" : "shopper asked for cheaper"}`); continue;
    }
    if (found.matches.length > 1) {
      await call("compare_products", { product_ids: [...new Set(found.matches.map((m) => m.product_id))].slice(0, 3) });
    }
    await call("recommend_product", { product_id: best.product_id, variant_id: best.variant_id, label: need.who,
      reason: `${need.text}: ${best.brand} in ${best.color}, size ${best.size}${found.strict ? ", every preference met" : ", closest available"}.` });
    const added = await call("add_to_cart", { product_id: best.product_id, variant_id: best.variant_id, quantity: need.qty || 1, label: need.who });
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
    { who: "Dad", text: "Sun hat", category: "accessories", size: "L/XL", activity: ["beach"], brands: [], price_max: 40 },
    { who: "Mom", text: "Water shorts", category: "shorts", size: "M", activity: ["swim"], price_max: 70 },
    { who: "Milo", text: "Spare athletic shorts", category: "shorts", size: "L", activity: ["running"], price_max: 30, optional: true },
  ];
  const lines = [];
  for (const need of extras) {
    const found = await call("find_matching_variants", { ...constraints(need), limit: 3 });
    const best = found.matches[0];
    if (best) lines.push({ variant_id: best.variant_id, label: need.who, reason: `${need.text}: ${best.brand} in ${best.color}`, optional: !!need.optional,
      alternatives: found.matches.slice(1, 3).map((m) => ({ variant_id: m.variant_id, reason: `${m.brand} in ${m.color}, $${m.price}` })) });
  }
  if (lines.length) {
    await evaluate(`window.__prop = {done: false}; navigator.modelContext.tools.get("propose_cart").execute(${JSON.stringify({ title: "Maui extras — your call", subtitle: "Tick what you want; the budget updates live", budget: { total: BUDGET }, lines })})` +
      `.then(r => { window.__prop = {done: true, r}; }, e => { window.__prop = {done: true, e: String(e.message || e)}; }); true`);
    console.log("▶ propose_cart(" + lines.length + " lines, budget $" + BUDGET + ")\n  (waiting for the shopper)");
    await sleep(700);
    await screenshot("1d-propose-cart");
    await sleep(process.env.HUMAN_DELAY_MS ? parseInt(process.env.HUMAN_DELAY_MS, 10) : 2500);
    // Stand-in shopper: untick from the bottom until the basket fits the budget, then accept.
    for (let i = 0; i < 5; i++) {
      const over = await evaluate(`parseFloat(document.getElementById("agent-proposal")?.dataset.overBy || "0")`);
      if (!(over > 0)) break;
      await evaluate(`(() => { const ticks = Array.from(document.querySelectorAll("#agent-proposal input[type=checkbox]:checked")); ticks.at(-1)?.click(); })(); true`);
      await sleep(600);
    }
    await evaluate(`document.getElementById("proposal-accept")?.click(); true`);
    await waitFor(() => evaluate(`window.__prop.done`), "proposal");
    const r = await evaluate(`window.__prop`);
    console.log("  " + JSON.stringify(r.r ?? r.e).slice(0, 260));
  }

  await call("present_plan", plan(status));
  const cart = await call("get_cart");
  console.log(`\n🛍  Cart: ${cart.cart.item_count} items, $${cart.cart.subtotal} of $${BUDGET} budget`);
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
  console.log(`\n👀 Human view: ${state.state.view}, ${state.state.annotations.length} annotations, cart open: ${state.state.cart_open}`);
  console.log("\nDone. The human reviews the cart and approves checkout in the drawer; the agent cannot.");
} catch (e) {
  console.error("\nREHEARSAL FAILED:", e.message);
  process.exitCode = 1;
} finally {
  try { ws?.close(); } catch {}
  chrome.kill();
}
