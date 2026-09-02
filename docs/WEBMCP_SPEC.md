Absolutely. This should be the **contract document** your coding agent uses when implementing the WebMCP layer. It intentionally keeps the tools semantic and domain-oriented rather than exposing DOM operations.

# WEBMCP_SPEC.md

# FitzYo WebMCP Specification

**Version:** 1.0
**Status:** MVP
**Application:** FitzYo Agent-Native Retail
**Protocol:** WebMCP
**Primary Goal:** Expose semantic retail capabilities directly to AI agents.

---

# 1. Purpose

This document defines the WebMCP interface exposed by the FitzYo retail application.

The WebMCP layer allows an AI agent to interact with the retailer through structured commerce operations.

The agent should be able to:

- Discover products
- Search products
- Filter products
- Inspect product information
- Inspect variants
- Understand sizes and fit
- Find matching variants
- Compare products
- Inspect the cart
- Add products to the cart
- Modify the cart
- Navigate the human UI to relevant products or filters

The WebMCP interface is a **semantic API for the website**.

It is not a browser automation API.

---

# 2. Core Principle

## WebMCP tools operate on commerce concepts, not DOM elements.

### Never expose tools like:

```text
click_product()
click_filter()
click_size_dropdown()
click_add_to_cart()
read_product_card()
```

### Expose tools like:

```text
search_products()
filter_products()
get_product()
get_variants()
find_matching_variants()
compare_products()
add_to_cart()
```

The agent should describe **what it wants to accomplish**, and the application should determine how the UI changes.

---

# 3. Architecture

The WebMCP layer sits between the AI agent and the application domain.

```text
┌─────────────────────────┐
│       AI AGENT          │
│                         │
│ Reasoning               │
│ Planning                │
│ Personal Context        │
└────────────┬────────────┘
             │
             │ WebMCP
             ▼
┌─────────────────────────┐
│      WebMCP Layer       │
│                         │
│ Tool Registration       │
│ Schema Validation       │
│ Authorization           │
│ Domain Dispatch         │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│    Commerce Domain      │
│                         │
│ Products                │
│ Variants                │
│ Filters                 │
│ Cart                    │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│   Application State     │
│                         │
│ Search                 │
│ Results                │
│ Selected Product       │
│ Comparison             │
│ Cart                   │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────┐
│       Human UI          │
│   LiveView / Svelte     │
└─────────────────────────┘
```

The WebMCP layer must not manipulate the DOM directly.

---

# 4. WebMCP Registration

The application should register tools through the page's WebMCP interface.

Conceptually:

```javascript
document.modelContext.registerTool({
  name: "...",
  description: "...",
  inputSchema: {...},
  annotations: {...},
  execute: async (input) => {
    // Dispatch to application/domain operation
  }
});
```

The exact WebMCP API implementation should follow the currently supported WebMCP browser API.

Do not invent a parallel MCP protocol inside FitzYo.

---

# 5. Tool Design Rules

Every WebMCP tool must satisfy the following requirements.

## 5.1 Semantic

The tool represents a meaningful business operation.

## 5.2 Deterministic

Given the same application state and inputs, the operation should produce predictable results.

## 5.3 Structured

Inputs and outputs must use explicit JSON schemas.

## 5.4 Validated

Invalid product IDs, variants, filters, quantities, etc. must produce structured errors.

## 5.5 State-Aware

Tools operate against the current application/session state.

## 5.6 Idempotent Where Possible

Read operations must be safe to repeat.

State-changing operations should have predictable behavior when repeated.

## 5.7 Human-Visible

When a tool changes application state, the resulting UI change should be visible to the human.

---

# 6. Tool Categories

The FitzYo MVP exposes five categories.

```text
Discovery
Search / Filtering
Product Intelligence
Comparison
Cart
UI Navigation
```

---

# 7. Tool Inventory

| Tool                     | Type       | Purpose                              |
| ------------------------ | ---------- | ------------------------------------ |
| `get_store_info`         | Read       | Understand retailer                  |
| `get_categories`         | Read       | Discover categories                  |
| `search_products`        | Read/State | Search catalog                       |
| `filter_products`        | Read/State | Apply structured filters             |
| `get_product`            | Read       | Inspect product                      |
| `get_variants`           | Read       | Inspect variants                     |
| `get_size_guide`         | Read       | Understand sizing                    |
| `find_matching_variants` | Read       | Find variants satisfying constraints |
| `compare_products`       | Read/State | Compare products                     |
| `get_cart`               | Read       | Inspect cart                         |
| `add_to_cart`            | Write      | Add item                             |
| `remove_from_cart`       | Write      | Remove item                          |
| `update_cart_item`       | Write      | Change cart item                     |
| `clear_cart`             | Write      | Empty the cart                       |
| `recommend_product`      | State      | Agent-written reason on a product    |
| `clear_annotations`      | State      | Remove the agent's own badges        |
| `register_party_member`  | State      | Register derived constraints for one person (§62) |
| `remove_party_member`    | State      | Forget a registered person           |
| `present_plan`           | State      | Show the agent's plan                |
| `agent_update`           | State      | Banner, progress, streamed thoughts  |
| `ask_human`              | Blocking   | Hand a decision to the shopper       |
| `propose_cart`           | Blocking   | One priced basket, one approval      |
| `request_capability`     | Blocking   | Earn a tier of tools (§63)           |
| `get_store_state`        | Read       | What the human sees, incl. overrides |
| `focus_product`          | UI         | Focus product in UI                  |
| `focus_filter`           | UI         | Focus filter in UI                   |

