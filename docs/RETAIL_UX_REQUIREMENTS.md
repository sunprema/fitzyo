# RETAIL_UX_REQUIREMENTS.md

# FitzYo Agent-Friendly Retail Experience

**Project:** FitzYo
**Document:** Retail UX Requirements
**Version:** 1.0
**Purpose:** Hackathon MVP / WebMCP Demonstration
**Status:** Implementation Ready

---

## 1. Purpose

This document defines the UX, UI, application-state, semantic markup, and WebMCP requirements for an **agent-friendly retail website** used by FitzYo.

The website must support two equal consumers:

1. **Human shoppers** interacting through the normal visual interface.
2. **AI agents** interacting through WebMCP.

The critical architectural principle is:

> **WebMCP tools MUST operate on semantic commerce objects and application state, not low-level DOM interactions.**

The human and the AI agent must interact with the **same underlying retail state**.

For example:

```text
Agent:
filter_products({
  size: "16.5/34",
  color: ["navy"],
  max_price: 70
})

        ↓

Retail Application State

        ↓

Human UI updates

        ↓

Agent can inspect the resulting state
```

The agent must never need to simulate mouse clicks or infer the meaning of arbitrary visual elements.

---

# 2. Product Vision

FitzYo demonstrates a new model of AI-assisted commerce:

> **The user's AI knows the user. The retailer knows its products. WebMCP allows them to work together.**

The retailer does NOT need to maintain the user's:

- family profile
- measurements
- clothing preferences
- personal style
- wardrobe
- travel plans

The user's desktop AI agent may have access to this private context.

The retailer exposes its product capabilities through WebMCP.

The agent combines the two.

```text
USER'S PRIVATE CONTEXT
        │
        │ Desktop AI Agent
        │
        ▼
      WebMCP
        │
        ▼
RETAILER'S COMMERCE CAPABILITIES
        │
        ▼
      Products
```

---

# 3. MVP Demonstration Scenario

The primary demonstration scenario is:

> **"We're going to Hawaii for seven days. Plan what my family should wear and find the things we don't already own."**

The agent may know:

```text
Dad:
  Shirt: 16.5/34
  Pants: 34x32
  Shoes: 11
  Preferred colors: navy, gray
  Preferred brands: Columbia, Patagonia
  Style: casual

Mom:
  ...

Child:
  ...
```

The retailer knows:

```text
Products
Prices
Sizes
Colors
Brands
Fit
Materials
Activities
Availability
```

The agent combines the two.

The retailer UI should visibly update as the agent works.

---

# 4. UX Principles

## 4.1 Human and Agent Share One State

There must be a single canonical commerce state.

```text
                   Commerce State
                         │
             ┌───────────┴───────────┐
             ↓                       ↓
        Human UI                  WebMCP
```

Never maintain separate agent and human representations of:

- search
- filters
- selected product
- selected variant
- cart
- comparison
- category

---

## 4.2 Semantic Rather Than Visual Interaction

Bad:

```text
click_button_17()
scroll_400px()
click_element_293()
```

Good:

```text
filter_products(...)
get_product(...)
select_variant(...)
add_to_cart(...)
```

The agent should operate using business concepts.

---

## 4.3 Deterministic State

Every WebMCP operation must produce deterministic application state.

Repeated calls should not unexpectedly duplicate state.

Example:

```text
filter_products({color: "navy"})
```

called twice must result in the same state.

---

## 4.4 Visible Agent Actions

Agent actions must be reflected visibly in the UI.

If the agent filters products:

```text
Agent:
filter size = 16.5/34
```

the human must see:

```text
SIZE
● 16.5 / 34
```

selected in the filter UI.

---

# 5. Application Layout

The desktop retail experience should use the following structure:

```text
┌──────────────────────────────────────────────────────────────┐
│ FitzYo Store                                  ✦ Agent ●      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ Search products...                                           │
│                                                              │
├───────────────┬──────────────────────────────────────────────┤
│               │                                              │
│ FILTERS       │ PRODUCT RESULTS                             │
│               │                                              │
│ Category      │ ┌────────────┐ ┌────────────┐ ┌────────────┐ │
│               │ │ Product    │ │ Product    │ │ Product    │ │
│ Size          │ │            │ │            │ │            │ │
│               │ │ $49        │ │ $59        │ │ $69        │ │
│ Color         │ └────────────┘ └────────────┘ └────────────┘ │
│               │                                              │
│ Brand         │                                              │
│               │                                              │
│ Price         │                                              │
│               │                                              │
│ Fit           │                                              │
│               │                                              │
└───────────────┴──────────────────────────────────────────────┘
```

