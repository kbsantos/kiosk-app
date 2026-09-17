# Bigger Brew Kiosk — Clean Unified Baseline

This is the clean standalone Bigger Brew customer-ordering kiosk project.

## Important architecture

The Kiosk is a **completely separate Flutter application** from the Bigger Brew Recipe Guide / Barista application.

The Kiosk does **not** import:

- `bigger_brew_barista`
- `RecipeRepository`
- `RecipePage`
- `BaristaModePage`
- recipe editor code
- recipe JSON assets

Instead, the Kiosk contains a neutral commercial Product Catalog JSON file.

```text
Product Catalog
      │
      ├── Bigger Brew Kiosk
      │       └── Kiosk UI / Cart / Orders
      │
      └── Bigger Brew Recipe Guide
              └── Recipes / Barista Mode
```

## Current baseline

- K1 kiosk foundation retained.
- K1 Rice Meals retained with established prices.
- K1 Rice Meal add-ons retained.
- Neutral Product Catalog included.
- Kiosk-side catalog loader included.
- Kiosk-side catalog mapping included.
- Drink products are visible from the neutral catalog.
- Drink prices remain unconfigured until the pricing sprint.
- Unpriced products cannot be added to the cart.
- No dependency on the Recipe Guide application.

## Project structure

```text
bigger_brew_kiosk/
├── assets/
│   └── catalog/
│       └── product_catalog.v4.commercial.json
├── lib/
│   ├── main.dart
│   ├── product_catalog/
│   │   ├── product_catalog_models.dart
│   │   ├── product_catalog_repository.dart
│   │   └── kiosk_catalog_adapter.dart
│   └── features/kiosk/
│       ├── kiosk_page.dart
│       ├── data/
│       │   ├── kiosk_menu_data.dart
│       │   └── kiosk_catalog_data.dart
│       ├── models/
│       │   └── kiosk_models.dart
│       └── pages/
│           ├── kiosk_home_page.dart
│           ├── kiosk_category_page.dart
│           └── kiosk_cart_page.dart
├── test/
│   └── kiosk/
│       └── kiosk_k1_test.dart
└── pubspec.yaml
```

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

## Current product behavior

Rice Meals are orderable.

Drinks from the neutral catalog are displayed, but show `Price not configured` and cannot be added until commercial drink pricing is defined.

This is intentional and avoids inventing prices.

## Next sprint

U8 — final Product Unification validation/migration, then return to K2/K3 using this standalone catalog architecture.

## K2 Layout Update — Persistent Order Panel

The kiosk ordering layout now uses a desktop two-pane design when the screen is wide enough:

```text
┌──────────────────────────────────────────────────────────────┬──────────────────────┐
│                         MENU / PRODUCTS                      │     YOUR ORDER       │
│                                                              │                      │
│  categories / products                    ADD TO ORDER       │  item 1       ₱85   │
│  categories / products                    ADD TO ORDER       │  item 2       ₱70   │
│  categories / products                    ADD TO ORDER       │  item 3       ₱20   │
│                                                              │                      │
│                                                              │  TOTAL       ₱175   │
│                                                              │  [ CHECKOUT ]       │
└──────────────────────────────────────────────────────────────┴──────────────────────┘
```

The order panel remains visible while browsing a category and adding products.

- Desktop/tablet-wide layout: menu on the left, order panel on the right.
- Order panel width: 360px.
- Narrow screens: the order panel is hidden to preserve usable menu space; the existing cart page remains available through the category/cart navigation architecture.
- Checkout remains a K4 placeholder.

This is a layout-only K2 update. Product pricing/customization and checkout are not being implemented yet.

## K2 Product Catalog Integration

The Kiosk now reads product identity and category membership from the neutral
Product Catalog asset at `assets/catalog/product_catalog.v4.commercial.json`.

Kiosk-only prices remain a temporary local bridge until K3 centralized pricing.
The Kiosk never resolves `recipeRef` and has no dependency on the Recipe Guide.