Tools are grouped into capability tiers (§63): `read` and `suggest` are
granted on connect; `cart` (`add_to_cart`, `remove_from_cart`,
`update_cart_item`, `clear_cart`, `propose_cart`) must be requested.

---

# 8. Common Data Types

## Product ID

```text
product_id: string
```

Example:

```text
prod_1024
```

Product IDs must remain stable for the lifetime of the catalog entry.

---

## Variant ID

```text
variant_id: string
```

Example:

```text
prod_1024_blue_xl
```

A variant represents an actual purchasable configuration.

---

## Category ID

```text
category_id: string
```

Example:

```text
shirts
```

---

## Filter ID

```text
filter_id: string
```

Example:

```text
size
color
brand
fit
price
activity
```

---

# 9. Product Model

Products returned through WebMCP should have a normalized representation.

Example:

```json
{
  "id": "prod_1024",
  "name": "Performance Polo",
  "brand": "Example Brand",
  "category": "shirts",
  "description": "Lightweight performance polo",
  "price": {
    "amount": 59.99,
    "currency": "USD"
  },
  "fit": {
    "profile": "relaxed",
    "stretch": "medium",
    "length": "regular"
  },
  "activities": ["travel", "casual", "golf"],
  "colors": ["blue", "black", "white"],
  "available": true
}
```

---

# 10. Variant Model

Variants are first-class commerce objects.

Example:

```json
{
  "id": "prod_1024_blue_xl",
  "product_id": "prod_1024",
  "size": "XL",
  "color": "Blue",
  "sku": "PP-XL-BLU",
  "price": {
    "amount": 59.99,
    "currency": "USD"
  },
  "available": true,
  "inventory_status": "in_stock"
}
```

The agent must not assume that product-level availability means every variant is available.

---

# 11. Tool: `get_store_info`

## Purpose

Provides basic information about the retailer.

## Input

No input.

```json
{}
```

## Output

```json
{
  "store": {
    "id": "fitzyo-retail-demo",
    "name": "FitzYo Retail",
    "currency": "USD",
    "country": "US"
  },
  "capabilities": [
    "product_search",
    "product_filtering",
    "variant_selection",
    "comparison",
    "cart"
  ]
}
```

## Behavior

Read-only.

Must not modify application state.

---

# 12. Tool: `get_categories`

## Purpose

Returns available product categories.

## Input

```json
{}
```

## Output

```json
{
  "categories": [
    {
      "id": "shirts",
      "name": "Shirts"
    },
    {
      "id": "shorts",
      "name": "Shorts"
    },
    {
      "id": "swimwear",
      "name": "Swimwear"
    },
    {
      "id": "outerwear",
      "name": "Outerwear"
    }
  ]
}
```

---

# 13. Tool: `search_products`

## Purpose

Search the product catalog using natural-language search.

## Input Schema

```json
{
  "type": "object",
  "properties": {
    "query": {
      "type": "string"
    },
    "limit": {
      "type": "integer",
      "minimum": 1,
      "maximum": 50
    }
  },
  "required": ["query"]
}
```

## Example

```json
{
  "query": "lightweight blue shirts for travel",
  "limit": 10
}
```

## Output

```json
{
  "query": "lightweight blue shirts for travel",
  "results": [
    {
      "product_id": "prod_1024",
      "name": "Performance Polo",
      "brand": "Example Brand",
      "price": {
        "amount": 59.99,
        "currency": "USD"
      }
    }
  ],
  "total": 7
}
```

## State Behavior

Search should update the retailer's search state.

The UI should visibly reflect:

```text
Search: lightweight blue shirts for travel
```

---

# 14. Tool: `filter_products`

## Purpose

Apply structured filters to the current product catalog.

This is one of the most important WebMCP tools.

## Input Schema

```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string"
    },
    "brand": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "size": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "color": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "exclude_color": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "AND-NOT: an excluded color never satisfies color, even when also included"
    },
    "exclude_brand": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "fit": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "activity": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "price_min": {
      "type": "number",
      "minimum": 0
    },
    "price_max": {
      "type": "number",
      "minimum": 0
    },
    "member": {
      "type": "string",
      "description": "A registered party member's label (§62); fills size, colors, exclusions, brands, fit, and gender unless given"
    }
  },
  "additionalProperties": false
}
```

## Example

