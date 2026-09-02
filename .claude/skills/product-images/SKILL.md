---
name: product-images
description: "Find Unsplash photos for catalog products and record them in priv/repo/product_images.exs. Use when products are added to priv/repo/seeds.exs, when a product shows the initials tile instead of a photo, or when asked to search images for products, swap a product photo, or refresh photo credits."
---

## What this does

Every product in the demo catalog gets one Unsplash photo, hotlinked from
`images.unsplash.com`. The mapping lives in `priv/repo/product_images.exs`
(product id → url, alt, photographer, link) and the seeds copy the url into
the product's `image_url`. `StoreComponents.product_art/1` shows the photo
and falls back to the color tile with initials when a product has none.

The script at `scripts/unsplash_images.py` runs the whole pipeline. It needs
`curl` and `python3`; Pillow is optional but needed for the contact sheets
you review (`python3 -m venv .venv && .venv/bin/pip install pillow` in a
scratch directory, then run the script with that interpreter).

## Workflow

1. **Find products without a photo.**

       python3 .claude/skills/product-images/scripts/unsplash_images.py missing

2. **Write one search phrase per product** to a `queries.json` file in your
   scratch directory: `{"prod_1057": "women rain jacket"}`.
   Keep phrases to 2–4 plain words naming the garment and, if useful, who
   wears it: `"boy hiking pants"`, `"straw hat beach"`, `"sunglasses"`.
   Brand names, product names, and long descriptions return junk. If a
   product comes back with fewer than four candidates, simplify the phrase
   and search again; the top hits were probably paid Unsplash+ photos,
   which the script drops.

3. **Search and build the contact sheet.**

       python3 .../unsplash_images.py search queries.json WORK/

   This writes `WORK/candidates.json`, thumbnails, and `WORK/sheet-N.png`
   with four candidates per product, labelled 0–3. Re-running only
   searches the products in the queries file and keeps earlier results.

4. **Review every sheet with the Read tool** and choose an index per
   product. Prefer photos where the garment itself is clearly visible over
   portraits or scenery; match the wearer to the product (kids' products
   get kids); avoid choosing the same photo for two products, which the
   script will refuse. Write the choices to `picks.json`:
   `{"prod_1057": 2}`.

5. **Apply the picks.**

       python3 .../unsplash_images.py apply picks.json WORK/

   This rewrites `priv/repo/product_images.exs` (existing entries are kept,
   picked ones added or replaced) and regenerates the "Photo credits"
   section at the end of `README.md`.

6. **Finish in the app.**

       mix format priv/repo/product_images.exs
       mix run priv/repo/seeds.exs
       mix test

   Update the product and variant counts in the README's `mix setup` line
   if products were added. Check a category page in the browser, or
   `curl -s localhost:4000/?category=... | grep -c images.unsplash.com`.

## Swapping one photo

Run `search` with just that product and a new phrase, review the sheet,
then `apply` with its new index. Existing entries for other products are
untouched.

## Why it is built this way

- **curl, not Python requests.** The unofficial search endpoint
  (`unsplash.com/napi/search/photos`) is behind a bot check that rejects
  Python's TLS fingerprint and passes curl. No API key is needed. Keep
  requests sequential with a short pause.
- **No Unsplash+ photos.** Results whose urls are on `plus.unsplash.com`
  are paid and are excluded. Only free-license photos are recorded.
- **Hotlinking.** Photos are requested at 900×900 crop with `auto=format`
  so the repo stays small; the demo needs network access to show them.
- **Credits.** The Unsplash License does not require attribution, but the
  photographer and photo link are recorded per product and listed in the
  README anyway. Keep that section generated, not hand-edited.
