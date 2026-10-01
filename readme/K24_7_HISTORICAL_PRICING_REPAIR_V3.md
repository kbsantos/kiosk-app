# K24.7 Historical Transaction Pricing Repair v3

## Purpose

Manual repair of corrupted historical `transaction_items.unit_price` and `transaction_items.total` values caused by legacy kiosk pricing/reload behavior.

## v3 change

The previous v2 script failed on PostgreSQL because it used `max(jsonb)`. v3 replaces that aggregation with `array_agg(...)[1]` for the single-solution case.

The repair also uses historical transaction pricing evidence and exact reconciliation against the existing `transactions.total`.

## Safety

- `transactions.total` is never changed.
- `transaction_item_options` is never changed.
- Only `SAFE_REPAIR` transactions are updated.
- Ambiguous and no-match transactions are left untouched.
- The script ends with `ROLLBACK`.
- Review the previews before changing `ROLLBACK` to `COMMIT`.