An optional collapsible Agent Activity panel may appear on the right or bottom.

---

# 6. Global Semantic Application State

The retailer must maintain a canonical state similar to:

```javascript
{
  searchQuery: "",
  category: null,

  filters: {
    brands: [],
    colors: [],
    sizes: [],
    fits: [],
    materials: [],
    activities: [],
    minPrice: null,
    maxPrice: null
  },

  results: [],

  selectedProduct: null,
  selectedVariant: null,

  comparisonProducts: [],

  cart: []
}
```

The exact implementation may use Phoenix LiveView assigns, Svelte state, or another state mechanism.

However, the conceptual state must remain consistent.

---

# 7. Product Data Model

Every product must contain normalized semantic attributes.

Minimum fields:

```text
id
title
brand
category
description
price
currency

gender
age_group

fit
material

colors[]
sizes[]

activities[]

variants[]
```

Example:

```json
{
  "id": "prod_123",
  "title": "Performance Polo",
  "brand": "Columbia",
  "category": "mens-shirt",
  "price": 49.99,
  "currency": "USD",
  "gender": "men",
  "fit": "regular",
  "material": "polyester",
  "colors": ["navy", "gray", "red"],
  "sizes": ["16/34", "16.5/34", "17/34"],
  "activities": ["travel", "casual", "outdoor"]
}
```

---

# 8. Product Card Requirements

Every product card MUST have:

- stable product ID
- product name
- brand
- price
- primary category
- available colors
- available sizes
- fit
- availability status
- stable DOM identifier

Example semantic structure:

```html
<article
  id="product-prod_123"
  data-product-id="prod_123"
  data-product-name="Performance Polo"
  data-brand="Columbia"
  data-category="mens-shirt"
></article>
```

The exact HTML implementation may vary.

The semantic information must remain accessible to the agent.

---

# 9. Product Variant Requirements

A product and its variants must be treated separately.

Example:

```text
Performance Polo
│
├── Navy
│   ├── 16/34
│   ├── 16.5/34
│   └── 17/34
│
├── Gray
│   ├── 16/34
│   └── 16.5/34
│
└── Red
    └── 16.5/34
```

Every variant must have:

```text
variant_id
product_id
color
size
availability
price
```

If inventory varies by variant, availability MUST be represented at the variant level.

---

# 10. Stable Identifiers

All important semantic objects must have stable IDs.

Examples:

```text
product-prod_123

variant-prod_123-navy-16_5_34

filter-size-16_5_34

filter-color-navy

filter-brand-columbia

cart-item-prod_123
```

Do not rely on generated DOM identifiers as semantic identity.

---

# 11. Search UX

The search interface must support normal human searching.

Example:

```text
[ men's casual shirts                     ] [Search]
```

The search result state must also be accessible to WebMCP.

The agent should be able to invoke:

```text
search_products(query)
```

rather than simulate typing.

After an agent search, the human must see:

```text
Search:
men's casual shirts

47 products found
```

---

# 12. Filter UX

Filters must be explicit and semantic.

Required MVP filters:

### Category

```text
Shirts
Pants
Shorts
Shoes
Dresses
Swimwear
```

### Size

Examples:

```text
S
M
L
XL

16/34
16.5/34
17/34

30x32
32x32
34x32
```

### Color

```text
Black
White
Navy
Gray
Blue
Red
Green
```

### Brand

```text
Columbia
Patagonia
Levi's
Nike
Adidas
```

### Price

```text
Minimum
Maximum
```

### Fit

```text
Slim
Regular
Relaxed
Oversized
```

### Activity

```text
Travel
Beach
Hiking
Casual
Dinner
Outdoor
Running
```

---

# 13. Filter State Requirements

Each filter must expose machine-readable values.

Example:

```html
<button
  id="filter-color-navy"
  data-filter-type="color"
  data-filter-value="navy"
>
  Navy
</button>
```

The UI must clearly show active filters.

Example:

```text
ACTIVE FILTERS

× Navy
× 16.5/34
× Columbia
× Under $70
```

---

# 14. Combined Filtering

The application MUST support multiple simultaneous constraints.

Example:

