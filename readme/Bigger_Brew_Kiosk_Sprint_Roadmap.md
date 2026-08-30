# Bigger Brew Kiosk --- Sprint Roadmap

**Project:** Bigger Brew Barista / Customer Ordering Kiosk\
**Document purpose:** Living sprint plan. Update this file at the end of
each development session so the next session can continue from the
latest status.

------------------------------------------------------------------------

## Current Overall Status

**Current sprint:** K17.2 — Centralized Pricing Authority\
**Next planned sprint:** K17.3 — Product / Add-on Rule Finalization\
**Overall status:** K17.2 source changes are complete. Product-level prices now survive catalog parsing and flow through the kiosk adapter; kiosk pricing no longer maintains a duplicate commercial price table. Static catalog consistency checks pass. Local Flutter verification is pending in the user's development environment.

### Core principle

The kiosk should be a separate customer-ordering experience, while
continuing to use the existing Bigger Brew recipe/menu system.

``` text
Existing App
│
├── Home
├── Menu / RecipePage
├── Recipe Editor
├── Recent Drinks
├── Favorites
└── Barista Mode
        │
        ▼
NEW CUSTOMER KIOSK
│
├── Kiosk Home
├── Categories
│   ├── Milk Tea
│   ├── Fruit Tea
│   ├── Coffee
│   ├── Chocolate
│   ├── Rice Meals
│   ├── Burgers
│   ├── Merienda
│   ├── Accessories / Other Products
│   └── Add-ons
├── Product Selection
├── Customization
├── Cart
├── Order Review
├── Order Number
└── Order Complete
```

------------------------------------------------------------------------

# Sprint K1 --- Kiosk Foundation

**Status: COMPLETE — 2026-08-15**

### Goal

Create the basic customer-facing kiosk architecture without disturbing
the existing app.

### Files

``` text
lib/features/kiosk/
├── kiosk_page.dart
├── models/
│   └── kiosk_models.dart
├── data/
│   └── kiosk_menu_data.dart
└── pages/
    ├── kiosk_home_page.dart
    ├── kiosk_category_page.dart
    └── kiosk_cart_page.dart
```

### Included

-   Kiosk home
-   Category grid
-   Product cards
-   Cart model
-   Add/remove items
-   Quantity controls
-   Rice Meals
-   Rice Meal add-ons

### Rice Meals

  Item                         Price
  -------------------------- -------
  Hungarian Sausage w/ Egg       ₱85
  Liempo                         ₱85
  Lechon Kawali                  ₱85
  Sisig                          ₱85
  Fried Chicken                  ₱80
  Bacon & Egg                    ₱80
  Spam & Egg                     ₱80
  Burger Steak                   ₱70
  Chicken Pastil                 ₱70

### Rice Meal Add-ons

  Add-on              Price
  ----------------- -------
  Extra Rice            ₱20
  Garlic Mayo Dip       ₱10
  Egg                   ₱15

### Important

K1 is intentionally isolated from `RecipePage` and `BaristaModePage`.

------------------------------------------------------------------------

# Sprint K2 --- Connect the Existing Menu

**Status: Planned — NEXT**

### Goal

Make the kiosk read from the existing application menu/recipe data
instead of maintaining duplicate menu information.

### Connect

-   Milk Tea
-   Fruit Tea
-   Coffee
-   Chocolate
-   Burgers
-   Merienda
-   Rice Meals
-   Add-ons where applicable
-   Accessories / Other Products as a shared product type

### Architecture target

``` text
MenuRepository / RecipeRepository
              │
              ▼
        Existing Models
              │
              ├───────────────┐
              ▼               ▼
         RecipePage       Kiosk
                            │
                            ▼
                       KioskProduct
```

### K2 implementation notes

K2 has not been applied to the clean K1 restart baseline yet. The earlier
K2 work recorded in previous sessions is preserved as historical context,
but the current working baseline is the standalone `bigger_brew_kiosk` K1
project. K2 will be re-applied from this clean foundation.

### Why this sprint comes first

We should avoid having:

``` text
Recipe price = ₱45
Kiosk price  = ₱50
```

or duplicate product definitions that later need to be synchronized
manually.

------------------------------------------------------------------------

# Sprint K3 --- Product Customization

**Status: Next**

Build category-aware customization.

## Drinks

Sizes:

-   12oz
-   22oz
-   1 Liter

Customer-facing size names may also be:

-   Regular
-   Go Big
-   Go Bigger

The relationship between size name, volume, price, and recipe quantity
should be centralized.

Possible drink options:

-   Size
-   Flavor
-   Sugar
-   Ice
-   Add-ons

Only options applicable to the selected recipe should be shown.

## Rice Meals

``` text
Base meal
+
Extra Rice
+
Garlic Mayo Dip
+
Egg
```

No drink-size selector.

## Burgers

``` text
Burger
+
Applicable add-ons
+
Quantity
```

## Merienda

``` text
Item
+
Applicable add-ons
+
Quantity
```

------------------------------------------------------------------------

# Sprint K4 --- Cart & Checkout

**Status: Planned**

Expand the current cart into a complete order review.

### Cart must support

-   Add
-   Remove
-   Increase quantity
-   Decrease quantity
-   Clear order
-   Show selected options
-   Show item subtotal
-   Show order total

Example:

``` text
YOUR ORDER

Hungarian Sausage w/ Egg
+ Extra Rice
+ Egg

Qty 2
₱220

----------------

Classic Milk Tea
22oz

Qty 1
₱45

----------------

TOTAL
₱265
```

Add a clear:

`REVIEW ORDER`

action before final submission.

------------------------------------------------------------------------

# Sprint K5 --- Order Confirmation

**Status: Planned**

After checkout:

``` text
ORDER CONFIRMED

Order #1042

Please wait for your order
to be prepared.

[ DONE ]
```

### Order numbering