```json
{
  "category": "shirts",
  "size": ["XL"],
  "color": ["blue", "black"],
  "brand": ["Patagonia", "Columbia"],
  "fit": ["relaxed"],
  "price_max": 80
}
```

## Output

```json
{
  "filters_applied": {
    "category": "shirts",
    "size": ["XL"],
    "color": ["blue", "black"],
    "brand": ["Patagonia", "Columbia"],
    "fit": ["relaxed"],
    "price_max": 80
  },
  "results": [],
  "total": 4
}
```

## State Behavior

The application's canonical filter state must be updated.

The UI must reflect the active filters.

---

# 15. Filter Semantics

Filtering should use AND semantics between filter categories.

Example:

```text
size = XL
AND
color = blue
AND
fit = relaxed
AND
price <= $80
```

Within a single category, values normally use OR semantics.

Example:

```text
color = blue OR black
```

Therefore:

```text
(size = XL)
AND
(color = blue OR black)
AND
(fit = relaxed)
```

---

# 16. Tool: `get_product`

## Purpose

Returns complete information about a product.

## Input

```json
{
  "product_id": "prod_1024"
}
```

## Output

```json
{
  "product": {
    "id": "prod_1024",
    "name": "Performance Polo",
    "brand": "Example Brand",
    "category": "shirts",
    "description": "Lightweight performance polo",
    "price": {
      "amount": 59.99,
      "currency": "USD"
    },
    "fit": {
      "profile": "relaxed",
      "stretch": "medium",
      "length": "regular"
    },
    "activities": ["travel", "casual"]
  }
}
```

---

# 17. Tool: `get_variants`

## Purpose

Returns all purchasable variants for a product.

## Input

```json
{
  "product_id": "prod_1024"
}
```

## Output

```json
{
  "product_id": "prod_1024",
  "variants": [
    {
      "id": "prod_1024_blue_l",
      "size": "L",
      "color": "Blue",
      "available": true
    },
    {
      "id": "prod_1024_blue_xl",
      "size": "XL",
      "color": "Blue",
      "available": true
    }
  ]
}
```

---

# 18. Tool: `get_size_guide`

## Purpose

Returns structured sizing information.

## Input

```json
{
  "product_id": "prod_1024"
}
```

## Output

```json
{
  "product_id": "prod_1024",
  "size_system": "US",
  "measurements": [
    {
      "size": "L",
      "chest_min": 42,
      "chest_max": 44
    },
    {
      "size": "XL",
      "chest_min": 44,
      "chest_max": 46
    }
  ],
  "unit": "inches"
}
```

The data must be structured.

Do not return only an image or unstructured size-chart text.

---

# 19. Tool: `find_matching_variants`

## Purpose

Find variants that satisfy a set of fit and shopping constraints.

This is the key tool for the FitzYo experience.

The agent supplies constraints derived from the user's private context.

The retailer does not need to know the user's identity.

## Input

```json
{
  "type": "object",
  "properties": {
    "category": {
      "type": "string"
    },
    "size": {
      "type": "string"
    },
    "color": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "brand": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "exclude_color": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Hard constraint, never relaxed"
    },
    "exclude_brand": {
      "type": "array",
      "items": {
        "type": "string"
      },
      "description": "Hard constraint, never relaxed"
    },
    "fit": {
      "type": "string"
    },
    "activity": {
      "type": "array",
      "items": {
        "type": "string"
      }
    },
    "price_max": {
      "type": "number"
    },
    "label": {
      "type": "string"
    },
    "member": {
      "type": "string",
      "description": "A registered party member's label (§62): resolves the size for the category, or every size system when no category is given"
    }
  }
}
```

With `member`, the reply carries `resolved_for` and `constraints.sizes`, the
size labels the store resolved for that person.

## Example

```json
{
  "category": "shirts",
  "size": "XL",
  "color": ["blue", "black"],
  "brand": ["Patagonia", "Columbia"],
  "fit": "relaxed",
  "activity": ["travel"],
  "price_max": 80
}
```

## Output

```json
{
  "matches": [
    {
      "product_id": "prod_1024",
      "variant_id": "prod_1024_blue_xl",
      "match": {
        "size": true,
        "color": true,
        "brand": true,
        "fit": true,
        "activity": true,
        "price": true
      },
      "match_score": 0.96
    }
  ]
}
```

The match score is optional for MVP.

The important requirement is that the output explains which constraints matched.

---

# 20. Important Privacy Rule

`find_matching_variants` should receive **shopping constraints**, not the entire user profile.

Good:

```json
{
  "size": "XL",
  "color": ["blue"],
  "fit": "relaxed"
}
```

Avoid:

```json
{
  "name": "John Smith",
  "age": 48,
  "chest": 45,
  "weight": 198,
  "family": "...",
  "wardrobe": "..."
}
```

The agent performs the personal reasoning before calling the retailer.

---

# 21. Tool: `compare_products`

## Purpose

