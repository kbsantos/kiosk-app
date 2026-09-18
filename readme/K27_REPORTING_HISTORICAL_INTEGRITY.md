# K27 — Reporting Validation & Historical Data Integrity

## Scope

K27 adds a read-only local reporting integrity layer. It validates the
historical transaction snapshot before reporting and provides deterministic
category, product, variant, and option/add-on sales aggregates using the
kiosk EOD rule that only `completed` orders contribute to sales totals.

## Rules

- Cancelled, pending, preparing, and ready orders are excluded from sales
  aggregates.
- The stored order total must equal the sum of its persisted item totals.
- Category and product totals use the transaction item's persisted snapshot.
- Variant totals use the persisted transaction item total for that variant.
- Option/add-on totals use the persisted option price multiplied by the item
  quantity.
- Historical orders without a catalog version remain reportable and are
  counted as legacy catalog-version orders.
- No historical transaction is modified by the integrity analyzer.

## Regression coverage

Tests cover:

1. category + product + variant + option preservation;
2. cancelled transactions excluded from sales;
3. order-total mismatch detection without mutation;
4. legacy orders without a catalog version remaining reportable.

This checkpoint does not change the XP-58H printer flow, checkout/payment,
local EOD PDF data source, or Store Master catalog synchronization behavior.