Example:

``` text
1041
1042
1043
```

Later decide whether numbering resets daily.

------------------------------------------------------------------------

# Sprint K6 --- Order Persistence

**Status: Planned**

Store kiosk orders locally.

Target structure:

``` text
Order
├── orderNumber
├── date/time
├── items
├── options
├── quantities
├── total
└── status
```

Statuses:

-   Pending
-   Preparing
-   Ready
-   Completed
-   Cancelled

This becomes the foundation for staff order management.

------------------------------------------------------------------------

# Sprint K7 --- Recent Orders / Order History

**Status: Planned**

Keep kiosk order history separate from the existing **Recent Drinks**
feature.

Use:

`Recent Orders`

rather than:

`Recent Drinks`

Example:

``` text
ORDER #1042
2 items
₱265
Today • 8:42 PM

[ VIEW ]
```

------------------------------------------------------------------------

# Sprint K8 --- Kiosk Order Management

**Status: Planned**

Create a staff-facing order management screen.

Example:

``` text
ORDERS

┌──────────────────────────┐
│ #1042                    │
│ Hungarian Sausage + Egg │
│ Classic Milk Tea        │
│ ₱265                    │
│                          │
│ [ PREPARING ]            │
└──────────────────────────┘
```

Order progression:

``` text
Pending
   ↓
Preparing
   ↓
Ready
   ↓
Completed
```

This should eventually integrate with the existing Barista Mode concept.

------------------------------------------------------------------------

# Sprint K9 --- Kiosk UX / Visual Polish

**Status: Planned**

Optimize the customer-facing interface for touchscreen use.

### Design goals

-   Large buttons
-   Large prices
-   Large product names
-   Large category cards
-   Large cart button
-   Large checkout button
-   Minimal text entry
-   Fast navigation

### Bigger Brew visual language

Use:

-   Bigger Brew gold
-   Dark brown / black
-   Cream / light background
-   Bigger Brew logo
-   Large readable typography

The kiosk should be more visual and touch-friendly than the internal
recipe/admin pages.

------------------------------------------------------------------------

# Sprint K10 --- Kiosk Navigation & Safety

**Status: Planned**

### Idle timeout

Example:

``` text
Customer starts order
       ↓
No activity
       ↓
Timeout
       ↓
Return to Kiosk Home
```

Automatically clear abandoned carts.

### Back navigation

Prevent customers from accidentally leaving the kiosk flow.

### Customer isolation

A new customer should always start with a clean state.

------------------------------------------------------------------------

# Sprint K11 --- Receipt / Order Ticket

**Status: Planned**

Create printable order output.

Example:

``` text
        BIGGER BREW

        ORDER #1042
        08/14/2026  8:42 PM

2 × Hungarian Sausage w/ Egg
    + Extra Rice
    + Egg

1 × Classic Milk Tea
    22oz

------------------------
TOTAL             ₱265
------------------------

       THANK YOU!
```

Later support thermal printers if required.

------------------------------------------------------------------------

# Sprint K12 --- Production / Store Mode

**Status: Planned**

### Kiosk mode

Application opens directly into:

``` text
KIOSK HOME
```

rather than internal recipe/admin screens.

### Staff exit

Use a protected staff gesture or PIN.

Possible flow:

``` text
5 taps on logo
       ↓
PIN
       ↓
Staff Mode
```

This prevents customers from accessing:

-   Recipe Editor
-   Barista configuration
-   Internal tools
-   Other administrative pages

------------------------------------------------------------------------

# Sprint K13 --- Testing

**Status: Planned**

Create dedicated kiosk tests.

### Product tests

-   Product displays correctly
-   Correct price
-   Correct add-on price
-   Quantity handling

### Cart tests

-   Add
-   Remove
-   Increase
-   Decrease
-   Total calculation

### Drink tests

-   12oz
-   22oz
-   1L
-   Correct recipe/price mapping

### Checkout tests

-   Order number
-   Order total
-   Order persistence
-   Order status

### Reset tests

-   Idle timeout
-   Abandoned cart
-   New customer starts clean

------------------------------------------------------------------------

# Sprint K14 --- APK / Deployment

**Status: Planned**

Final validation:

``` bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then test the APK on the actual kiosk/tablet hardware.

------------------------------------------------------------------------

# Recommended Development Order

``` text
K1  Foundation
 ↓
K2  Existing Menu Integration
 ↓
K3  Product Customization
 ↓
K4  Cart & Checkout
 ↓
K5  Order Confirmation
 ↓
K6  Order Persistence
 ↓
K7  Recent Orders
 ↓
K8  Staff Order Management
 ↓
K9  UX / Visual Polish
 ↓
K10 Kiosk Safety
 ↓
K11 Receipt / Order Ticket
 ↓
K12 Production / Store Mode
 ↓
K13 Testing
 ↓
K14 APK / Deployment
```

------------------------------------------------------------------------

# Session Handoff / Change Log

Use this section at the end of every development session.

## Current Session

**Date:** 2026-08-15

### Completed

- Restarted Sprint K1 from a clean kiosk baseline.
- Created the standalone `bigger_brew_kiosk` Flutter project structure.
- Created `lib/features/kiosk/kiosk_page.dart`.
- Created the K1 kiosk models and temporary kiosk menu data.
- Created `kiosk_home_page.dart`, `kiosk_category_page.dart`, and `kiosk_cart_page.dart`.
- Added the K1 customer-facing category structure.
- Added Rice Meals and Rice Meal add-ons.
- Added basic product selection and cart flow.
- Confirmed `main.dart` launches `KioskHomePage` directly, so no `home_page.dart` is required for K1.
- Kept the kiosk isolated from `RecipePage`, `BaristaModePage`, and other existing app screens.

### K1 completion status

K1 is marked **COMPLETE** as the clean foundation milestone. The source-level
structure and entry point are in place. Full local `flutter analyze` and
`flutter test` verification has not been confirmed in this session yet.

### Current blocker / known limitation

- K1 still uses temporary kiosk menu data by design.
- Drink/menu integration and centralized pricing are deferred to K2/K3.
- Local Flutter CLI verification should be performed before production use.

### Next session

**Start Sprint K2 — Connect the Existing Menu.**

Re-apply menu integration from the clean K1 baseline. Inspect the existing
menu/recipe models and repositories, then replace duplicated drink menu data
with adapters/mapping to the existing source of truth.

### Files established in K1

```text
lib/
├── main.dart
└── features/kiosk/
    ├── kiosk_page.dart
    ├── data/
    │   └── kiosk_menu_data.dart
    ├── models/
    │   └── kiosk_models.dart
    └── pages/
        ├── kiosk_home_page.dart
        ├── kiosk_category_page.dart
        └── kiosk_cart_page.dart