Compare multiple products.

## Input

```json
{
  "product_ids": ["prod_1024", "prod_2048", "prod_3072"]
}
```

## Output

```json
{
  "products": [
    {
      "id": "prod_1024",
      "name": "Performance Polo",
      "price": 59.99,
      "brand": "Columbia",
      "fit": "relaxed"
    },
    {
      "id": "prod_2048",
      "name": "Travel Polo",
      "price": 69.99,
      "brand": "Patagonia",
      "fit": "regular"
    }
  ]
}
```

## State Behavior

The comparison products should become visible in the retailer UI.

---

# 22. Tool: `get_cart`

## Purpose

Returns the current cart.

## Input

```json
{}
```

## Output

```json
{
  "cart": {
    "items": [
      {
        "product_id": "prod_1024",
        "variant_id": "prod_1024_blue_xl",
        "name": "Performance Polo",
        "size": "XL",
        "color": "Blue",
        "quantity": 1,
        "unit_price": 59.99
      }
    ],
    "subtotal": 59.99,
    "currency": "USD"
  }
}
```

---

# 23. Tool: `add_to_cart`

## Purpose

Adds a specific purchasable variant to the cart.

## Input

```json
{
  "product_id": "prod_1024",
  "variant_id": "prod_1024_blue_xl",
  "quantity": 1
}
```

## Validation

The application must verify:

1. Product exists.
2. Variant exists.
3. Variant belongs to product.
4. Variant is available.
5. Quantity is valid.

## Output

```json
{
  "success": true,
  "cart": {
    "item_count": 1,
    "subtotal": 59.99
  }
}
```

## State Behavior

The cart UI must update immediately.

---

# 24. Tool: `remove_from_cart`

## Input

```json
{
  "product_id": "prod_1024",
  "variant_id": "prod_1024_blue_xl"
}
```

## Output

```json
{
  "success": true,
  "cart": {
    "item_count": 0,
    "subtotal": 0
  }
}
```

---

# 25. Tool: `update_cart_item`

## Purpose

Modify an existing cart item.

## Input

```json
{
  "product_id": "prod_1024",
  "variant_id": "prod_1024_blue_xl",
  "quantity": 2
}
```

The MVP may support quantity updates only.

Variant changes can be implemented later if necessary.

---

# 26. Tool: `focus_product`

## Purpose

Direct the human UI to a product the agent is discussing.

This tool does not perform a commerce action.

## Input

```json
{
  "product_id": "prod_1024"
}
```

## Behavior

The application should:

- Scroll to the product
- Highlight it
- Select it if appropriate

The product must remain visible to the human.

---

# 27. Tool: `focus_filter`

## Purpose

Direct the human's attention to an active filter.

## Input

```json
{
  "filter_id": "size"
}
```

The UI should visually highlight the relevant filter.

---

# 28. Read vs Write Tools

Tools should be classified conceptually.

## Read-only

```text
get_store_info
get_categories
get_product
get_variants
get_size_guide
get_cart
```

## Search / state navigation

```text
search_products
filter_products
compare_products
find_matching_variants
```

These may change visible application state.

## Write operations

```text
add_to_cart
remove_from_cart
update_cart_item
```

## UI operations

```text
focus_product
focus_filter
```

---

# 29. Tool Annotations

Where supported by WebMCP, tools should provide accurate annotations describing their behavior.

Conceptually:

```javascript
annotations: {
  readOnlyHint: true;
}
```

for read-only operations.

Write operations should explicitly indicate that they modify state.

Do not mark a state-changing tool as read-only.

---

# 30. Structured Errors

Never return arbitrary strings for failures.

Errors should be structured.

Example:

```json
{
  "success": false,
  "error": {
    "code": "VARIANT_UNAVAILABLE",
    "message": "The requested XL Blue variant is currently unavailable.",
    "product_id": "prod_1024",
    "variant_id": "prod_1024_blue_xl"
  }
}
```

Recommended error codes:

```text
PRODUCT_NOT_FOUND
VARIANT_NOT_FOUND
VARIANT_UNAVAILABLE
INVALID_FILTER
INVALID_CATEGORY
INVALID_QUANTITY
CART_ITEM_NOT_FOUND
INVALID_OPERATION
CAPABILITY_NOT_GRANTED     the tool's tier has not been granted (§63); carries capability and hint
CAPABILITY_SCOPE_EXCEEDED  a cart write would pass the granted ceiling; carries max_spend, cart_subtotal, projected_total
MEMBER_NOT_FOUND           member: names nobody registered (§62)
PRIVATE_CONTEXT_REJECTED   register_party_member received a field that is not a derived constraint; names the fields
```

---

# 31. Tool Failure Behavior

A failed tool operation must not leave the application in a partially modified state.

For example:

```text
add_to_cart()
     ↓
validate
     ↓
if invalid
     ↓
return error
     ↓
do not modify cart
```

Operations should be atomic where practical.

---

# 32. Application State

