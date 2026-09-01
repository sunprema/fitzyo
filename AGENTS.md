Absolutely. For `AGENTS.md`, I would keep the focus on **product intent, architecture philosophy, user experience, and the role of WebMCP**, rather than implementation details. Your coding agent should understand _why FitzYo exists_ before deciding how to implement it.

Here is a version you can put directly into the project root.

# AGENTS.md

# FitzYo — Agent Context

## 1. What Is FitzYo?

**FitzYo is an AI-native shopping experience where the user's personal context stays with the user, while retailers expose their products and commerce capabilities to AI agents through WebMCP.**

The core idea is:

> **Your AI knows you. The web doesn't have to.**

FitzYo allows a user's AI agent to use private, user-controlled context such as:

- Body measurements
- Clothing sizes
- Fit preferences
- Favorite brands
- Preferred colors
- Style preferences
- Activities and lifestyle
- Existing wardrobe
- Travel plans
- Shopping budget
- Family members and their preferences

The AI agent uses this context to make shopping decisions.

The retailer does **not** need to maintain this personal profile.

Instead:

```text
                 USER'S PRIVATE CONTEXT
                         │
                         ▼
                  ┌─────────────┐
                  │  AI Agent   │
                  │             │
                  │ Reasoning   │
                  │ Planning    │
                  │ Personal    │
                  │ Context     │
                  └──────┬──────┘
                         │
                       WebMCP
                         │
                         ▼
              ┌─────────────────────┐
              │   Retailer Website  │
              │                     │
              │ Products            │
              │ Variants            │
              │ Sizes               │
              │ Inventory           │
              │ Prices              │
              │ Cart                │
              │                     │
              │ WebMCP Tools        │
              └─────────────────────┘
```

The agent supplies the **intent and personal context**.

The retailer supplies the **commerce capabilities and product data**.

WebMCP is the interface between them.

---

# 2. The Problem

Traditional ecommerce assumes that the retailer must know everything about the customer.

A typical shopping experience looks like:

```text
User
  ↓
Search
  ↓
Filters
  ↓
Product pages
  ↓
Size chart
  ↓
Compare
  ↓
Add to cart
  ↓
Checkout
```

The user must manually translate their intent into dozens of UI interactions.

For example:

> "I'm going to Hawaii for seven days with my family. I need clothes for myself and my family, but I don't want to buy things we already own."

Today, the user must manually:

- Research Hawaii weather
- Determine appropriate clothing
- Remember everyone's sizes
- Remember everyone's preferences
- Search retailers
- Filter products
- Check sizes
- Check colors
- Compare products
- Remember what is already in the wardrobe
- Build outfits
- Stay within budget

FitzYo changes this interaction model.

The user should be able to tell their agent:

> "We're going to Hawaii for seven days. Figure out what everyone needs and help me buy only what we're missing."

The agent should reason about the task and use WebMCP-enabled retailers to execute the shopping workflow.

---

# 3. The Core Product Model

FitzYo separates responsibilities between three entities.

## User

Owns:

- Personal information
- Measurements
- Preferences
- Wardrobe
- Family context
- Travel context
- Budget
- Shopping intent

## AI Agent

Owns:

- Reasoning
- Planning
- Personalization
- Product discovery
- Product comparison
- Constraint satisfaction
- Recommendation generation
- Translating user intent into retailer operations

## Retailer

Owns:

- Products
- Product descriptions
- Variants
- Sizes
- Colors
- Prices
- Inventory
- Availability
- Categories
- Cart
- Commerce operations

The retailer should not need to understand the user's entire personal profile.

---

# 4. Why WebMCP Is Fundamental

FitzYo is not simply an ecommerce application with an AI chatbot added to it.

WebMCP is a fundamental part of the architecture.

The retailer website exposes semantic capabilities such as:

```text
search_products()
filter_products()
get_product()
get_variants()
get_size_guide()
find_matching_variants()
compare_products()
get_cart()
add_to_cart()
remove_from_cart()
update_cart_item()
focus_product()
```