test/
kiosk/
└── kiosk_k1_test.dart
```

### Do not change yet

- Existing `RecipePage`
- Existing `BaristaModePage`
- Existing Recent Drinks page
- Existing recipe editor


---

---

# Current Session — 2026-08-15

## Sprint K2 Progress

### Completed

- Received and inspected the original `bigger_brew_barista.zip` source.
- Confirmed `MenuRepository.categories` is the existing drink menu source.
- Confirmed the source hierarchy: `MenuCategory` → `MenuGroup` → `MenuItem`.
- Added a K2 kiosk adapter using the existing Barista project as a local package dependency.
- Mapped existing source categories: Milk Tea, Coffee, Matcha, Frappe, Fruit Tea, Fruity Soda, and Slushies.
- Preserved menu item ID, title, recipe path, image path, and group title.
- Changed kiosk product pricing to nullable so K2 does not invent drink prices.
- Kept K1 Rice Meals and Rice Meal add-ons.
- Added `accessory` as a kiosk product type and kept Accessories unpopulated until actual products/prices are supplied.
- Added K2 integration tests.

### K2 Files Changed / Added

```text
lib/features/kiosk/models/kiosk_models.dart
lib/features/kiosk/data/kiosk_menu_data.dart
lib/features/kiosk/pages/kiosk_category_page.dart
test/kiosk/kiosk_k2_test.dart
```

### Setup Requirement

Because `bigger_brew_kiosk` and `bigger_brew_barista` are separate Flutter projects, the kiosk needs a local path dependency to the Barista project, for example:

```yaml
dependencies:
  bigger_brew_barista:
    path: ../bigger_brew_barista
```

### Verification

Flutter CLI verification has not been run in this environment. Run `flutter pub get`, `flutter analyze`, and the K2 tests locally after adding the path dependency.

### Next Step

Finish local K2 verification and fix any compile/test issues. Once green, mark K2 complete and begin K3 — Product Customization and centralized pricing/sizes.

# Decision Log

  -----------------------------------------------------------------------
  Date                                Decision
  ----------------------------------- -----------------------------------
  2026-08-14                          Kiosk will be developed as a
                                      separate customer-facing feature.

  2026-08-14                          Existing recipe/menu system should
                                      become the source of truth.

  2026-08-14                          Rice Meals are included in the
                                      kiosk.

  2026-08-14                          Rice Meal add-ons: Extra Rice ₱20,
                                      Garlic Mayo Dip ₱10, Egg ₱15.

  2026-08-14                          Drink sizes include 12oz, 22oz, and
                                      1 Liter.

  2026-08-14                          Kiosk Recent Orders is separate
                                      from existing Recent Drinks.

  2026-08-14                          Kiosk and RecipePage/BaristaMode
                                      remain separate during early

| 2026-08-15 | K2 uses `MenuRepository.categories` as the kiosk drink-menu source of truth. |
| 2026-08-15 | K2 does not invent existing drink prices because the current menu/recipe models do not contain selling prices. |
| 2026-08-15 | Accessories use the same `KioskProduct` / cart architecture but remain unpopulated until actual products and prices are supplied. |
                                      development.
  -----------------------------------------------------------------------


2026-08-15                          K1 was restarted from a clean standalone
                                      `bigger_brew_kiosk` baseline; prior K2
                                      implementation notes are historical and
                                      are not assumed to exist in this baseline.

2026-08-15                          K1 is marked complete after establishing
                                      the kiosk foundation and direct
                                      `KioskHomePage` application entry point.

------------------------------------------------------------------------

# Working Rule

At the end of each kiosk development session:

1.  Update **Current Session**.
2.  Update sprint status.
3.  Record completed files/features.
4.  Record blockers.
5.  Record decisions that affect architecture.
6.  Set the exact **Next Session** task.
7.  Do not remove previous decisions unless explicitly superseded.

This file is the single living roadmap for the Bigger Brew Kiosk
project.


# Product Unification Plan — Shared Product Catalog

**Status:** U1 COMPLETE — Product Contract defined; U2 NEXT  
**Purpose:** Establish a common commercial product definition that can be used by the Kiosk, Recipe Guide, future POS/order management, inventory, and reporting without making the applications dependent on each other.

## Core decision

The **Recipe Guide and Kiosk remain completely separate applications**.

They must not depend on each other's Flutter source code or repositories.

Instead, both applications will consume a future **shared Product Catalog contract/data source**.

```text
                    SHARED PRODUCT CATALOG
                    Commercial Products
                           │
             ┌─────────────┼─────────────┐
             ▼             ▼             ▼
       Recipe Guide      Kiosk        Future POS
             │             │             │
             ▼             ▼             ▼
         Recipes        Orders       Inventory