The retailer should maintain one canonical application state.

Conceptually:

```text
ApplicationState
├── searchQuery
├── category
├── filters            (each constraint with an origin: agent | human)
├── results            (with excluded_by: products each facet hides)
├── selectedProduct
├── selectedVariant
├── comparisonProducts
├── annotations        ("Fits Dad", recommendations)
├── members            (registered party, §62)
├── capabilities       (granted tiers and scopes, §63)
└── cart               (lines carry source: human | agent | proposal)
```

`get_store_state` reports all of it, including `filter_origins`,
`excluded_by`, and `removed_by_human`: the constraints the shopper removed
that an agent should not re-impose (§64).

WebMCP operations interact with this state.

The human UI renders this state.

The agent does not maintain a competing copy of retailer state.

---

# 33. State Synchronization

Example:

```text
Agent
  │
  │ filter_products()
  ▼
Application State
  │
  ├── filters updated
  ├── results updated
  └── selected state preserved where possible
  │
  ▼
LiveView/Svelte
  │
  ▼
Human sees updated products
```

Human interaction follows the reverse direction:

```text
Human
  │
  ▼
UI
  │
  ▼
Application State
  │
  ▼
Agent can inspect current state
```

---

# 34. Agent Context vs Retailer Context

FitzYo intentionally separates these.

## Agent context

May include:

```text
Family
Measurements
Preferences
Wardrobe
Trip
Activities
Budget
Personal priorities
```

## Retailer context

Contains:

```text
Products
Variants
Prices
Inventory
Availability
Categories
Commerce state
```

The WebMCP API should primarily expose retailer context.

The agent combines both contexts.

---

# 35. No Central FitzYo Profile API

The MVP must not require:

```text
POST /api/family-profile
POST /api/user-measurements
POST /api/wardrobe
```

to the retailer.

The retailer should remain generic.

The agent should be able to bring the necessary constraints to the retailer.

This is a fundamental architectural property of FitzYo.

---

# 36. "Fits Dad" Implementation

"Fits Dad" is a presentation concept.

The retailer should not create a permanent user named "Dad."

Instead, the agent can derive:

```text
Dad
→ XL
→ Blue
→ Relaxed
→ Columbia
```

and use:

```text
find_matching_variants()
```

The UI may then display:

```text
✓ Fits Dad
```

The mapping between a private person and retailer constraints belongs to the agent/user context.

---

# 37. Agent Activity

The application should maintain a human-readable activity stream.

Example:

```text
Agent Activity

✓ Searching for travel shirts
✓ Filtering for XL
✓ Filtering for blue and black
✓ Checking available variants
✓ Comparing 3 products
✓ Added Performance Polo to cart
```

The activity stream must describe **high-level tool actions**.

Do not expose hidden chain-of-thought.

---

# 38. Human Confirmation

The agent can perform reversible shopping operations.

For MVP:

```text
SEARCH       → automatic
FILTER       → automatic
COMPARE      → automatic
INSPECT      → automatic
ADD TO CART  → automatic
```

Final purchase should require explicit human confirmation.

```text
CHECKOUT
   ↓
HUMAN REVIEW
   ↓
HUMAN CONFIRMATION
```

Do not implement automatic payment or autonomous purchasing in the MVP.

---

# 39. Idempotency

Operations should behave predictably if an agent repeats them.

For example:

```text
add_to_cart(product, variant, quantity)
```

should have deterministic behavior.

The application should avoid accidental duplicate items caused solely by an agent retry.

A reasonable MVP behavior is:

```text
same variant already exists
        ↓
increase quantity
```

rather than creating multiple indistinguishable cart lines.

---

# 40. Search and Filter Relationship

`search_products()` and `filter_products()` serve different purposes.

Search:

```text
search_products("lightweight travel shirt")
```

answers:

> What products are relevant to this concept?

Filtering:

```text
filter_products({
  size: ["XL"],
  color: ["blue"],
  price_max: 80
})
```

answers:

> Which products satisfy these explicit constraints?

The agent may use both:

```text
search_products()
        ↓
filter_products()
        ↓
find_matching_variants()
```

---

# 41. Example Agent Workflow

User:

> "We're going to Hawaii for seven days. Find Dad two shirts under $80 that fit him and work for casual dinners."

Agent reasoning:

```text
Private Context

Dad:
  size = XL
  fit = relaxed
  colors = blue, black
  brands = Columbia, Patagonia

Trip:
  Hawaii
  casual dinners
```

Agent calls:

```text
search_products(
  "lightweight shirts for Hawaii casual dinner"
)
```

Then:

```text
filter_products({
  category: "shirts",
  size: ["XL"],
  color: ["blue", "black"],
  brand: ["Columbia", "Patagonia"],
  price_max: 80
})
```

Then:

```text
find_matching_variants({
  category: "shirts",
  size: "XL",
  color: ["blue", "black"],
  brand: ["Columbia", "Patagonia"],
  fit: "relaxed",
  activity: ["travel", "casual"],
  price_max: 80
})
```

