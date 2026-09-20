# K7.6 — Kiosk Consumption of Store-Managed Automatic Charges

## Purpose

Consume `automaticCharges` published by Store Management and apply matching
charges to kiosk cart items as mandatory order options.

## Behavior

- Active automatic charges can target a category, product, or product type.
- Matching charges are projected into the kiosk catalog as `automatic: true`.
- Automatic charges are added to every matching cart item.
- Automatic charges are not shown in the customer add-on selector and cannot
  be removed through the customer add-on flow.
- Existing Auto Apply add-ons remain separate: they are preselected but
  removable by the customer.
- Automatic charge metadata is preserved in local kiosk order JSON and in the
  reporting payload/restore path.
- Local catalog persistence/backup now retains `automaticCharges`.

## Dependency

Apply the Store Management migration first:

`supabase/20260920_automatic_charges.sql`

The kiosk consumes the `automaticCharges` field from the existing
`get_store_catalog` master-catalog RPC.

## Validation

Flutter/Dart executables are not available in the build environment used to
prepare this checkpoint, so runtime `flutter analyze` and `flutter test` have
not been executed here.

Run locally:

```bash
flutter analyze
flutter test
```

Expected: the existing unrelated `dart:html` deprecation may remain as an
informational analyzer issue.

## Manual validation

1. In Store Management, create an active automatic charge, e.g. `paper_straw`
   for category `drinks`, amount `2`.
2. Publish the catalog.
3. On the kiosk, refresh/synchronize the Store Master catalog.
4. Add a matching drink to the cart.
5. Confirm `Paper Straw` is included automatically and increases the item total
   by `₱2`.
6. Open the add-on selector and confirm the automatic charge is not presented
   as a removable add-on.
7. Add a non-matching food product and confirm no `Paper Straw` charge is
   applied.
8. Confirm existing Auto Apply add-ons still appear selected by default and
   remain removable.
9. Complete an order and verify the automatic charge remains in the stored
   transaction/order data.