```

## What is unified

The following should eventually have one common identity:

- Product ID
- Product name
- Product category
- Product type
- Customer-facing description
- Image/reference
- Active/inactive status
- Availability
- Variants
- Sizes
- Selling prices
- Add-ons/options
- SKU where applicable

## What stays application-specific

### Recipe Guide owns

- Ingredients
- Recipe quantities
- Preparation steps
- Barista instructions
- Recipe notes
- Recipe editing
- Barista Mode
- Recipe history

### Kiosk owns

- Customer ordering UI
- Cart
- Order flow
- Customer customization UI
- Kiosk session
- Checkout
- Order confirmation

### Future POS / Inventory may own

- Stock
- Purchasing
- Supplier information
- Cost
- Inventory movements
- Sales reporting

The shared Product Catalog should not contain barista instructions or inventory implementation details unless a later requirement explicitly adds them.

---

# Unified Product Model

The future shared product identity should be centered around a stable `productId`.

```text
Product
├── productId              ← stable identity
├── name
├── categoryId
├── productType
├── description
├── image
├── active
├── available
├── variants[]
├── sizes[]
├── prices[]
├── options[]
└── sku
```

### Product types

Start with:

```text
drink
food
accessory
addOn
```

This is intentionally broader than the current kiosk category enum.

## Category vs Product Type

Do not use category and type interchangeably.

Example:

```text
Product:
    Dark Chocolate

productType:
    drink

category:
    Milk Tea
```

Another:

```text
Product:
    Hungarian Sausage w/ Egg

productType:
    food

category:
    Rice Meals
```

Another:

```text
Product:
    Bigger Brew Tumbler

productType:
    accessory

category:
    Accessories
```

This lets the same product model support future categories without changing the core architecture.

---

# Stable Product IDs

Product IDs must never depend on display names.

Good:

```text
dark_chocolate
hungarian_sausage_egg
bigger_brew_tumbler
```

Avoid:

```text
"Dark Chocolate"
"Hungarian Sausage w/ Egg"
```

The display name can change without breaking orders, recipes, or historical data.

---

# Variants and Sizes

Products should support optional variants.

```text
Product
   │
   ├── Variant
   │     ├── id
   │     ├── name
   │     └── price
   │
   └── Size
         ├── id
         ├── name
         ├── volume
         └── price
```

For drinks:

```text
Regular
12oz

Go Big
22oz

Go Bigger
1 Liter
```

The exact prices will be defined during K3.

Accessories can instead use variants:

```text
Tumbler
├── Black
├── Cream
└── Gold
```

Products that need neither sizes nor variants simply leave those collections empty.

---

# Product Options / Add-ons

Keep options separate from variants.

```text
Product
   │
   └── options[]
```

Example:

```text
Rice Meal
├── Extra Rice
├── Garlic Mayo Dip
└── Egg
```

A drink could later have:

```text
Drink
├── Pearl
├── Cream Cheese
└── Extra Syrup
```

Options should have their own stable IDs and prices.

---

# Product ↔ Recipe Relationship

The kiosk must not import or depend on the Recipe Guide's recipe classes.

Instead, the shared product identity can optionally contain a **recipe reference**:

```text
Product
├── productId
├── name
└── recipeRef
      └── recipeId
```

Example:

```text
productId:
dark_chocolate

recipeRef:
dark_chocolate
```

This is only an identifier/reference.

The Kiosk does not load the recipe.

The Recipe Guide can use the same product identity to locate its own recipe.

```text
                    Product
                productId = X
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
   Recipe Guide                  Kiosk
   recipeId = X                productId = X
   ingredients                 price
   preparation                 sizes
   barista steps               options
```

This preserves complete application separation.

---

# Recommended Long-Term Data Structure

Eventually use a neutral format/data source rather than sharing Flutter model classes.

For example:

```text
shared product catalog
│
├── products
│   ├── drinks
│   ├── food
│   ├── accessories
│   └── add-ons
│
├── categories
├── variants
├── sizes
├── prices
└── options
```

The actual implementation can later be:

```text
Phase A
Local JSON / SQLite
        ↓
Phase B
Shared local package / generated model
        ↓
Phase C
Central API / database
```

Do not commit to a backend yet. First establish the data contract.

---

# Migration Strategy

Do not rewrite the Recipe Guide immediately.

### Phase U1 — Define Product Contract

Create the neutral product schema and stable IDs.

### Phase U2 — Build Product Catalog

Populate the catalog with the existing commercial menu.

### Phase U3 — Kiosk Adapter

Kiosk reads the product catalog and converts products into its own UI model.

```text
Product Catalog
      ↓
KioskProduct
```

### Phase U4 — Recipe Guide Adapter

Recipe Guide maps its recipes to the same product IDs.

```text
Product Catalog
      ↓
Recipe / RecipeReference
```

### Phase U5 — Future Systems

Later:

```text
Product Catalog
      ├── Kiosk
      ├── Recipe Guide
      ├── POS
      ├── Inventory
      └── Reports
```

---

# Important Rule

**Never make this:**

```text
Kiosk
  ↓
Recipe Guide Flutter package
  ↓
RecipeRepository
```

And never make this:

```text
Recipe Guide
  ↓
Kiosk Flutter package
```

Instead:

```text
             Product Catalog
              /      |      \
             /       |       \
        Recipe      Kiosk     POS
         Guide       App      App
```

Each application owns its implementation.

---

# Product Unification Sprint Sequence

These should become a separate architectural track before deep K2/K3 work.

```text
U1  Product Contract
 ↓
U2  Product Catalog
 ↓
U3  Product IDs / Categories
 ↓
U4  Sizes / Variants / Options
 ↓
U5  Recipe References
 ↓
U6  Kiosk Adapter
 ↓
U7  Recipe Guide Adapter
 ↓
U8  Validation / Migration
```

## Relationship to Kiosk Sprints

```text
K1  Kiosk Foundation             ✅
       │
       ▼
U1  Shared Product Contract      NEXT ARCHITECTURE STEP
       │
       ▼
U2  Product Catalog
       │
       ├───────────────┐
       ▼               ▼