Then:

```text
compare_products([
  "prod_1024",
  "prod_2048",
  "prod_3072"
])
```

Finally:

```text
add_to_cart(
  "prod_1024",
  "prod_1024_blue_xl",
  1
)
```

The human sees every meaningful state change.

---

# 42. Example Constraint Refinement

User initially asks:

> "Find me a shirt."

Agent searches.

User then says:

> "Actually, keep everything under $50."

Agent does not restart the entire application.

It modifies the current state:

```text
filter_products({
  price_max: 50
})
```

The retailer UI updates immediately.

---

# 43. Example Human Override

Agent has selected:

```text
Blue Performance Polo
```

Human clicks:

```text
Black
```

The application state changes.

The agent should subsequently observe the new state rather than assuming its previous selection remains active.

The human always has authority over the shared UI state.

---

# 44. Tool Output Design

Tool responses should contain enough structured information for an agent to continue reasoning.

Avoid returning only:

```text
"Done"
```

Prefer:

```json
{
  "success": true,
  "product_id": "prod_1024",
  "variant_id": "prod_1024_blue_xl",
  "cart": {
    "item_count": 2,
    "subtotal": 119.98
  }
}
```

The agent should not have to scrape the UI to understand what happened.

---

# 45. Stable IDs

All semantic objects exposed through WebMCP must have stable IDs.

Required:

```text
product_id
variant_id
category_id
filter_id
cart_item_id
```

Do not use:

```text
DOM index
array index
CSS selector
generated temporary identifier
```

as semantic identifiers.

Bad:

```text
product_3
```

if `3` simply means the third card currently rendered.

Good:

```text
prod_1024
```

---

# 46. WebMCP and DOM

The DOM remains important for human interaction and accessibility.

However, the WebMCP layer must not depend on DOM structure.

This means:

```text
DOM changes
```

should not break:

```text
WebMCP tools
```

The domain/API layer is the contract.

The UI is an implementation of that contract.

---

# 47. Semantic HTML

Although WebMCP should not depend on the DOM, the UI should still use semantic HTML.

Product cards should expose meaningful attributes where useful:

```html
<article data-product-id="prod_1024" data-category="shirts"></article>
```

Variants:

```html
<button data-variant-id="prod_1024_blue_xl">Blue / XL</button>
```

These attributes support:

- Accessibility
- Debugging
- Testing
- Human-agent observability
- Future browser capabilities

They must not become the WebMCP implementation mechanism.

---

# 48. Performance

WebMCP interactions should feel immediate.

Target:

```text
Tool invocation
      ↓
Domain operation
      ↓
State update
      ↓
UI update
```

should normally complete in:

```text
< 250 ms
```

for local/demo operations.

Avoid unnecessary network calls inside individual WebMCP tools.

---

# 49. Security

WebMCP tools operate within the current retailer session.

Validate all inputs.

Never trust:

```text
product_id
variant_id
quantity
price
```

supplied by the agent.

The server/domain layer remains authoritative.

The agent cannot override:

- Product price
- Availability
- Inventory
- Variant ownership
- Cart validation

---

# 50. Price Integrity

The agent must never be able to supply an arbitrary price when adding an item.

Bad:

```json
{
  "product_id": "prod_1024",
  "price": 1
}
```

The application determines the actual price from the product/variant record.

```text
variant_id
    ↓
authoritative product data
    ↓
actual price
```

---

# 51. Inventory Integrity

Likewise, availability must always come from the retailer.

The agent may request:

```text
XL / Blue
```

but the retailer determines whether:

```text
XL / Blue
```

is actually available.

---

# 52. Checkout Boundary

The MVP WebMCP interface stops at cart management.

Do not expose:

```text
submit_payment()
purchase()
place_order()
```

in the MVP.

The final transaction should remain human-controlled.

---

# 53. Minimal MVP Tool Set

If implementation time becomes constrained, prioritize these tools:

```text
search_products
filter_products
get_product
get_variants
find_matching_variants
compare_products
get_cart
add_to_cart
focus_product
```

These tools are sufficient to demonstrate the core FitzYo thesis.

---

# 54. Implementation Priority

Implement in this order:

## Phase 1 — Catalog

```text
Product
Variant
Category
Inventory
```

## Phase 2 — Retail UI

```text
Product listing
Product card
Filters
Product detail
Cart
```

## Phase 3 — Application State

```text
Search
Filters
Selection
Comparison
Cart
```

## Phase 4 — WebMCP

```text
search_products
filter_products
get_product
get_variants
get_size_guide
find_matching_variants
compare_products
get_cart
add_to_cart
```

## Phase 5 — Agent UX

```text
Agent activity
Fits Dad
Focus product
Human override
```

## Phase 6 — Demo Polish

```text
Hawaii scenario
Family context
Wardrobe
Budget
Agent-driven shopping
```

---