The agent interacts with these **semantic commerce operations** rather than attempting to operate the website like a human through clicks.

This distinction is critical.

### Bad approach

```text
Agent
 ↓
Find button
 ↓
Click button
 ↓
Read DOM
 ↓
Click filter
 ↓
Read DOM
 ↓
Click product
 ↓
Read DOM
```

### FitzYo approach

```text
Agent
 ↓
search_products()
 ↓
filter_products()
 ↓
find_matching_variants()
 ↓
compare_products()
 ↓
add_to_cart()
```

The website becomes an **agent-accessible commerce environment**.

---

# 5. Human + Agent Interaction

FitzYo should not create two separate experiences.

There should be:

```text
                ONE APPLICATION STATE
                       │
              ┌────────┴────────┐
              │                 │
           HUMAN             AGENT
              │                 │
              └────────┬────────┘
                       │
                 Shared State
                       │
                       ▼
                 Retail UI
```

The human and agent operate on the same application state.

If the agent filters products:

```text
Agent
  ↓
filter_products(...)
  ↓
Application State
  ↓
UI updates
```

The human immediately sees the filtered products.

If the human changes the filter:

```text
Human
  ↓
UI interaction
  ↓
Application State
  ↓
Agent observes updated state
```

This bidirectional relationship is important.

The agent should never feel like it is operating a hidden application.

---

# 6. The Signature FitzYo Experience

The most important demonstration scenario is:

> **"We're going to Hawaii for seven days. What should my family wear?"**

The agent should be able to combine:

### Private context

Example:

```text
Dad:
  Size: XL
  Waist: 36
  Preferred brands: Patagonia, Columbia
  Colors: Blue, Black
  Avoid: Red
  Style: Casual

Mom:
  Size: M
  Preferred colors: ...

Child:
  Size: Youth L
  ...
```

### Existing wardrobe

```text
Dad:
  3 t-shirts
  2 shorts
  1 swim trunk

Mom:
  ...

Child:
  ...
```

### Trip context

```text
Destination: Hawaii
Duration: 7 days
Activities:
  Beach
  Hiking
  Dinner
  Sightseeing
```

### Retail inventory

Provided through WebMCP:

```text
Products
Variants
Sizes
Colors
Prices
Availability
```

The agent combines all of these inputs.

It should produce something like:

```text
HAWAII — 7 DAY WARDROBE

Dad

Already have:
✓ 3 casual shirts
✓ 2 shorts
✓ 1 swim trunk

Need:
• 2 lightweight shirts
• 1 hiking short
• 1 lightweight dinner shirt

Retailer search:
✓ Blue Columbia shirt — XL
✓ Black Patagonia hiking short — 36
✓ Blue linen shirt — XL

Estimated additional cost: $184
```

The important part is that the retailer does not need to know why the agent selected those products.

The agent owns that reasoning.

---

# 7. FitzYo's "Fit" Concept

The name **FitzYo** represents personalized fit.

Fit should be treated as more than just a size.

A product can expose structured fit information such as:

```text
Size: XL

Chest: 44–46"
Waist: 36–38"
Fit: Relaxed
Length: Regular
Stretch: Medium
Cut: Athletic
```

The user's private profile may contain:

```text
Chest: 45"
Waist: 36"
Preferred fit: Relaxed
```

The agent can reason:

```text
User measurements
        +
Product measurements
        +
Fit preference
        ↓
     FIT MATCH
```

The retailer should expose the information required for this reasoning.

The retailer does not need to permanently store the user's body profile.

---

# 8. "Fits Dad" UX

One of the signature UI concepts should be contextual personalization.

Instead of:

> XL available

the interface can show:

> **Fits Dad ✓**

or:

> **Likely fits Dad**

This information is generated from the user's private context and current agent task.

The retailer itself does not need to know who "Dad" is.

Conceptually:

```text
Retail Product
      +
Private Family Context
      +
Agent Reasoning
      ↓
"Fits Dad"
```