K2  Menu Catalog     Recipe Guide Mapping
       │
       ▼
K3  Sizes / Pricing / Customization
       │
       ▼
K4  Cart / Checkout
```

This allows us to unify the **commercial product identity** without unifying the applications themselves.

---

# Product Unification Decision Log

| Date | Decision |
|---|---|
| 2026-08-15 | Kiosk and Recipe Guide are completely separate applications. |
| 2026-08-15 | Neither application may depend on the other's Flutter source code. |
| 2026-08-15 | A future shared Product Catalog will provide common commercial product identity. |
| 2026-08-15 | Stable `productId` is the primary cross-application identity. |
| 2026-08-15 | Product type and category are separate concepts. |
| 2026-08-15 | Recipe instructions remain owned by Recipe Guide. |
| 2026-08-15 | Ordering remains owned by Kiosk. |
| 2026-08-15 | Inventory remains a future POS/inventory concern. |
| 2026-08-15 | Kiosk must not import `RecipeRepository` from the Recipe Guide. |
| 2026-08-15 | U1 Product Contract defined as a neutral JSON-based contract; no Flutter application dependency is introduced. |
| 2026-08-15 | Stable `productId` is the cross-application product identity. |
| 2026-08-15 | Product type, category, sizes, variants, and options are separate concepts in the contract. |
| 2026-08-15 | U1 does not establish commercial selling prices for existing products; pricing remains a later implementation step. |

| 2026-08-15 | Product Catalog should use a neutral data contract rather than shared Flutter application code. |


## Latest Session Update — 2026-08-15

### Product Unification U1 — COMPLETE

Completed:
- Defined neutral Product Catalog contract.
- Defined stable `productId`.
- Defined `productType`: drink, food, accessory, addOn.
- Separated category from product type.
- Defined sizes, variants, and options.
- Defined optional `recipeRef` as an identifier only.
- Confirmed no Kiosk → Recipe Guide Flutter dependency.
- Created `product_catalog.schema.json`.
- Created `product_catalog.example.json`.
- Created U1 documentation.

Files:
- `schema/product_catalog.schema.json`
- `examples/product_catalog.example.json`
- `README.md`

Next:
**U2 — Build/populate the Product Catalog.**

U2 should use the actual commercial menu/product list, but must not import Recipe Guide application code.


## Latest Session Update — 2026-08-15

### Product Unification U2 — COMPLETE

Completed:
- Populated the neutral Product Catalog from the actual Bigger Brew Barista `MenuRepository`.
- Added 65 existing drink products.
- Added the 9 K1 Rice Meals.
- Added the 3 K1 Rice Meal add-on products.
- Added category definitions for Milk Tea, Coffee, Matcha, Frappe, Fruit Tea, Fruity Soda, Slushies, Rice Meals, Burgers, Merienda, Accessories, and Add-ons.
- Added stable product ID registry.
- Kept Burgers, Merienda, and Accessories empty until actual commercial products/prices are supplied.
- Kept drink pricing unset because the source menu does not provide selling prices.

Files:
- `catalog/product_catalog.v2.json`
- `catalog/product_id_registry.json`
- `catalog/catalog_summary.json`
- `schema/product_catalog.schema.json`
- `README.md`

Catalog total: 77 products.
- 65 drinks
- 9 Rice Meals
- 3 add-ons

Next:
**U3 — Product ID / Category Validation.**


---

# Current Session — 2026-08-17

## Product / Catalog Unification Checkpoint

### Completed

- Product Catalog is now part of the kiosk codebase through the local neutral catalog models/repository and kiosk adapter.
- Kiosk product identity is sourced from the Product Catalog rather than maintaining a second commercial product definition.
- Product catalog models support categories, product types, sizes, variants, options, availability, SKU, recipe references, and kitchen-preparation metadata.
- `kitchenPrepared` is supported at both product and option/add-on level.
- Kiosk catalog mapping preserves `kitchenPrepared` when converting catalog products into kiosk products.
- Order serialization preserves kitchen-preparation metadata for products and options.
- Rice Meal add-ons use the same option/add-on logic as drink add-ons.
- Add Order flow returns to the main menu after the order is added.
- Add-ons UI was adjusted so the add-ons list is opened through an **ADD-ONS** action instead of occupying the initial popup view.
- Employee mode override is supported for kiosk-operated employee ordering, including the session/password behavior established in the kiosk settings flow.
- Review Order supports payment-mode tagging: **GCash / Cash / Others**.
- Place Order supports order printing.
- End-of-day summary supports Excel export.
- Kitchen-preparation tagging was moved into the Product/Catalog Unification architecture instead of maintaining it as a separate kiosk-only product definition.

### Verification

```text
flutter test
00:04 +39: All tests passed!
```

Live Chrome kiosk flow was also verified after the catalog changes.

### Architecture checkpoint

```text
Product Catalog
      ↓
Kiosk Catalog Repository
      ↓
Kiosk Catalog Adapter
      ↓
KioskProduct
      ↓
Cart / Order
      ↓