```json
{
  "size": "16.5/34",
  "colors": ["navy", "gray"],
  "brands": ["Columbia", "Patagonia"],
  "fit": "regular",
  "max_price": 70
}
```

The result set should update as one coherent operation.

---

# 15. Product Detail Page

The product detail page must expose:

```text
Product
Brand
Description
Price
Materials
Fit
Colors
Sizes
Activities
Availability
Size Guide
```

Example:

```text
Performance Polo

Columbia
$49.99

Fit
Regular

Material
Lightweight polyester

Activities
Travel
Casual
Outdoor

Colors
Navy
Gray
Red
```

---

# 16. Fit Information

Because FitzYo is specifically concerned with personal fit, clothing products should expose fit information wherever possible.

Example:

```text
FIT INFORMATION

Cut: Regular
Stretch: Medium
Weight: Lightweight

Chest:
42–44"

Sleeve:
34"

Length:
30"
```

---

# 17. Size Guide

Size guides must be structured.

Example:

```text
Size      Chest       Neck       Sleeve

16/34     40–42"      16"        34"
16.5/34   42–44"      16.5"      34"
17/34     44–46"      17"        34"
```

The agent should be able to retrieve this information through:

```text
get_size_guide(product_id)
```

The retailer should NOT expect the agent to parse a screenshot of a size chart.

---

# 18. Fit Matching

The retailer should support a semantic fit result.

Example:

```text
FIT MATCH

16.5 / 34
✓ Available

Regular fit
✓ Matches requested fit

Navy
✓ Available
```

For the MVP, the retailer does not need to know the user's identity.

The agent can supply the relevant measurements or desired size.

Example:

```text
find_matching_variants(
  product_id,
  size="16.5/34",
  color="navy"
)
```

---

# 19. "Fits Dad" UX

The UI may display an agent-provided contextual match.

Example:

```text
┌───────────────────────────────┐
│ Performance Polo              │
│ Columbia                      │
│ $49.99                        │
│                               │
│ ✦ FitzYo Match                │
│                               │
│ Size: 16.5/34 ✓               │
│ Color: Navy ✓                 │
│ Fit: Regular ✓                │
└───────────────────────────────┘
```

Important:

The retailer does not need to know who "Dad" is.

The label is generated from the agent's context.

---

# 20. "Fits Mom" / Family Context

The UI may support:

```text
✦ FitzYo Match — Dad
```

or:

```text
✦ FitzYo Match — Mom
```

This is optional presentation metadata.

The underlying retailer state should only contain the information necessary to select the product variant.

---

# 21. Product Comparison

Users and agents must be able to compare products.

Example:

```text
              Columbia       Patagonia
Price         $49             $69
Fit           Regular         Relaxed
Material      Polyester       Nylon
Weight        Medium          Light
Navy          ✓               ✓
16.5/34       ✓               ✓
```

WebMCP operation:

```text
compare_products(product_ids)
```

---

# 22. Cart UX

The cart must be inspectable.

Example:

```text
CART

Dad
Performance Polo
Navy / 16.5/34
$49.99

Mom
Linen Dress
Blue / M
$69.99

Subtotal
$119.98
```

WebMCP operation:

```text
get_cart()
```

must return equivalent semantic information.

---

# 23. Cart Modification

The agent must be able to:

```text
add_to_cart()
remove_from_cart()
update_cart_item()
```

The human must immediately see the change.

Example:

```text
Agent:
add_to_cart(prod_123, variant_navy_16_5_34)

        ↓

Cart count: 3 → 4
```

---

# 24. Trip Wardrobe UX

The MVP should support a simple trip-planning presentation.

Example:

```text
HAWAII
May 14–21

DAY 1
Travel

DAY 2
Beach

DAY 3
Hiking

DAY 4
Sightseeing

DAY 5
Beach

DAY 6
Dinner

DAY 7
Travel
```

The retailer does not need to own the trip.

The agent can create the wardrobe requirements.

The retailer's role is to provide products matching those requirements.

---

# 25. Agent Activity Panel

The application SHOULD include an optional agent activity panel.

Example:

```text
┌─────────────────────────────────────────────┐
│ ✦ Agent Activity                            │
│                                             │
│ ✓ Searching men's shirts                    │
│ ✓ Filtering size 16.5/34                   │
│ ✓ Filtering navy / gray                    │
│ ✓ Filtering under $70                      │
│ ✓ 12 matching products                     │
│                                             │
│ Agent connected ●                          │
└─────────────────────────────────────────────┘
```

