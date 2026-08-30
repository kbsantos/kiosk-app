# K23.10 — Product Variant Selection Fix

## Problem
Product variants were stored in the catalog and loaded into `KioskProduct`, but the customer-facing product flow only handled sizes and add-ons. Tapping a product with variants therefore skipped variant selection and the selected variant was never passed to the cart.

## Fix
- Added a customer-facing variant selection sheet.
- Active, priced variants are shown as touch-friendly choices.
- Selected `KioskVariant` is passed into `KioskCart.add()`.
- Variant price becomes the cart item's base price when no size is selected.
- Variant selection works before product-specific/shared add-ons.
- Drink add-on validation now also passes the selected variant into `cart.canAdd()`.
- Product cards with variants show `SELECT VARIANT` and a `From <currency>` starting price.
- Existing size selection remains unchanged.
- Existing add-on, cart, checkout, receipt, and printer flows remain unchanged.

## Validation
Flutter/Dart validation could not be run in this environment because the Flutter SDK is not installed.

Run locally:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Tablet test
1. Open a product with variants.
2. Confirm `SELECT VARIANT` is shown.
3. Tap the product.
4. Select a variant.
5. Confirm the selected variant is shown in the cart.
6. Confirm the variant price is used.
7. Complete checkout and confirm the variant appears on receipt/order history.
8. Test a product with both size and variant.
9. Test a variant product with add-ons.
10. Confirm XP-58H printing remains unchanged.