## K3 — Pricing & Customization

K3 introduces the customer-facing drink size selection structure:

- Regular — 12oz
- Go Big — 22oz
- Go Bigger — 1 Liter

The Kiosk maps these sizes from the neutral Product Catalog.

Drink prices remain intentionally unconfigured until the approved commercial price list is supplied. The UI shows `PRICE TBD` rather than inventing prices.

Rice Meal add-ons are read from the Product Catalog rather than hardcoded in the category page.

The right-side persistent order panel remains the primary order view.


### K3 analyzer fix

The K3 package was corrected after local `flutter analyze` reported:
- missing `KioskProduct.options`
- unused product catalog model import
- unused `kiosk_cart_page.dart` import
- relative import in the K3 test

These are fixed in the K3 Fixed package.


### K3 final analyzer fix

The latest local analyzer output showed one remaining model-field mismatch:
`KioskCatalogOption` exposes `id`, while the category page was still reading `optionId`.
It also treated `price` as nullable even though the kiosk-side option model stores it as `int`.

Both references are corrected in this package.


## K3.1 — Centralized Pricing Layer

The kiosk now has one commercial pricing service:

`lib/features/kiosk/pricing/kiosk_pricing.dart`

No selling price is invented in K3.1.

When the approved price list is supplied, update the centralized maps there. UI pages should ask the pricing layer for prices rather than storing hardcoded selling prices.

This makes future price changes a data/configuration change instead of a widget-code change.


## K3.2 — Menu Pricing Applied

Pricing was updated from the supplied Bigger Brew menu image.

- Regular prices are taken directly from the menu.
- Go Big = Regular + ₱10.
- Go Bigger = Regular + ₱40.
- Hot Coffee is treated as 1 size only, matching the menu.
- Slushies remain unpriced because they do not appear on the supplied menu image.
- Rice meal prices remain as previously configured where they are not part of this drink menu.


### K3.2 pricing source

The supplied menu image is the authoritative source for this pricing update.

Applied:
- Afforda Milktea
- Signature Milktea
- Afforda Coffee
- Signature Coffee
- Frappe Selections
- Fruitea
- Fruity Soda
- Matcha Series
- Hot Coffee
- Existing rice-meal/add-on prices already present in the catalog

Sizing:
- Regular = menu R price
- Go Big = R + ₱10
- Go Bigger = R + ₱40
- Hot Coffee = one size only

Not assigned:
- Slushies, because no slushie prices are shown in the supplied image.
- New add-ons shown in the image (Pearl, Nata, Espresso Shot, etc.) are not added in this pricing-only sprint; they should be added as catalog products/options in the customization sprint.


## K3.3 — Drink Customization

The supplied menu's 11 drink add-ons are now available from the Kiosk:

- Pearl — ₱10
- Nata — ₱15
- Coffee Jelly — ₱15
- Espresso Shot — ₱20
- Crushed Oreo — ₱20
- Fruit Syrup — ₱20
- Creampuff — ₱20
- Coffee Syrup — ₱25
- Whipcream — ₱30
- Oat Milk — ₱40
- Non Fat Milk — ₱40

Drink ordering flow:

1. Select drink
2. Select size
3. Select add-ons
4. Add to order

The selected size and add-ons are shown in the persistent right-side order panel and included in the cart total.

These add-ons are sourced from the supplied menu image and are kept in the kiosk pricing layer until they are later promoted into the neutral catalog.


## K4.1 — Checkout / Order Review

The checkout button now opens a dedicated checkout page.

Included:
- Full order review
- Quantity and customization summary
- Running total
- Take Out / Dine In selection
- Pay at Counter placeholder
- Place Order action
- Local order confirmation number
- Cart reset after confirmation

No external payment gateway or POS submission is performed yet. This is intentionally the K4.1 customer-order flow.


## K4.2 — Local Order Persistence & Queue

Completed kiosk submissions are now persisted locally using `shared_preferences`.

Each new day starts a fresh queue sequence:

