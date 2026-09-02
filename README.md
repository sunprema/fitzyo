# FitzYo

An agent-native shopping demo: the shopper's AI keeps the personal context,
the retailer exposes products and a cart through WebMCP. See `AGENTS.md` for
the product intent and `docs/` for the UX and WebMCP specs.

## Running locally

Requires Elixir, Postgres 16+, and a `postgres/postgres` superuser on localhost.

```sh
mix setup        # deps, database, migrations, assets, demo catalog
mix phx.server   # http://localhost:4000
```

`mix setup` seeds a Hawaii-friendly apparel catalog (56 products, 754 variants)
from `priv/repo/seeds.exs`. Re-running the seeds is safe; product and variant
ids stay stable.

## Demo: an external agent shops for the family

FitzYo has no built-in intelligence. A WebMCP-capable agent (a browser or
extension that provides `navigator.modelContext`, or a shell using the
postMessage bridge) attaches to the store page, reads its 22 tools, and drives
it using the shopper's private context in `context/`:

- `context/FAMILY.md` — sizes and preferences for Dad, Mom, and Milo
- `context/WARDROBE.md` — what they already own
- `context/TRIP.md` — seven days in Maui, itinerary, $600 budget

`docs/AGENT_PLAYBOOK.md` describes the tool surface, the privacy rule, and the
Hawaii sequence an agent should run. To rehearse it without an agent:

```sh
mix phx.server
node scripts/agent_rehearsal.mjs http://localhost:4000   # needs Chrome + Node 22+
```

## Layout

- `lib/fitzyo/catalog` — Ash domain for categories, products, variants, and
  structured size guides. `Fitzyo.Catalog.filter_products/2` and
  `find_matching_variants/2` are the queries the WebMCP tools build on.
- `lib/fitzyo/commerce` — session-scoped carts and the human-only checkout.
- `lib/fitzyo_web/live/store_live.ex` — the single LiveView that owns the
  shared human/agent state: filters (in the URL), results, selected product
  and variant, and the cart.

## Development

```sh
mix test         # runs against fitzyo_test
mix precommit    # compile with warnings as errors, format, test
mix ash.codegen <name> && mix ash.migrate   # after changing Ash resources
```

## License

FitzYo is released under the [MIT License](LICENSE).

## Photo credits

