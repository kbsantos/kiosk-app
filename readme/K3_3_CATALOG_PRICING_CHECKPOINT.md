# Bigger Brew K3.3 — Catalog Pricing Checkpoint

## Result

**IMPLEMENTED — Static validation PASS; Flutter runtime verification pending**

## Goal

Move commercial selling prices out of the kiosk-only pricing table and make the
Product Catalog the single source of truth for product and size prices.

## Completed

- Added product-level `price` to `CatalogProduct` JSON parsing.
- Added product-level price to the kiosk catalog adapter.
- Kiosk product prices now come directly from the Product Catalog.
- Kiosk size prices now come directly from catalog `sizes[].price`.
- Removed the duplicated `_productPrices` and `_sizePrices` tables from
  `KioskPricing`.
- `KioskPricing` is now only a UI-independent resolver over already-loaded
  catalog prices.
- Moved drink add-on resolution to Product Catalog `optionDefinitions`.
- Drink customization now receives add-ons through the catalog adapter instead
  of a kiosk-only add-on price table.
- Rice Meal product-specific options continue to come from the catalog product.
- Existing kitchen-preparation metadata remains preserved.

## Catalog validation

Current commercial catalog:

- 77 products total.
- 12 products have product-level prices.
- 65 products use size-specific pricing.
- 61 size-based products have complete prices for all configured sizes.
- 4 Slushies products intentionally remain unpriced because the supplied
  commercial source did not contain a Slushies price section:
  - `green_apple_slushies`
  - `strawberry_slushies`
  - `blueberry_slushies`
  - `lychee_slushies`

## Size mapping

The catalog continues to use:

| Customer label | Volume |
|---|---:|
| Regular | 12oz |
| Go Big | 22oz |
| Go Bigger | 1 Liter |

## Add-on architecture

```text
Product Catalog
      │
      ├── product price
      ├── size prices
      └── option definitions
              │
              ▼
       Kiosk Catalog Adapter
              │
              ▼
          KioskProduct
              │
              ▼
      Customization / Cart
```

## Important boundary

The kiosk does not own a second commercial price table. If a commercial price
changes, the catalog data is the intended update point.

Recipe instructions and barista preparation details remain outside the catalog
and continue to belong to the Recipe Guide.

## Verification limitation

Flutter/Dart CLI is not installed in the current execution environment, so
`flutter test` and `flutter analyze` could not be executed here. Static catalog
and source-structure validation passed.

## Next

Run locally:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

Then verify the kiosk customer flow for:

1. Drink → size → add-ons → Add to Order.
2. Rice Meal → add-ons → Add to Order.
3. Food product pricing.
4. 12oz / 22oz / 1 Liter price display.
5. Intentionally unpriced Slushies remain unavailable until prices are supplied.


## Post-user verification fixes — 2026-08-17

The first local Flutter test run exposed three issues in the K3.3 checkpoint package:

1. `ProductCatalog` test fixtures could not omit `categories`, even though the catalog JSON used by the checkpoint does not require a categories array. The constructor now defaults `categories` to an empty list, preserving JSON behavior while allowing focused test fixtures.
2. `kiosk_k3_catalog_pricing_test.dart` declared a non-const `CatalogProduct.fromJson(...)` value inside a `const ProductCatalog`, producing `Not a constant expression`. The fixture catalog is now non-const.
3. `kiosk_kitchen_preparation_test.dart` had its second `test(...)` declaration outside `main()`, producing parser errors and the downstream Dart compiler termination seen in the test run. The second test is now inside `main()`.

These are test/fixture and constructor-compatibility corrections; no commercial catalog values were changed.

### Next verification

Run:

```bash
flutter clean
flutter pub get
flutter test
```

Then run the Chrome kiosk flow and confirm K3 customization/pricing before starting K4.