- BB-001
- BB-002
- BB-003
- ...

Persisted order records include:
- Order number
- Timestamp
- Take Out / Dine In
- Payment method
- Status
- Products
- Sizes
- Add-ons
- Quantity
- Total

A local Order Queue page is included for development/counter workflow. It can move orders through Preparing, Ready, Completed, or Cancelled.

No cloud/POS synchronization is included yet.


## K4.2.1 Build/Test Fix

Fixed the missing `KioskOrder` import in checkout and updated the legacy pricing test to match the now-configured menu prices.


## K4.3 — Customer Queue / Order Status

After an order is saved and confirmed, the kiosk now opens a customer-facing Order Status screen.

It displays:
- Bigger Brew branding
- Queue number
- Current order status
- Order summary
- Take Out / Dine In
- Total
- Customer instruction

The screen polls the local order repository every 2 seconds, so a counter operator changing an order from Pending → Preparing → Ready is reflected on the customer screen.

The queue screen can return to the menu after the customer finishes viewing the status.

Cloud synchronization and a second physical customer display are not included yet.


## K4.4 — Payment Boundary

K4.4 separates payment processing from checkout.

Current method:
- Pay at Counter
- Payment status is stored as `pending`

A `KioskPaymentProcessor` interface now defines the boundary for future:
- GCash / QR payment provider
- Card terminal
- Other payment gateway

No merchant credentials, payment API, QR payload, or fake payment confirmation is included. A real provider can be plugged in later without redesigning checkout or orders.


## K4.5 — Counter Order Management

The Order Queue is now a proper counter workflow.

Added:
- Status filter chips for All, Pending, Preparing, and Ready
- Active-order count
- Full order detail dialog
- Product quantities
- Drink size and volume
- Add-ons
- Order type
- Payment method/status
- Order time
- Total
- Direct status changes: Pending, Preparing, Ready, Completed, Cancelled
- Refresh action

Completed and cancelled orders remain persisted in local storage but are removed from the active queue.


## K4.5.1 — Build/Test Fix

Fixed the K4.5 issues found during local testing:

- Imported `kiosk_models.dart` into the counter queue page so `KioskCartItem` is a valid type.
- Corrected the pricing regression test to use the kiosk's size-based pricing table for drinks.
- Removed the invalid `const` use around `DateTime(...)` in the counter queue test.
- Added regression coverage for sized drink pricing and counter order item details.


## K4.6 — Order History / End-of-Day

Added a separate Order History screen for completed kiosk orders.

Features:
- Select a specific business date
- Completed order count
- Items sold count
- Completed sales total
- Payment-still-pending total
- Completed order list
- Order detail view
- Payment status indicator
- Refresh
- Navigation from Home and Order Queue

Sales are calculated from orders whose order status is `completed`. Cancelled, pending, and preparing orders are excluded from completed sales.

Payment status remains separate from order status. This means the screen can expose completed orders that still have a `pending` payment record instead of incorrectly treating them as cash collected.

No cloud/POS synchronization is included yet.


## K4.7 — Payment Completion

Added manual payment completion for the current `Pay at Counter` flow.

Staff can:
- Mark a pending payment as `PAID` directly from the active Order Queue.
- Mark a completed order as `PAID` from Order History.
- See `PAID` vs `PENDING` clearly in the queue/history.
- Keep payment status independent from order preparation status.

The kiosk still does not process GCash/card transactions. `PAID` is a staff confirmation for the physical counter payment.

End-of-day `COMPLETED SALES` continues to represent completed orders, while `PAYMENT STILL PENDING` now decreases when staff confirms payment.


## K4.8 — Receipt / Order Ticket

Added a printable receipt/ticket flow.

Features:
- Dedicated receipt preview
- Bigger Brew branding
- Order number
- Time
- Order type
- Payment method/status
- Product quantities
- Drink size and volume
- Add-ons
- Total
- Paid / Pay at Counter indicator
- Print dialog via the `printing` package
- PDF generation via the `pdf` package
- Print access from Order Queue and Order History