This panel is particularly important for the hackathon demonstration.

It makes WebMCP activity visible to judges.

---

# 26. Agent Connection Indicator

The application header should show:

```text
✦ Agent Connected ●
```

when WebMCP is available.

Possible states:

```text
Agent Connected ●

Agent Disconnected ○

Agent Working ◐
```

This is purely UX feedback.

---

# 27. WebMCP Tool Surface

The initial WebMCP surface should remain intentionally small.

## Discovery

```text
get_store_info()
get_categories()
```

## Search

```text
search_products(query)
```

## Filtering

```text
filter_products(criteria)
```

## Product

```text
get_product(product_id)
get_variants(product_id)
get_size_guide(product_id)
```

## Fit

```text
find_matching_variants(criteria)
```

## Comparison

```text
compare_products(product_ids)
```

## Cart

```text
get_cart()
add_to_cart(product_id, variant_id)
remove_from_cart(product_id, variant_id)
update_cart_item(...)
```

## UI navigation

```text
focus_product(product_id)
focus_filter(filter_id)
```

---

# 28. WebMCP Tool Requirements

Every tool MUST:

1. Have a clear description.
2. Have a strict input schema.
3. Validate inputs.
4. Return structured output.
5. Operate on application state.
6. Produce visible UI changes when appropriate.
7. Fail with structured errors.

Example:

```json
{
  "error": {
    "code": "VARIANT_UNAVAILABLE",
    "message": "Navy / 16.5/34 is currently unavailable."
  }
}
```

---

# 29. Tool Responses

Tool responses should contain enough semantic information for the agent to continue reasoning.

Example:

```json
{
  "products": [
    {
      "id": "prod_123",
      "name": "Performance Polo",
      "brand": "Columbia",
      "price": 49.99,
      "matching_variants": [
        {
          "id": "var_456",
          "color": "navy",
          "size": "16.5/34",
          "available": true
        }
      ]
    }
  ],
  "total_results": 12
}
```

---

# 30. Agent-Friendly Error Handling

Errors must be semantic.

Bad:

```text
Error 500
```

Good:

```text
NO_MATCHING_PRODUCTS

No products match:

size: 16.5/34
color: navy
brand: Patagonia
max_price: $50
```

The agent can then reason about alternatives.

For example:

> "There are no Patagonia options under $50. There are 4 Columbia options."

---

# 31. Human Override

The human must always be able to modify agent-generated state.

Example:

Agent selects:

```text
Navy
```

User changes it to:

```text
Gray
```

The canonical application state becomes:

```text
color = gray
```

The agent should be able to inspect the updated state.

Human actions always take precedence over stale agent assumptions.

---

# 32. Agent Must Not Bypass User Intent

The retailer MUST require explicit human confirmation for sensitive actions such as:

- final checkout
- payment
- placing an order
- submitting an irreversible order
- entering sensitive customer information

For the hackathon MVP:

```text
Agent can:
✓ search
✓ filter
✓ compare
✓ add to cart

Human must:
✓ review cart
✓ approve checkout
```

---

# 33. Privacy Model

The retailer should NOT require a FitzYo account for the demonstration.

The retailer should not need to know:

```text
Dad
Mom
Child
Family relationships
Private measurements
Private wardrobe
Private preferences
```

Instead, the agent converts private context into shopping constraints.

Example:

```text
PRIVATE:

Dad
shirt = 16.5/34
preferred_color = navy
preferred_brand = Columbia

            ↓

RETAILER SEES:

size = 16.5/34
color = navy
brand = Columbia
```

The retailer should only receive the minimum information required for the current shopping task.

---

# 34. Do Not Build a FitzYo Backend Profile for the MVP

For the hackathon MVP, do NOT create a centralized database of:

```text
family measurements
family preferences
wardrobe
personal style
```

The demo should intentionally demonstrate that these can remain outside the retailer.

The user's desktop agent can access a local file such as:

```text
FAMILY.md
```

or an equivalent private context source.

---

# 35. Local Profile Example

Example private context:

