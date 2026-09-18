# Kiosk Pricing / Checkout Consistency Checkpoint

## Scope
This checkpoint addresses the next Kiosk pricing item after removing the Upload Local Catalog UI.

### Changes
- Persist `basePrice` separately from final `unitPrice` in local Kiosk order snapshots.
- Restore legacy snapshots without re-adding option prices on every JSON reload.
- Freeze the cart item list and calculate one authoritative checkout total before creating a Kiosk order.
- Validate that the frozen item totals equal the cart total before persistence.
- Added regression coverage for repeated order JSON round-trips and legacy snapshots.

### Why
Previously, a product without a size/variant could be restored with its final option-inclusive `unitPrice` as the product price. Reloading the order then added the same options again. This could produce progressively inflated prices in persisted transaction data.

Example:
- Liempo base price: 85
- One Rice option: 20
- Correct unit price: 105

The snapshot now stores both values explicitly so reloads remain 105 instead of treating 105 as the new base price.

## Preserved
- XP-58H Bluetooth printer implementation.
- Existing receipt/barista/kitchen printing behavior.
- Catalog sync architecture and Refresh Product Catalog.
- Removal of Upload Local Catalog from the Administration Sync UI.
- Existing Kiosk functionality outside this pricing/checkout consistency change.

## Historical data
This checkpoint does not modify existing Supabase transactions. Historical pricing anomalies remain unchanged until a separate reconciliation decision is made.

## Validation
Flutter/Dart CLI is not available in the build environment used to prepare this ZIP. Run locally:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Recommended functional test:
1. Add Liempo at ₱85.
2. Select One Rice at +₱20.
3. Verify cart total is ₱105.
4. Checkout.
5. Reload/restart the kiosk.
6. Verify the saved order still shows ₱105 for the item.
7. Repeat the reload and verify it remains ₱105.