The receipt is a presentation/printing artifact only. It does not change order or payment state.


K4.8.1 — Receipt navigation fix: receipt actions opened from the history dialog now navigate using the parent page context after closing the dialog.


## K4.9 — Order Cancellation / Refund

Added cancellation and refund handling.

Cancellation:
- Staff can cancel an active order from the Order Queue.
- A confirmation dialog is required.
- An optional cancellation reason is stored.
- Cancelled orders leave the active queue.
- Cancellation does not automatically mark a payment as refunded.

Refund:
- Only a `paid` payment can be refunded.
- Refund confirmation is required.
- Refund changes payment status to `refunded`.
- The kiosk does not move money through a payment gateway; this is a staff accounting confirmation.

Order History now supports:
- Completed filter
- Cancelled filter
- All orders filter
- Refund total in the daily summary
- Cancellation reason in order details

Completed sales remain based on completed orders. Refunded amounts are shown separately so gross completed sales and refunds are not silently mixed.

K4.9.1 — Refund guard tightened: refunds are only valid for orders that are both `cancelled` and `paid`; cancellation uses its dedicated confirmation flow.


K4.9.2 — Build fixes:
- `_OrderCard` now receives Mark Paid and Cancel callbacks from the queue State.
- Removed Cancelled from the generic status popup because cancellation uses its dedicated confirmation/reason flow.
- Receipt PDF callback now returns `Future<Uint8List>` as required by `printing`.
- Receipt regression test no longer relies on an invalid const getter expression.


## K4.10 — Kiosk Settings & Operational Controls

Added a dedicated Kiosk Settings page.

Controls:
- Store OPEN / CLOSED mode
- Store display name
- Receipt paper preference: 58mm / 80mm
- Local order-data explanation
- Settings button from the main kiosk
- Closed-store banner on the menu
- Closed-store mode blocks new checkout/orders while leaving existing queue/history accessible

Order sequence remains date-based and automatically starts at BB-001 on a new calendar day. Manual same-day reset is intentionally not exposed because it could create duplicate order numbers.

This is kiosk-local operational configuration. Real printer-device selection, staff authentication, and backend synchronization remain future POS/backend work.


K4.10.1 — Build correction:
- Rebuilt the nested FutureBuilder/LayoutBuilder section in `kiosk_home_page.dart` with balanced widget closures.
- Fixed the repository test's non-constant `product.sizes.single` declaration.
- Removed unused test model imports reported by the analyzer.


## K4.11 — Staff/Admin Access

Added a local 4-digit staff PIN gate.

Protected from the customer-facing kiosk:
- Kiosk Settings
- Order History
- Order Queue
- Queue operations such as payment completion, cancellation and refunds

Fresh installation default PIN: `1234`. Staff authentication is requested once per 30-minute in-app session.

The PIN can be changed from Kiosk Settings after staff authentication. This is a local kiosk control, not cloud authentication; backend/user accounts are intentionally deferred to K5.


## K4.11.1 — Staff PIN Dialog Lifecycle Fix

Fixed a runtime Flutter assertion caused by disposing the `TextEditingController`
in `KioskStaffGate.requirePin()` immediately after `showDialog()` returned.

The staff PIN dialog now owns its controller in a dedicated StatefulWidget and
disposes it from that widget's `dispose()` lifecycle. This prevents:
`A TextEditingController was used after being disposed`
and the cascading `_dependents.isEmpty` / wrong build scope assertions.


## K4.11.2 — Review Order / Payment / Printing / Size UI

- Added customer payment-mode tags: GCash, Cash, Others.
- PLACE ORDER now saves the order and opens the print dialog automatically.
- Shared receipt-printing service is used by checkout and the receipt page.
- Reworked drink size pricing on product cards into aligned size/volume/price blocks.
- Payment mode remains a tag at this stage; gateway integration is not claimed.

## K4.11.3 — End-of-Day Excel Export