```text
FAMILY.md

## Dad

### Measurements
shirt: 16.5/34
pants: 34x32
shoes: 11

### Preferences
colors: navy, gray, white
brands: Columbia, Patagonia
style: casual

### Wardrobe
3 t-shirts
2 polo shirts
1 linen shirt
2 shorts
1 swim short
1 hiking pant
1 sneaker
1 sandal

## Mom

### Measurements
shirt: M
pants: 8
shoes: 8

### Preferences
colors: blue, white
style: relaxed

### Wardrobe
...
```

The retailer does not access this file.

The desktop agent does.

---

# 36. Agent-Friendly Semantic HTML

Important commerce objects SHOULD have semantic HTML and `data-*` attributes.

Example:

```html
<article
  id="product-prod_123"
  data-product-id="prod_123"
  data-product-type="apparel"
  data-category="mens-shirt"
  data-brand="columbia"
></article>
```

Variant:

```html
<button
  id="variant-prod_123-navy-16_5_34"
  data-product-id="prod_123"
  data-variant-id="var_456"
  data-color="navy"
  data-size="16.5/34"
  data-available="true"
>
  Navy / 16.5 / 34
</button>
```

These attributes complement WebMCP but are NOT a replacement for WebMCP.

---

# 37. Accessibility

All controls must be accessible through standard browser accessibility mechanisms.

Requirements:

- semantic buttons
- labels for inputs
- accessible filter names
- keyboard navigation
- meaningful text alternatives
- visible focus states

Accessibility and agent-friendliness should reinforce each other.

---

# 38. Loading States

Agent-driven operations may take time.

The UI should show:

```text
Searching...
Filtering...
Loading product details...
Checking availability...
```

Avoid making the UI appear frozen.

---

# 39. Empty States

When no products match:

```text
No products found.

Current requirements:

Size: 16.5/34
Color: Navy
Brand: Patagonia
Maximum price: $50

Try:
• Increase budget
• Remove brand restriction
• Try another color
```

The agent can then reason about the alternatives.

---

# 40. Agent-Generated Recommendations

The retailer may display an agent-generated explanation:

```text
✦ FitzYo Recommendation

This shirt matches Dad's requested size,
preferred color, and casual style.

$49.99
```

This information should be clearly identified as agent-generated.

---

# 41. Performance Requirements

Agent-driven operations should feel instantaneous.

Target:

```text
WebMCP request
      ↓
Application state update
      ↓
UI update

< 250ms target
```

External search/API latency may be higher.

The application should not block the entire UI while an agent operation is executing.

---

# 42. State Synchronization

When WebMCP modifies application state:

```text
WebMCP
  ↓
LiveView / Application State
  ↓
Svelte / DOM
```

When the human modifies state:

```text
Human UI
  ↓
Application State
  ↓
WebMCP-readable state
```

Both directions must remain synchronized.

---

# 43. Recommended Architecture

```text
                    ┌──────────────────────┐
                    │   Desktop AI Agent   │
                    │                      │
                    │ Private Context      │
                    │ FAMILY.md            │
                    │ Wardrobe             │
                    │ Preferences          │
                    └──────────┬───────────┘
                               │
                             WebMCP
                               │
                               ▼
┌────────────────────────────────────────────────────┐
│                 RETAIL APPLICATION                 │
│                                                    │
│                    WebMCP Layer                    │
│                         │                          │
│                         ▼                          │
│                 Commerce Actions                   │
│                         │                          │
│                         ▼                          │
│                 Application State                  │
│                         │                          │
│               ┌─────────┴─────────┐                │
│               ↓                   ↓                │
│          Phoenix LiveView      Svelte UI           │
│               │                   │                │
│               └─────────┬─────────┘                │
│                         ↓                          │
│                    Human UI                        │
│                                                    │
│                     Products                       │
│                     Variants                       │
│                     Inventory                      │
│                     Cart                           │
└────────────────────────────────────────────────────┘
```

---

# 44. Recommended Implementation Principle

The WebMCP layer should call application-domain functions.

Example:

```text
WebMCP
   ↓
filter_products(criteria)
   ↓
Catalog.search(criteria)
   ↓
Commerce State
   ↓
LiveView update
```

Do NOT implement:

```text
WebMCP
   ↓
find DOM element
   ↓
simulate click
   ↓
hope UI changes
```

WebMCP should be an application interface, not a browser automation hack.

---

# 45. MVP Acceptance Criteria

The implementation is considered successful when all of the following work.

### Scenario 1 — Search

Agent:

> "Find men's casual shirts."

Result:

