# K17.2 — Centralized Pricing Authority Checkpoint

**Date:** 2026-08-20

## Status

Source implementation complete. Local Flutter verification is the remaining gate.

## Objective

Ensure the Product Catalog is the only commercial selling-price authority used by the customer kiosk.

## Changes

1. `CatalogProduct.price` was added for products that do not use size/variant pricing.
2. Product-level prices are parsed from and serialized to the commercial catalog.
3. The kiosk adapter preserves the product-level price.
4. Kiosk catalog projection exposes that price through `KioskProduct.price`.
5. `KioskPricing` no longer contains a duplicate hard-coded commercial price table.
6. Size and variant prices are resolved from the selected catalog-projected value.
7. Catalog option prices remain authoritative for add-ons.
8. Unpriced options are excluded instead of being converted to a fake zero price.
9. Negative commercial prices are rejected by catalog validation.
10. Product Manager exposes base selling price editing for products without size/variant pricing.

## Static verification

The supplied `pricing_menu_source.json` was compared with the bundled commercial catalog:

- 73 regular/food price entries checked — **0 mismatches**
- 14 configured option prices checked — **0 mismatches**

## Runtime gate

Run:

```bash
flutter clean
flutter pub get
flutter test test/kiosk/kiosk_pricing_test.dart
flutter test test/kiosk/kiosk_k3_customization_test.dart
flutter test test/kiosk/kiosk_k17_2_pricing_authority_test.dart
flutter test test/kiosk/product_catalog_models_test.dart
flutter analyze
```

Do not mark K17.2 runtime-green until these checks pass on the development machine.