Order JSON / Kitchen Preparation
```

The Kiosk and Recipe Guide remain separate applications. The Kiosk does not import Recipe Guide Flutter source code; `recipeRef` remains an identifier only.

### Known limitations / intentionally deferred

- Commercial drink pricing is not yet established as a final centralized catalog price source.
- Burgers, Merienda, and Accessories remain dependent on actual commercial product/pricing data.
- Recipe instructions remain owned by Recipe Guide.
- Inventory remains outside the current Product Catalog scope.

### Exact next session

**Continue K3 — verify centralized catalog pricing and customization.**

The source-level implementation now reads product prices, size prices, and shared drink add-ons from the Product Catalog. Next is local Flutter verification and live customer-flow verification.

### Files / areas involved in this checkpoint

```text
assets/catalog/product_catalog.v4.commercial.json
lib/product_catalog/product_catalog_models.dart
lib/product_catalog/product_catalog_repository.dart
lib/product_catalog/kiosk_catalog_adapter.dart
lib/features/kiosk/data/kiosk_catalog_data.dart
lib/features/kiosk/models/kiosk_models.dart
test/kiosk/kiosk_kitchen_preparation_test.dart
```

### Session decision

The Product Catalog is an architectural layer inside the kiosk codebase, not a separate kiosk application. It provides the neutral commercial product contract/data used by the kiosk and can later be consumed by other applications without sharing Flutter application source code.


---

# Current Session — 2026-08-17

## Sprint K3.3 — Centralized Catalog Pricing

### Completed

- Added `price` to `CatalogProduct` and JSON parsing.
- Kiosk catalog adapter now preserves product-level catalog prices.
- Kiosk size mapping now uses `sizes[].price` directly from the Product Catalog.
- Removed the duplicated kiosk `_productPrices` and `_sizePrices` tables.
- `KioskPricing` is now a resolver over catalog-loaded prices rather than a second price source.
- Shared drink add-ons now come from Product Catalog `optionDefinitions`.
- Drink customization UI now consumes add-ons from the selected `KioskProduct`.
- Rice Meal add-ons remain product-specific catalog options.
- Added K3.3 catalog pricing/customization regression coverage.

### Static verification

- Product Catalog: **77 products**.
- Product-level prices: **12**.
- Size-based products: **65**.
- Fully priced size-based products: **61**.
- Intentionally unpriced Slushies: **4**.
- No duplicate `_productPrices`, `_sizePrices`, or kiosk-only drink add-on price table remains in application source.

### Flutter verification

Flutter CLI is not installed in the current execution environment, so `flutter analyze` and `flutter test` could not be run here. The previous verified checkpoint remains **39 tests passing** before this K3.3 source-level change.

### Files changed

```text
lib/product_catalog/product_catalog_models.dart
lib/product_catalog/kiosk_catalog_adapter.dart
lib/features/kiosk/data/kiosk_catalog_data.dart
lib/features/kiosk/pricing/kiosk_pricing.dart
lib/features/kiosk/pricing/README.md
lib/features/kiosk/pages/kiosk_category_page.dart
test/kiosk/kiosk_k3_catalog_pricing_test.dart
test/kiosk/kiosk_k3_customization_test.dart
test/kiosk/kiosk_k4_5_regression_test.dart
test/kiosk/kiosk_kitchen_preparation_test.dart
K3_3_CATALOG_PRICING_CHECKPOINT.md
```

### Next session

Run local Flutter verification, then proceed to K4 only after the K3 customer flow is confirmed.

---

# Current Session — 2026-08-18
## K15.3.2 — Category Manager

### Status
**IMPLEMENTED — source-level checkpoint; Flutter runtime verification pending**

### Completed
- Added `ProductCategory.toJson()` and `copyWith()`.
- Added `ProductCatalog.copyWith()` for immutable catalog projections.
- Extended `ProductCatalogRepository` with local category persistence using `shared_preferences`.
- Bundled catalog remains the baseline source; local category overrides are applied on load.
- Corrupt local category overrides fail safely back to the bundled catalog.
- Added `CategoryManagerController` with:
  - category loading
  - product counts
  - add category
  - edit category
  - active/inactive toggle
  - safe deletion of empty categories only
  - duplicate-name protection
  - stable category ID protection during editing
  - category ID format validation
- Added `CategoryManagerPage` with touch-friendly list UI, edit dialogs, status switches, product counts, add/delete actions, and refresh.

### Files changed / added
```text
lib/product_catalog/product_catalog_models.dart
lib/product_catalog/product_catalog_repository.dart
lib/features/catalog/pages/category_manager.dart
```

### Architecture decision
Category management operates on `ProductCategory` in the neutral Product Catalog. It does not modify or replace the kiosk `KioskCategory` enum.

This preserves the established separation between the commercial catalog and kiosk-specific UI models.

### Important limitation
The current customer-facing `KioskHomePage` still renders the legacy `KioskCategory.values` grid. Therefore, K15.3.2 persistence is complete, but newly created categories and category active/inactive state are **not yet automatically reflected in the customer home screen**.

That integration should be the next task rather than silently maintaining a second category definition.

### Verification
Flutter CLI is not installed in the current execution environment, so `flutter analyze` / `flutter test` could not be executed here.

### Exact Next Session
**K15.3.3 — Dynamic Catalog Category Integration**

Replace the customer-facing category grid's dependency on `KioskCategory.values` with the active Product Catalog category list while preserving the existing kiosk product/cart flow. Then add regression coverage for category add/edit/disable behavior.

---

# Current Session — 2026-08-18
## K15.3.3 — Dynamic Catalog Category Integration

### Status
**IMPLEMENTED — source-level checkpoint; Flutter runtime verification pending**

### Completed
- Replaced the customer-facing `KioskHomePage` category source from legacy `KioskCategory.values` + `KioskMenuData` to `KioskCatalogData.load()`.
- Active Product Catalog categories now determine the customer-facing category grid.
- Category product lists are loaded from the Product Catalog adapter.
- Newly created categories can appear in the kiosk without adding a new hard-coded enum member.
- Inactive categories are excluded from the customer-facing kiosk.
- Empty active categories remain visible as disabled / Coming soon cards.
- Added a refresh action so category changes made by staff can be reflected without restarting the kiosk application.
- Refactored `KioskCategory` from an enum into a stable-ID value object while retaining all existing named categories and `KioskCategory.values` compatibility.
- Known categories continue to resolve to the existing singleton values; unknown catalog categories are represented dynamically.
- Equality for dynamic categories is based on stable `categoryId`, preserving category-aware behavior such as Rice Meals add-ons.
- Added K15.3.3 regression tests for known-category resolution, new dynamic categories, and stable-ID equality.

### Files changed / added
```text
lib/features/kiosk/models/kiosk_models.dart
lib/features/kiosk/pages/kiosk_home_page.dart
lib/features/kiosk/data/kiosk_catalog_data.dart
test/kiosk/kiosk_k15_3_3_dynamic_category_test.dart
```

### Architecture checkpoint
```text
Product Catalog
      ↓