# 55. Testing Requirements

Every WebMCP tool should have tests for:

### Valid input

```text
valid product
valid variant
valid filters
valid cart operation
```

### Invalid input

```text
unknown product
unknown variant
wrong product/variant combination
invalid quantity
unavailable variant
invalid filter
```

### State synchronization

Verify that:

```text
tool operation
      ↓
application state
      ↓
UI
```

remains consistent.

### Human override

Verify that human changes remain authoritative.

---

# 56. End-to-End Acceptance Test

The application should support the following scenario.

### User Context

```text
Dad

Size: XL
Fit: Relaxed
Colors: Blue, Black
Brands: Columbia, Patagonia
```

### User Request

```text
We're going to Hawaii for seven days.
Find Dad two shirts for casual dinners.
Keep them under $80 each.
```

### Expected Agent Behavior

```text
search_products()
        ↓
filter_products()
        ↓
find_matching_variants()
        ↓
compare_products()
        ↓
recommend products
        ↓
add_to_cart()
```

### Expected Human Experience

The user should see:

```text
Searching...

4 products found

Filtering:
✓ XL
✓ Blue / Black
✓ Relaxed
✓ Columbia / Patagonia
✓ Under $80

Best matches:

┌──────────────────────────┐
│ Performance Polo        │
│ Columbia                │
│ $59.99                  │
│                         │
│ ✓ Fits Dad              │
│ ✓ Available XL          │
└──────────────────────────┘
```

The selected product can then be added to the cart.

---

# 57. What Makes This WebMCP-Native

FitzYo should demonstrate that the agent is not simply reading the page.

The agent is using **capabilities intentionally designed for agents**.

The distinction is:

```text
Traditional AI Shopping

AI
 ↓
Read webpage
 ↓
Infer buttons
 ↓
Click UI
 ↓
Read webpage
```

versus:

```text
FitzYo

AI
 ↓
Understand user intent
 ↓
Call semantic commerce tools
 ↓
Retail domain executes operation
 ↓
Shared application state changes
 ↓
Human sees result
```

That distinction should be obvious during the demo.

---

# 58. Design Principle: Capability Over Automation

The goal of WebMCP is not to make an agent better at clicking websites.

The goal is to give the agent **capabilities that websites previously did not expose directly**.

For FitzYo:

```text
"Find products that satisfy these constraints"
```

is a capability.

```text
"Click the size XL checkbox"
```

is automation.

FitzYo should prioritize the former.

---

# 59. Design Principle: Agent + Human

The agent should handle:

```text
Complexity
Search
Filtering
Reasoning
Comparison
Planning
```

The human should handle:

```text
Intent
Preference
Judgment
Taste
Final approval
```

The best experience is therefore:

```text
Human:
"I need clothes for Hawaii."

Agent:
"I found what you're missing."

Human:
"I don't like this shirt."

Agent:
"I'll find alternatives."

Human:
"That one looks good."

Agent:
"Added it to your cart."

Human:
"Checkout."
```

---

# 60. Final Contract

The FitzYo WebMCP implementation must preserve these principles:

1. **WebMCP is a semantic commerce interface.**
2. **Tools operate on domain objects, not DOM elements.**
3. **Human and agent share the same application state.**
4. **The retailer owns product and commerce data.**
5. **The user's personal context remains with the user/agent.**
6. **Only task-relevant constraints should cross the WebMCP boundary.**
7. **Product variants are first-class objects.**
8. **Tool inputs and outputs are structured.**
9. **State-changing operations are visible to the human.**
10. **Human actions always remain authoritative.**
11. **Checkout/payment remains human-controlled in the MVP.**
12. **The WebMCP interface should remain useful even if the UI is completely redesigned.**

---

# 61. FitzYo WebMCP Thesis

The fundamental idea behind the implementation is:

```text
              PERSONAL CONTEXT
                     │
                     ▼
              ┌─────────────┐
              │  AI AGENT   │
              │             │
              │ Reasoning   │
              │ Planning    │
              │ Preferences │
              └──────┬──────┘
                     │
                     │ WebMCP
                     ▼
              ┌─────────────┐
              │  RETAILER   │
              │             │
              │ Products    │
              │ Variants    │
              │ Inventory   │
              │ Cart        │
              └──────┬──────┘
                     │
                     ▼
                 HUMAN UI
```

The agent brings **knowledge about the person**.

The retailer exposes **knowledge about its products**.

WebMCP provides the **capability boundary** between them.

That is the core technical and product thesis of FitzYo.

> **Your AI knows what fits you. The web doesn't have to.**

This gives your coding agent a clean contract: **`AGENTS.md` explains the product intent → `RETAIL_UX_REQUIREMENTS.md` explains the human/retail experience → `WEBMCP_SPEC.md` defines the machine interface.**

---

# 62. Party Members

`register_party_member` lets an agent register the people it is shopping
for as **derived constraints**: a label, one size per size system (`tops`,
`bottoms`, `inseam`, `shoes`, `hats`, `dresses`), colour and brand
preferences and avoid-lists, a fit, a budget, and a shopper group.