This should feel magical to a human user while remaining technically understandable.

---

# 9. Privacy Model

Privacy is an architectural benefit, but it is not the only product proposition.

The primary proposition is:

> **Your AI knows what fits you. The web doesn't have to.**

FitzYo should minimize the amount of personal information sent to retailers.

For example, the retailer may receive:

```text
size = XL
color = blue
fit = relaxed
```

It does not need to receive:

```text
name
age
body measurements
family relationships
entire wardrobe
travel history
personal preferences
```

unless those details are genuinely required for the current operation.

The general principle is:

> **Share task-relevant constraints, not the user's entire profile.**

Do not build a centralized FitzYo customer-profile backend for the MVP.

The user's personal context should remain outside the retailer application.

---

# 10. Local Personal Context

For the MVP, personal context can be represented using local files.

For example:

```text
FAMILY.md
```

Possible structure:

```markdown
# Family

## Dad

### Measurements

- Shirt: XL
- Waist: 36
- Inseam: 32

### Preferences

- Preferred brands: Patagonia, Columbia
- Preferred colors: Blue, Black
- Avoid: Red
- Preferred fit: Relaxed

## Mom

...

## Child

...
```

Wardrobe can be maintained separately or in the same local context:

```markdown
# Wardrobe

## Dad

- Blue polo
- Black shorts
- Gray t-shirt
- Navy swim trunks

## Mom

...

## Child

...
```

The MVP does not need a sophisticated personal-data backend.

The important architectural concept is:

```text
Private context belongs to the user/agent.
Commerce data belongs to the retailer.
```

---

# 11. Retailer UX Philosophy

The retailer should look like a normal modern ecommerce application.

It should not look like an "AI demo."

Humans should be able to use it normally.

At the same time, every important commerce concept should be semantically accessible to an agent.

For example:

```text
Product
Variant
Size
Color
Price
Availability
Fit
Category
Filter
Cart Item
```

should all have stable identifiers and structured representations.

The UI and WebMCP layer should operate on the same underlying application state.

---

# 12. Semantic Commerce Objects

Do not design WebMCP tools around DOM elements.

Bad:

```text
click_filter_button()
click_product_card()
click_size_dropdown()
```

Good:

```text
filter_products({
  category: "shirts",
  size: "XL",
  color: "blue",
  fit: "relaxed"
})
```

The WebMCP layer should operate on domain objects and domain operations.

The implementation should look conceptually like:

```text
WebMCP Tool
     ↓
Domain Operation
     ↓
Application State
     ↓
LiveView/Svelte UI
```

not:

```text
WebMCP Tool
     ↓
DOM manipulation
```

---

# 13. Important Product Capabilities

The MVP retailer should support:

### Discovery

- Store information
- Categories
- Product search

### Filtering

- Category
- Size
- Color
- Brand
- Price
- Fit
- Activity

### Product information

- Product details
- Variants
- Sizes
- Size guide
- Availability
- Fit information

### Personalization

- Matching variants to user constraints
- "Fits Dad"
- Family contextual labels

### Comparison

- Compare multiple products

### Cart

- View cart
- Add item
- Remove item
- Update quantity/variant

### UI navigation

- Focus product
- Focus filter

---

# 14. Agent-Friendly State

The application should have one canonical state model.

Conceptually:

```text
ApplicationState
├── searchQuery
├── category
├── filters
├── results
├── selectedProduct
├── selectedVariant
├── comparisonProducts
└── cart
```

WebMCP operations modify this state.

The UI renders this state.

The agent can inspect this state through appropriate read-only tools.

Avoid maintaining separate "agent state" and "human state."

---

# 15. Agent Activity Should Be Visible

For the hackathon/demo, the user should be able to see what the agent is doing.

For example:

```text
FITZYO AGENT

✓ Read family preferences
✓ Checked existing wardrobe
✓ Created Hawaii wardrobe plan
✓ Searching retailer
✓ Filtering for Dad — XL
✓ Filtering for blue / black
✓ Checking available variants
✓ Comparing 3 shirts
✓ Added 2 items to cart
```