ProductCatalogRepository
      ↓
KioskCatalogData
      ↓
Active Product Categories
      ↓
KioskCategory value objects
      ↓
Kiosk Home
      ↓
KioskCategoryPage
      ↓
KioskProduct / Cart
```

The Kiosk still does not import Recipe Guide Flutter source code. The Product Catalog remains the commercial identity source of truth.

### Verification
Flutter/Dart CLI is not installed in the current execution environment, so `flutter analyze` / `flutter test` could not be executed here.

### Important note
The implementation is source-level complete, but local Flutter verification is still required before treating this checkpoint as runtime-verified.

### Exact Next Session
**K15.3.4 — Category/Product Assignment Management.**

Add staff-side product category assignment so an existing product can be moved between active catalog categories without editing the raw JSON, while preserving stable product IDs and centralized pricing.

---

# Current Session — 2026-08-18
## K15.3.4 — Category/Product Assignment Management

### Status
**IMPLEMENTED — source-level checkpoint; Flutter runtime verification pending**

### Completed
- Added `CatalogProduct.copyWith()` while preserving stable `productId`.
- Added catalog product serialization needed for safe local overrides.
- Added local product persistence in `ProductCatalogRepository` using `shared_preferences`.
- Added `ProductCategoryAssignmentController` for loading categories/products and assigning products to categories.
- Added `ProductCategoryAssignmentPage` with:
  - product search
  - category filter
  - current category display
  - touch-friendly ASSIGN action
  - category selection dialog
  - refresh
- Added an **ASSIGN PRODUCTS** entry point from Category Manager.
- Category assignment changes only `categoryId`; pricing, sizes, variants, options, recipeRef, kitchen-preparation metadata, and stable product ID remain intact.
- Added regression coverage for category reassignment and product serialization.

### Architecture checkpoint
```text
Category Manager
      ↓
Product Category Assignment
      ↓
Product Catalog Repository
      ↓
Local Product Override
      ↓
KioskCatalogData
      ↓
Customer Kiosk
```

### Verification
Flutter/Dart CLI is not installed in the current execution environment, so `flutter analyze` / `flutter test` could not be executed here.

### Important note
The implementation is source-level complete. Local Flutter verification is required before treating this checkpoint as runtime-verified.

### Exact Next Session
**K15.3.5 — Product Manager.**

Add staff-side product management for active/inactive status, availability, product details, and safe product editing while preserving stable product IDs and centralized catalog pricing.

---

# Current Session — 2026-08-18
## K15.3.5 — Product Manager

### Status
**IMPLEMENTED — source-level checkpoint; Flutter runtime verification pending**

### Completed
- Added `ProductManagerController` for loading and safely updating catalog products.
- Added `ProductManagerPage` with:
  - product search by name, stable product ID, or SKU
  - product type filter
  - category filter
  - active/inactive filtering
  - product count
  - active toggle
  - product edit dialog
- Product editing supports customer-facing name, category, description, image/reference, SKU, active status, availability, and kitchen-prepared flag.
- Stable `productId` is read-only and cannot be changed from Product Manager.
- Product type is validated against the established catalog types: `drink`, `food`, `accessory`, `addOn`.
- Product pricing, sizes, variants, and options remain read-only in Product Manager so centralized catalog pricing is not duplicated or accidentally overwritten.
- Added Product Manager entry point to Category Manager.
- Added K15.3.5 regression coverage for stable identity, editable state, serialization, and price preservation.

### Architecture checkpoint
```text
Product Manager
      ↓
ProductCatalogRepository
      ↓
Local Product Override
      ↓
Product Catalog
      ↓
KioskCatalogAdapter
      ↓
Customer Kiosk
```

### Important boundary
Product Manager manages commercial/catalog metadata only. Recipe instructions remain outside the kiosk catalog, and inventory/cost management remains a future POS/inventory concern.

### Verification
Flutter/Dart CLI is not installed in the current execution environment, so `flutter analyze` / `flutter test` could not be executed here.

### Files changed / added
```text
lib/features/catalog/pages/product_manager.dart
lib/features/catalog/pages/category_manager.dart
test/kiosk/kiosk_k15_3_5_product_manager_test.dart
```

### Exact Next Session
**K15.3.6 — Product Size & Variant Manager.**

Add staff-side management for product sizes and variants while preserving centralized selling-price ownership, stable size/variant IDs, and existing kiosk customization behavior.

---

# Current Session — 2026-08-18
## K15.3.10 — Catalog Navigation Integration & Staff Entry Point

### Status
**IMPLEMENTED — source-level checkpoint; Flutter runtime verification pending**

### Completed
- Added protected staff entry from the customer-facing `KioskHomePage` using the established five-tap logo gesture.
- Added staff PIN dialog before entering Catalog Management.
- Staff PIN is supplied through the `BIGGER_BREW_STAFF_PIN` Dart build define rather than storing a production credential in source.
- Added `CatalogManagerDashboardPage` as the protected staff destination.
- Returning from Catalog Management reloads the kiosk catalog so category/product changes can be reflected immediately.
- Added K15.3.10 regression coverage for the staff access policy.

### Staff entry flow
```text
Customer Kiosk Home
       ↓
5 taps on BIGGER BREW title
       ↓
STAFF ACCESS PIN
       ↓
Catalog Management Hub
       ├── Categories
       ├── Products
       ├── Sizes & Variants
       ├── Options / Add-ons
       └── Catalog Health
       ↓