- Search state changes.
- Human sees search results.
- Search query is visible.

---

### Scenario 2 — Size

Agent:

> "Only show Dad's 16.5/34."

Result:

- Size filter activates.
- Product results update.
- Human sees active filter.

---

### Scenario 3 — Preference

Agent:

> "Only navy or gray."

Result:

- Color filters activate.
- Product results update.

---

### Scenario 4 — Budget

Agent:

> "Keep it under $70."

Result:

- Price filter activates.
- Results update.

---

### Scenario 5 — Fit

Agent:

> "Find the best available variant for Dad."

Result:

- Agent retrieves product variants.
- Agent identifies matching size/color.
- UI shows matching variant.

---

### Scenario 6 — Comparison

Agent:

> "Compare these three."

Result:

- Comparison view appears.
- Product attributes are shown side-by-side.

---

### Scenario 7 — Cart

Agent:

> "Add the best one to my cart."

Result:

- Correct variant added.
- Cart updates immediately.
- Human sees the item.

---

### Scenario 8 — Human Override

Agent selects:

```text
Navy
```

Human changes:

```text
Gray
```

Result:

- Gray becomes active.
- Agent-readable state reflects Gray.

---

# 46. Hackathon Demo Acceptance Criteria

The ideal final demonstration should support this exact flow:

```text
User:

"We're going to Hawaii for seven days with the family.
Find what we need and don't buy anything we already own."

                    ↓

Desktop Agent reads private context.

                    ↓

Agent determines:
- family members
- sizes
- preferences
- wardrobe gaps

                    ↓

Agent uses WebMCP.

                    ↓

Retailer searches catalog.

                    ↓

Retailer filters products.

                    ↓

Human watches UI update.

                    ↓

Agent finds matching variants.

                    ↓

Agent builds shopping list.

                    ↓

Human changes requirement:

"Nothing over $75."

                    ↓

WebMCP updates filters.

                    ↓

Human says:

"Remove red."

                    ↓

WebMCP updates catalog.

                    ↓

Agent adds selected products to cart.

                    ↓

Human reviews cart.
```

---

# 47. The Critical Demo Moment

The most important visual moment should be:

```text
PRIVATE CONTEXT

Dad
Size: 16.5/34
Colors: Navy, Gray
Brand: Columbia

            ↓
         AI Agent
            ↓
         WebMCP
            ↓

RETAIL WEBSITE

16.5/34 ✓
Navy ✓
Columbia ✓

✦ FitzYo Match
```

The judge should immediately understand:

> **The website did not know who Dad was. The agent brought the relevant context to it.**

---

# 48. Out of Scope for MVP

Do NOT implement:

- payment processing
- real order fulfillment
- retailer accounts
- complex recommendation algorithms
- centralized FitzYo identity database
- social shopping
- loyalty programs
- advertising personalization
- complex inventory management
- production-grade retailer integrations
- automatic purchasing without confirmation

Focus on:

```text
Private Context
       +
AI Agent
       +
WebMCP
       +
Agent-Friendly Retail UI
```

---

# 49. Future Capabilities

The architecture should leave room for:

### Personal Wardrobe

```text
What do I already own?
```

### Travel

```text
Plan my Hawaii wardrobe.
```

### Weather

```text
What should I wear tomorrow?
```

### Calendar

```text
I have a business dinner Friday.
Find something appropriate.
```

### Budget

```text
Keep this trip under $500.
```

### Multi-Retailer Shopping

```text
Find the best options across three stores.
```

### Gift Shopping

```text
Find a birthday gift for Mom based on her preferences.
```

### Fit Intelligence

```text
This brand runs small.
What size should Dad buy?
```

---

# 50. Final Product Principle

The retailer should be designed around one fundamental idea:

> **The website is not the user's personal database. It is an agent-accessible commerce environment.**

The user's personal context belongs to the user.

The retailer owns:

```text
Products
Inventory
Prices
Variants
Availability
```

The agent owns the reasoning.

WebMCP connects them.

```text
             USER
               │
       Private Context
               │
               ▼
         AI AGENT
               │
          WebMCP
               │
               ▼
        RETAIL WEBSITE
               │
       ┌───────┴───────┐
       ↓               ↓
   Products          Actions
       │               │
       └───────┬───────┘
               ↓
             HUMAN
```

**FitzYo's core UX promise:**

> **Your AI knows what fits you. The web doesn't have to.**