This is not intended to expose internal chain-of-thought.

It is a high-level action/status log showing **what operations the agent performed**.

The user should remain in control.

---

# 16. Human Override

The human always has the final say.

The agent can:

- Search
- Filter
- Inspect
- Compare
- Recommend
- Add items to cart

The agent should not automatically:

- Complete payment
- Place an irreversible order
- Make high-impact purchases without confirmation

The desired interaction is:

```text
Agent recommends
      ↓
Human reviews
      ↓
Human modifies if desired
      ↓
Human confirms
```

---

# 17. What FitzYo Is NOT

Do not turn FitzYo into:

- A traditional ecommerce marketplace
- A retailer CRM
- A centralized customer-profile database
- A generic AI chatbot
- A recommendation chatbot sitting beside an ecommerce website
- A browser automation framework
- A DOM-clicking agent
- A payment platform
- A social shopping network

The product is specifically about:

> **Personal AI context + agent-native commerce interfaces.**

---

# 18. MVP Scope

The MVP should prioritize the WebMCP experience over production ecommerce complexity.

### Must Have

- Retail product catalog
- Product search
- Structured filters
- Product variants
- Size/fit information
- Cart
- WebMCP tools
- Shared human/agent state
- Local family context
- Agent-driven shopping workflow
- "Fits [family member]" contextual UI
- Agent activity panel

### Not Required

- Real payment processing
- Real fulfillment
- Complex authentication
- Real retailer integrations
- Loyalty programs
- Advertising
- Production-grade inventory management
- Multi-retailer federation
- Automatic purchasing

The MVP should be a convincing **agent-native retail prototype**, not a complete ecommerce platform.

---

# 19. Technical Philosophy

FitzYo should favor simple, explicit architecture.

Preferred stack:

```text
Elixir
Phoenix
Phoenix LiveView
Ash Framework
Svelte where complex interactive UI is useful
WebMCP
```

Use the existing Phoenix application state as the source of truth.

Avoid introducing infrastructure unless it directly improves the demo or product architecture.

Prefer:

```text
Domain model
    ↓
Application state
    ↓
WebMCP
    ↓
UI
```

over unnecessary layers.

---

# 20. Architecture

The conceptual architecture is:

```text
┌──────────────────────────────────────────────┐
│              USER ENVIRONMENT                │
│                                              │
│  Family Context                              │
│  FAMILY.md                                   │
│  Wardrobe                                    │
│  Preferences                                 │
│  Travel Plans                                │
│                                              │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │    AI AGENT     │
              │                 │
              │ Understand      │
              │ Plan            │
              │ Reason          │
              │ Personalize     │
              └────────┬────────┘
                       │
                       │ WebMCP
                       ▼
┌──────────────────────────────────────────────┐
│              RETAILER WEBSITE                │
│                                              │
│  ┌────────────────────────────────────────┐  │
│  │           WebMCP Layer                 │  │
│  │                                        │  │
│  │ search_products                       │  │
│  │ filter_products                       │  │
│  │ get_product                           │  │
│  │ get_variants                          │  │
│  │ find_matching_variants                │  │
│  │ compare_products                      │  │
│  │ get_cart                              │  │
│  │ add_to_cart                            │  │
│  └──────────────────┬─────────────────────┘  │
│                     │                        │
│                     ▼                        │
│             Commerce Domain                  │
│                     │                        │
│                     ▼                        │
│              Application State              │
│                     │                        │
│             ┌───────┴────────┐               │
│             ▼                ▼               │
│         LiveView           Svelte            │
│             │                │               │
│             └───────┬────────┘               │
│                     ▼                        │
│                HUMAN UI                      │
│                                              │
└──────────────────────────────────────────────┘
```

---

# 21. The Most Important Design Rule

### WebMCP tools must represent what the user wants to accomplish, not how the UI happens to implement it.

For example:

```text
filter_products()
```