Added Excel export to the End-of-Day / Order History workflow.

The export includes:
- Summary information for the selected business date.
- Completed sales and refund totals.
- Payment-status information.
- An `Orders` worksheet containing order-level details.
- Payment mode (`GCash`, `Cash`, or `Others`).
- Order Mode (`Customer` or `Employee`) for employee-order reconciliation.

The export is generated locally from the kiosk order repository and does not require cloud synchronization.

## K4.11.4.1 — Employee Session / Default Mode Update

The Employee Order Mode behavior was refined for employee-operated kiosk sessions.

- Employee Order Mode now defaults to **ON** on a fresh install and on this settings-key migration.
- Staff authentication is required only once per **30-minute in-app staff session**.
- While the session is active, opening Settings, Order Queue, Order History, and other staff-protected screens does not prompt for the PIN again.
- The staff session expires automatically after 30 minutes and the next protected action requires the PIN again.
- Changing the staff PIN during an authenticated session no longer asks for the current PIN a second time; only the new PIN and confirmation are required.
- Employee Mode continues to mark orders PAID + COMPLETED automatically while preserving the selected payment mode.

## K4.11.4 — Employee Order Mode

Employee Order Mode is a staff-operated checkout override for cases where an employee enters an order on behalf of a customer.

### Setting

`KIOSK SETTINGS → ORDER MODE → EMPLOYEE ORDER MODE`

The setting is protected by the existing staff PIN because Kiosk Settings are staff-only. Once staff authentication succeeds, the kiosk keeps the staff session unlocked for 30 minutes.

Default: **ON**.

Staff authentication is requested once per 30-minute in-app session; staff navigation does not repeatedly prompt for the PIN while the session is active.

### When OFF — Customer Mode

- The normal payment workflow is used.
- The selected payment mode (GCash / Cash / Others) is recorded.
- Orders are created as `Customer` orders.
- Orders begin in `Pending` and follow the normal queue lifecycle.

### When ON — Employee Mode

Pressing `PLACE ORDER`:

- keeps the selected payment mode for reporting;
- records payment status as `PAID`;
- records order status as `COMPLETED` immediately;
- records the order mode as `Employee`;
- prints the order immediately using the existing print-on-place-order behavior;
- returns the employee to the kiosk after confirmation instead of sending the order into the customer queue flow.

The checkout screen displays a clear Employee Mode warning so staff can see that orders will be automatically marked paid and completed.

### End-of-Day / Excel

The Orders worksheet now includes an `Order Mode` column so Employee and Customer orders can be distinguished during reconciliation.

### Data compatibility

Historical orders without `orderMode` remain valid and are loaded as `Customer` by default.


## K4.11.4.2 — Kitchen Preparation Routing

Added menu-level **Kitchen Prepared** tagging. Staff can enable or disable
individual menu products and drink add-ons for the printed KITCHEN COPY.
The customer receipt remains unchanged. When at least one ordered item is
tagged for kitchen preparation, the printed ticket includes a separate
KITCHEN COPY section containing only kitchen-prepared items and kitchen-tagged
add-ons.

Default behavior:
- Rice Meals are kitchen-prepared by default.
- Rice Meal add-ons are kitchen-prepared by default.
- Drink products and drink add-ons are not kitchen-prepared by default.
- Kitchen preparation is now defined by the shared Product Catalog; kiosk settings no longer override product routing.

### Product Catalog Source of Truth

Kitchen preparation routing is part of Product/Catalog Unification rather than kiosk-local settings.

- Products use `kitchenPrepared`.
- Product options use `kitchenPrepared`.
- Shared option definitions use `kitchenPrepared`.
- The kiosk adapter reads these values from `product_catalog.v4.commercial.json`.
- Kiosk Settings no longer stores or overrides kitchen routing.

Rice meals and their food add-ons are currently tagged for kitchen preparation. Drink products and drink add-ons are currently not tagged for kitchen preparation.

## Kitchen Copy Printout