Product photos are from [Unsplash](https://unsplash.com) under the [Unsplash License](https://unsplash.com/license), hotlinked from `images.unsplash.com`. The full list, with links to each photo, is in `priv/repo/product_images.exs`. Thanks to:

- [Alex Gorey](https://unsplash.com/@alexgorey) — Capilene Cool Trail Tank
- [Alora Griffiths](https://unsplash.com/@aloragriffiths) — Sanibel Shirt Dress
- [Annie Spratt](https://unsplash.com/@anniespratt) — Saturday Trail Pants
- [Anomaly](https://unsplash.com/@anomaly) — Classic Pocket Tee
- [Artem Bondarchuk](https://unsplash.com/@artembondarchuk) — Free RN
- [Asal Mshk](https://unsplash.com/@asalmashkoori) — Coastalina Linen Shirt, Tamiami II Short Sleeve Shirt
- [Ben Masora](https://unsplash.com/@benmasora) — Essentials Tee
- [Benjamin R.](https://unsplash.com/@dapperprofessional) — Bahama II Short Sleeve Shirt
- [Callum Hill](https://unsplash.com/@inkyhills) — Kids Everyday Boardshorts, Kids Long-Sleeve Rash Guard
- [Christopher Campbell](https://unsplash.com/@chrisjoelcampbell) — Palm Coast Linen Pants
- [David Huck](https://unsplash.com/@davidhuckphotos) — Everyday 20\
- [David Trinks](https://unsplash.com/@dtrinksrph) — Fanning Flip Flops
- [Deny Hill](https://unsplash.com/@deny_hill) — Linen Sundress
- [Fashion Needles](https://unsplash.com/@fashionneedles) — Atom Sling 8L
- [Giorgio Trovato](https://unsplash.com/@giorgiotrovato) — Polarized Sunglasses
- [GlassesShop](https://unsplash.com/@glassesshop_9) — Sea Glass Breezer Linen Shirt
- [Imani Bahati](https://unsplash.com/@imani_bht) — Pegasus 41
- [Jay Mullings](https://unsplash.com/@writtenmirror) — Quandary Hiking Shorts 10\
- [Joseph Kellner](https://unsplash.com/@jkellner) — Baggies Shorts 5\, Palm Ridge One-Piece Swimsuit
- [julio andres rosario ortiz](https://unsplash.com/@cocodrilomediard) — Kids Flexible Sunglasses
- [Kakasi Kriszta](https://unsplash.com/@kakasikriszta) — Saturday Trail Short
- [Kaŕeem Saleh](https://unsplash.com/@kareem_saleh) — Kids Bahama Short Sleeve Shirt
- [Kier Allen](https://unsplash.com/@kallen2396) — Baggies Shorts 5\
- [Konara Bandara](https://unsplash.com/@kbandara) — Coastal Straw Hat
- [Kristino Boxers](https://unsplash.com/@kristinoboxers) — Silver Ridge Cargo Short, Wavefarer Boardshorts 19\
- [Laura Chouette](https://unsplash.com/@laurachouette) — Fleetwith Dress
- [Lumière Rezaie](https://unsplash.com/@lumiere_rz) — Boracay Linen Pants
- [Mawabo Mazwi](https://unsplash.com/@wabz_01) — Girls Twirl Dress
- [Michael Lee](https://unsplash.com/@guoshiwushuang) — Sunny Days Sundress
- [Miguel A Amutio](https://unsplash.com/@amutiomi) — Long-Sleeve Rash Guard
- [Modupe Falade](https://unsplash.com/@memoriesbymodupe) — Kids Dri-FIT Shorts
- [Nicholas Martinelli](https://unsplash.com/@nickmartinelli98) — Crestwood Hiking Shoe
- [Olivia Hibbins](https://unsplash.com/@olivia_hibbins) — Original Universal Sandal
- [Oswald Elsaboath](https://unsplash.com/@ozzzyphotos) — Island Maxi Dress
- [Patrick Pahlke](https://unsplash.com/@p_pixels_p) — Silver Ridge Convertible Pants
- [personalgraphic.com](https://unsplash.com/@personal_graphic) — Coolhead II Ball Cap
- [rade nugroho](https://unsplash.com/@rade_nugroho) — Kids Graphic Tee
- [Ray Shrewsberry](https://unsplash.com/@ray12119) — Bora Bora Booney Hat
- [Reza Roshan](https://unsplash.com/@rezamr2) — Sunset Wrap Dress
- [Robert Richman](https://unsplash.com/@linenese_lifestyle) — Silver Ridge Utility Lite Long Sleeve
- [S O C I A L . C U T](https://unsplash.com/@socialcut) — Sand-Free Beach Tote
- [Saman Tabrizy](https://unsplash.com/@sam932) — Girls Sundress
- [Simon Lund](https://unsplash.com/@simonlundh) — Kids Silver Ridge Pull-On Pants
- [STONES and BONES](https://unsplash.com/@stones_and_bones) — Hurricane XLT2 Sandal
- [TuanAnh Blue](https://unsplash.com/@blueeyeaa) — 405 Standard Denim Shorts, 511 Slim Fit Jeans, Capilene Cool Daily Shirt, Dri-FIT Miler Running Tee, Ribcage Straight Jeans
- [Vlady Nykulyak](https://unsplash.com/@vlad_nyk95) — XX Chino Standard Taper
- [vu khoi](https://unsplash.com/@jinkazamah) — Kids Hurricane Sandal
- [Xin](https://unsplash.com/@s1n) — Kids Bucket Hat