is good.

```text
click_checkbox_17()
```

is fundamentally wrong.

Likewise:

```text
add_to_cart(product_id, variant_id)
```

is good.

```text
click_add_button_at_coordinates()
```

is wrong.

This principle should guide all WebMCP API design.

---

# 22. Demo Story

The primary demo should feel like this:

### Step 1

User opens FitzYo.

### Step 2

User's agent has access to the user's private family context.

### Step 3

User says:

> "We're going to Hawaii for seven days. Plan what everyone should wear and find what we're missing."

### Step 4

Agent reasons over:

```text
Family
+
Wardrobe
+
Trip
+
Activities
+
Weather/context
+
Budget
```

### Step 5

Agent uses WebMCP to interact with the retailer.

```text
search_products()
filter_products()
find_matching_variants()
compare_products()
```

### Step 6

The retailer UI visibly changes.

The user sees:

```text
Fits Dad ✓
Fits Mom ✓
Fits Child ✓
```

### Step 7

Agent builds a recommendation.

### Step 8

Agent adds selected items to the cart.

### Step 9

User can modify the constraints:

> "Keep it under $500."

or:

> "Dad doesn't need another shirt."

or:

> "No red."

The agent responds by modifying the same retailer state through WebMCP.

### Step 10

Human reviews the final cart.

The human remains in control of purchase.

---

# 23. The Fundamental Value Proposition

Traditional ecommerce:

```text
Retailer knows products.
User manually figures out what to buy.
```

FitzYo:

```text
User's AI knows the user.
Retailer knows products.
WebMCP connects the two.
```

This creates a new interaction model:

```text
USER INTENT
     ↓
AI REASONING
     ↓
WEBMCP
     ↓
COMMERCE CAPABILITIES
     ↓
LIVE RETAIL UI
     ↓
HUMAN APPROVAL
```

---

# 24. Long-Term Vision

The MVP is apparel, but the underlying model is broader.

Eventually FitzYo could become a personal commerce agent that works across:

- Apparel
- Shoes
- Travel
- Outdoor equipment
- Home goods
- Gifts
- Family shopping
- Event preparation
- Seasonal shopping

The user's personal context could include:

```text
Identity
Measurements
Preferences
Wardrobe
Calendar
Travel
Activities
Budget
Past purchases
Wishlist
Household
```

The agent could then perform tasks such as:

> "I'm going to Colorado next month."

> "My son needs clothes for soccer season."

> "We have a wedding in October."

> "Find gifts for my parents."

> "Prepare our family for a week at the beach."

The same architecture applies:

```text
Personal Context
       +
User Intent
       +
AI Reasoning
       +
WebMCP-enabled Commerce
```

---

# 25. Guiding Principle for Coding Agents

When implementing FitzYo, always ask:

> **Does this feature make the interaction between a human, their AI agent, and the web meaningfully better?**

Prefer features that strengthen this relationship.

Avoid building conventional ecommerce features simply because they are common in ecommerce applications.

The objective is not to build another online clothing store.

The objective is to demonstrate what happens when:

> **The user's AI can directly interact with a website through meaningful, structured capabilities while the human remains in control.**

---

# 26. Final Product Definition

FitzYo is:

> **An agent-native shopping experience where users bring their own personal context and AI, while retailers expose structured commerce capabilities through WebMCP.**

The three parties have clear ownership:

```text
USER
Owns personal context.

AI AGENT
Owns reasoning and planning.

RETAILER
Owns products and commerce.

WEBMCP
Connects them.
```

The core promise is:

> **Your AI knows what fits you. The web doesn't have to.**

This is the version I'd give the coding agent **before** the more technical `RETAIL_UX_REQUIREMENTS.md` and `WEBMCP_SPEC.md`. It establishes the _why_ first, then those documents can define the _how_.

## Document References

- [Retail UX Requirements](@docs/RETAIL_UX_REQUIREMENTS.md)
- [WEB MCP Spec](@docs/WEBMCP_SPEC.md)