The order ticket now contains a separate **KITCHEN COPY** section when at least one
ordered product or add-on is tagged `Kitchen Prepared`. The kitchen copy includes
only preparation-relevant items and kitchen-tagged add-ons; customer pricing and
payment details remain in the customer receipt section.

Kitchen routing is read-only from the kiosk and is supplied by Product Catalog metadata.
The settings are stored locally on the kiosk and are independent of product pricing.

## K4.11.4.3 — Add Order Navigation + Rice Meal Add-on UX

### Add Order navigation

When an item is customized through the Add-ons sheet and **ADD TO ORDER** is
pressed, the item is added to the cart and the kiosk returns directly to the
main Kiosk Home menu. This keeps the next item selection one tap away.

### Rice Meal add-ons

Rice Meal add-ons now use the same interaction pattern as drink add-ons:

- Add-ons are collapsed when the sheet opens.
- The **ADD-ONS** button reveals the selectable add-on list.
- The button changes to **HIDE ADD-ONS** while expanded.
- **ADD TO ORDER** confirms the selected options.
- Kitchen-preparation flags are loaded for Rice Meal add-ons using the same
  settings repository used by drink add-ons.

## K4.11.6 — Kiosk Navigation & Safety

Customer-session safety now includes a reusable idle-timeout controller.

- Default customer inactivity timeout: **3 minutes**.
- Root-level touch/pointer activity resets the timer across the kiosk customer flow.
- Timeout clears the current cart and returns the kiosk to the Home screen.
- Staff Settings, Order Queue, and Order History pause the customer timeout while staff access is active.
- Returning to the customer kiosk flow re-enables the timeout.
- Customer Order Status remains protected by the same timeout so an unattended kiosk does not remain on a previous customer's status screen indefinitely.

This is a kiosk-session safety mechanism only; it does not change order persistence,
payment status, Employee Order Mode, printing, or End-of-Day reporting.

## K4.11.7 — Production / Store Mode

The customer-facing kiosk now hides staff navigation behind the protected
5-tap `BIGGER BREW` logo gesture. Staff authentication still uses the existing
4-digit PIN and 30-minute session. Authenticated staff are routed through the
Staff Tools hub for Order Queue, Order History/EOD, Settings, and explicit
exit back to customer mode.

## K4.11.8 — K13 Final Regression / Release Validation

Added a dedicated release-contract regression suite:

`test/kiosk/kiosk_k13_release_regression_test.dart`

The suite protects the critical production contracts without changing the
customer UI or existing order workflow:

- size-based drink pricing and add-on totals;
- Rice Meal kitchen-preparation metadata;
- order JSON round-trip including size, options, payment and order mode;
- production defaults (`storeOpen`, Employee Order Mode, store name, paper size);
- counter payment behavior;
- staff session lock and 30-minute duration;
- customer idle-timeout stop behavior during staff mode;
- stable category IDs used by stored orders.

### Local release validation

Run the full validation sequence:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then manually verify the production kiosk on Chrome and the target tablet:

1. Customer can place a normal order.
2. Employee Order Mode still completes and prints an employee-entered order.
3. Drink sizes and add-ons retain their prices.
4. Rice Meals and kitchen-tagged add-ons appear on the kitchen copy.
5. EOD Excel export contains Drink Summary and Meal Summary.
6. Three-minute customer idle timeout clears abandoned carts.
7. Five-tap logo gesture opens Staff PIN access.
8. Staff Mode exposes Queue, History/EOD, and Settings.
9. Exiting Staff Mode locks staff access again.
10. Store Closed does not expose customer Settings access.


## K15.2 — Catalog Manager

Staff Mode now includes Product Catalog for browsing, searching, filtering, and reviewing catalog status. Product mutation is intentionally deferred to K15.3.

## K15.3.1 — Catalog Manager Shell

The staff Product Catalog entry now opens the K15 Catalog Management shell. The shell is read-only/non-destructive for this step; category/product mutation is intentionally deferred to K15.3.2+.