```json
{"label": "Dad", "gender": "men",
 "sizes": {"tops": "XL", "bottoms": "36", "inseam": "32", "shoes": "11", "hats": "L/XL"},
 "colors": ["blue", "black", "navy"], "exclude_colors": ["red"],
 "brands": ["Columbia", "Patagonia"], "fit": "relaxed", "budget": 300}
```

The schema has `additionalProperties: false` and the server refuses any
other field with `PRIVATE_CONTEXT_REJECTED`, naming it. No name, age,
measurement, or reason is accepted; if a field would embarrass the shopper
on a retailer's server, it does not belong here.

With a member registered:

- `find_matching_variants` and `filter_products` accept `member: "Dad"` and
  resolve the size for the category themselves (shirts → tops; shorts and
  swimwear → bottoms or tops; pants → bottoms, `bottoms x inseam`, or tops;
  shoes → shoes; accessories → hats). With no category, every size system is
  sent as one OR list; the same-variant rule keeps it precise.
- Product cards badge every member a product fits (an in-stock variant in
  one of their sizes, not an avoided colour, within their shopper group).
- The cart drawer, `get_cart.by_label`, and proposals show per-member
  subtotals against per-member budgets; `propose_cart.budget.by_label`
  defaults from registered members.
- `remove_party_member` (or the × in the agent panel) forgets the person and
  clears their badges and matches.

Members live in the session only.

---

# 63. Capability Scopes

An agent does not get the whole surface on connect. Tools belong to tiers:

| Tier      | Tools                                                                                                              | Default     |
| --------- | ------------------------------------------------------------------------------------------------------------------ | ----------- |
| `read`    | `get_*`, `search_products`, `filter_products`, `find_matching_variants`, `compare_products`, `get_store_state`     | granted     |
| `suggest` | `recommend_product`, `clear_annotations`, `present_plan`, `agent_update`, `ask_human`, `focus_*`, party members     | granted     |
| `cart`    | `add_to_cart`, `remove_from_cart`, `update_cart_item`, `clear_cart`, `propose_cart`                                 | not granted |

A call into an ungranted tier fails with `CAPABILITY_NOT_GRANTED` and
changes nothing. `request_capability` is a blocking call, like `ask_human`:

```json
{"capability": "cart", "reason": "to assemble the beach-trip basket you asked for",
 "scope": {"max_spend": 600, "expires_ms": 1800000}}
→ {"granted": true, "capability": "cart", "scope": {"max_spend": 600, "expires_at_ms": 1788400000000}}
→ {"granted": false, "capability": "cart", "reason": "denied" | "timeout" | "superseded"}
```

The request renders in the agent panel with the ceiling editable; the
shopper's figure wins. `max_spend` is enforced **server-side at every cart
write**, including accepting a proposal: a write that would push the whole
cart past it fails with `CAPABILITY_SCOPE_EXCEEDED` and the current
figures, and the cart is unchanged. `expires_ms` revokes the tier
mid-session. The shopper can revoke or pre-authorise any tier from the panel
at any time, `read` included. `get_store_state.capabilities` and
`get_store_info.granted_capabilities` report grants, scopes, and expiry.
Grants, denials, revocations, and expiries appear in the activity feed.

No grant enables checkout: there is no checkout tool to grant (§52).

---

# 64. Constraint Origin and Exclusion Counts

Every active constraint records who set it. Chip groups in the results
header show the facet, its origin (`✦ agent` or `you`), and `hiding N`: how
many more products would show if only that facet were dropped. A chip
removes one value; the group's × drops the whole facet.

`get_store_state` exposes `filter_origins` (per facet: `agent`, `human`, or
`mixed`), `excluded_by` (per facet counts), and `removed_by_human`: the
agent-set constraints the shopper removed this session. An agent that
re-applies one of those, or clears a constraint the shopper set, is written
to the feed as a warning, so the correction is visible to both sides.

---

# 65. Negative Constraints

`filter_products` and `find_matching_variants` take `exclude_color` and
`exclude_brand`. They are AND-NOT against the OR-within-facet rule: an
excluded colour never satisfies `color`, even when it is also included, and
an excluded brand never appears. For matching they are hard constraints,
never relaxed in the fallback. They render as `not Red` chips, are
removable by the human, appear in `filters_applied` and
`get_store_state.filters` (`exclude_color`, `exclude_brand`), and an
excluded swatch is struck through in the sidebar.

---

# 66. Order Provenance

Every cart line carries `source` (`human`, `agent`, or `proposal`) and, when
the shopper swapped a proposed line for an alternative the agent offered,
`proposed_variant_id`. Checkout returns `lines` with that provenance and a
`by_source` summary (`human`, `agent`, `proposal`, `substituted`); the
confirmation lists each line with its badge and the activity feed records
the split next to the order number.
