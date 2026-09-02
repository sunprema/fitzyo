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

`mix setup` seeds a Hawaii-friendly apparel catalog (42 products, 610 variants)
from `priv/repo/seeds.exs`. Re-running the seeds is safe; product and variant
ids stay stable.

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
