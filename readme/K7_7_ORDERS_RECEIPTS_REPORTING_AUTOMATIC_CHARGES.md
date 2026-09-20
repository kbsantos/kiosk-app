# K7.7 — Orders, Receipts & Reporting for Automatic Charges

## Scope

K7.7 makes Store-managed automatic charges visible and traceable across the kiosk sale lifecycle without changing the existing order model or the previously validated Auto Apply add-on behavior.

### Changes

- `KioskCartItem` now exposes separate totals for mandatory automatic charges and normal selectable add-ons.
- Customer receipt UI identifies automatic charges separately and shows their amounts.
- Thermal/PDF customer receipt identifies automatic charges and shows their amounts.
- Barista production copy does not print mandatory automatic charges as drink add-ons; Kitchen copy continues to print only kitchen-prepared options.
- EOD PDF adds an `AUTOMATIC CHARGES — SALES` summary with quantity and sales amount.
- EOD Excel export adds an `Automatic Charges` sheet with quantity and sales amount.
- Reporting transaction mapping continues to send automatic-charge metadata (`automatic: true`) and charge price in `transaction_item_options`.
- Added regression tests for automatic-charge pricing separation and reporting payload preservation.

## Validation required

Flutter/Dart are not available in the build environment used to prepare this checkpoint.

Run in the kiosk project:

```bash
flutter analyze
flutter test
```

Expected new test coverage includes the automatic-charge pricing and reporting cases. Existing K7.6 behavior must remain green.

## Manual validation

1. Sync a Store catalog containing an automatic charge such as `paper_straw` at ₱2.
2. Add a matching product and complete an order.
3. Confirm the customer receipt shows the automatic charge and its amount.
4. Confirm Barista/Kitchen copies do not treat a non-kitchen automatic charge as a normal production add-on.
5. Generate the EOD PDF and confirm `AUTOMATIC CHARGES — SALES` lists the charge quantity and sales amount.
6. Export EOD Excel and confirm the `Automatic Charges` sheet contains the same totals.
7. Confirm the reporting payload retains `automatic: true` for the charge option.
