# K7.8 — Automatic Charge Reporting Contract

This checkpoint makes the mandatory automatic-charge flag explicit in the
Supabase transaction option contract and preserves it during database-to-kiosk
transaction restore.

## Changes

- Adds `transaction_item_options.automatic boolean not null default false`.
- Existing transactions therefore remain normal/selectable options unless the
  stored row explicitly has `automatic = true`.
- Updates `get_kiosk_transactions_for_restore(uuid, text)` to include the
  `automatic` flag in every restored option.
- Keeps the existing kiosk reporting mapper contract unchanged; it already
  sends `automatic` in each option payload.
- Does not change kiosk printing, checkout, or Auto Apply behavior.

## Migration

Apply:

`supabase/migrations/20260920_automatic_charge_reporting_contract.sql`

## Validation

Run:

```bash
flutter analyze
flutter test
```

Then verify a database restore of an order containing an automatic charge:
`automatic` must remain `true` after restore.