Back to Kiosk
       ↓
Reload Product Catalog
```

### Security boundary
The kiosk does not expose the Catalog Management Hub through a normal customer-facing button. The staff gesture is intentionally hidden, followed by PIN authentication. The default development PIN is `0000`; production builds must override it with `--dart-define=BIGGER_BREW_STAFF_PIN=<store PIN>` before deployment.

### Files changed / added
```text
lib/features/kiosk/pages/kiosk_home_page.dart
lib/features/kiosk/staff_access.dart
lib/features/catalog/pages/catalog_manager_dashboard.dart
lib/features/catalog/pages/category_manager.dart
test/kiosk/kiosk_k15_3_10_staff_entry_test.dart
```

### Architecture checkpoint
```text
                    CUSTOMER KIOSK
                         │
                  5-tap staff gesture
                         ↓
                    Staff PIN Gate
                         ↓
               Catalog Management Hub
                  /       |       \
                 /        |        \
          Categories   Products   Options
                 \        |        /
                  \       |       /
                   Sizes & Variants
                         ↓
                   Catalog Health
                         ↓
                ProductCatalogRepository
                         ↓
                  KioskCatalogAdapter
                         ↓
                    Customer Kiosk
```

### Verification
Flutter/Dart CLI is not installed in the current execution environment, so `flutter analyze` / `flutter test` could not be executed here.

### Exact Next Session
**K15.3.11 — Catalog Change Safety & Confirmation.**

Add confirmation/guardrails for destructive catalog actions, unsaved edits, inactive-category impact, and product removal/disable operations before continuing deeper into staff administration.

---

# Working Project Merge — K15.3.24

## Status
**MERGED INTO SUPPLIED WORKING KIOSK — source-level; Flutter runtime verification pending**

The user's supplied working kiosk ZIP was used as the base project. The K15.3 catalog-management updates through K15.3.24 were merged into that project rather than replacing the working kiosk wholesale.

### Merged catalog capabilities
- K15.3.11 Catalog change safety
- K15.3.12 Backup / Restore
- K15.3.13 Audit History
- K15.3.14 JSON File Import / Export
- K15.3.15 Schema / Migration Guard
- K15.3.16 Import Preview / Diff
- K15.3.17 Deletion Protection
- K15.3.18 Selective Merge
- K15.3.19 Field-Level Review
- K15.3.20 Merge Summary
- K15.3.21 Import Rollback / Recovery
- K15.3.22 Editor / Manager Permissions
- K15.3.23 Multi-Kiosk Catalog Sync
- K15.3.24 Sync Hardening / Failure Guards

### Working-kiosk preservation
The existing customer kiosk, cart/checkout, payment, order queue/history, receipt/EOD, settings, staff session gate, and idle-timeout flows were preserved. `KioskCatalogManagerPage` now acts as a compatibility adapter into the unified K15.3 Catalog Management Hub.

### Dependency added
```text
file_picker: ^7.1.0+1
```

Required by catalog JSON import/export and multi-kiosk sync.

### Runtime verification required
Run on the development machine:
```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

### Exact Next Session
**K15.3.25 — Production Validation / Release Candidate.**

Validate the merged working kiosk end-to-end, beginning with compiler/test failures from the real Flutter environment before adding further catalog functionality.

# Current Session — 2026-08-20
## K17.2 — Centralized Pricing Authority

### Status
**IMPLEMENTED — source-level checkpoint; local Flutter verification pending**

### Completed
- Added `CatalogProduct.price` as the authoritative base selling price for products without size/variant pricing.
- Product-level price is now parsed from and serialized back to `product_catalog.v4.commercial.json`.
- `KioskCatalogAdapter` preserves the catalog product price.
- `KioskCatalogData` now projects the catalog product price into `KioskProduct.price`.
- Legacy single-variant pricing remains only as a compatibility fallback when a product-level price is absent.
- Reworked `KioskPricing` into a resolver over catalog-projected product/size/variant prices; removed its hard-coded commercial price table.
- Product-specific and shared option pricing remains catalog-owned. Options without an explicit price are no longer converted to an invented `₱0` price.
- Product Manager now exposes the base selling price for products without size/variant pricing while keeping the Product Catalog as the authoritative source.
- Added catalog validation for negative product, size, variant, and option prices.
- Added K17.2 regression coverage for product-price parsing, adapter propagation, pricing resolution, option totals, and negative-price rejection.

### Static source verification
The bundled commercial catalog was compared against `pricing_menu_source.json`: all 73 supplied regular/food price entries matched, and all 14 configured option prices matched.

### Local verification required
Run on the development machine:

```bash
flutter clean
flutter pub get
flutter test test/kiosk/kiosk_pricing_test.dart
flutter test test/kiosk/kiosk_k3_customization_test.dart
flutter test test/kiosk/kiosk_k17_2_pricing_authority_test.dart
flutter test test/kiosk/product_catalog_models_test.dart
flutter analyze
```

Then perform the customer-flow check:

```text
Drink → select size → select add-ons → ADD TO ORDER
      ↓
Cart uses catalog size price + catalog option prices

Food → ADD TO ORDER
      ↓
Cart uses catalog product base price + applicable food options

Unpriced product / size / option
      ↓
Must not receive an invented price
```

### Architecture checkpoint
```text
Product Catalog JSON
       ↓
CatalogProduct.price / ProductSize.price / ProductVariant.price
       ↓
KioskCatalogAdapter
       ↓
KioskCatalogData
       ↓
KioskProduct
       ↓
KioskPricing + KioskCart
       ↓
Customer Order Total
```

### Exact Next Session
**K17.3 — Product / Add-on Rule Finalization.**

Verify and harden category-aware option assignment across drinks, rice meals, burgers, merienda, accessories, and other product types; then add regression coverage ensuring each product receives only its assigned/shared applicable options.

