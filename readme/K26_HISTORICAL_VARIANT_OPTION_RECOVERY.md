# K26 — Historical Variant & Option Recovery

## Purpose

Recover catalog definitions that are missing from the current Store Master catalog but are still provable from local kiosk transaction snapshots.

## Recovery rules

- Source data is the kiosk's local transaction history.
- Only products that still exist in the current Store Master catalog are considered.
- Existing variants, shared option definitions, and product option assignments are never overwritten.
- Missing variants are reconstructed from the historical variant ID, name, and price.
- Missing shared option definitions are reconstructed from historical option selections and the current product type(s).
- Missing product option assignments are reconstructed from historical option ID, name, price, and kitchen-prepared flag.
- Historical observations must be unambiguous before an automatic recovery is applied.
- Conflicting variant observations are left unchanged and reported for manual review.
- Conflicting option names/kitchen-prepared flags or product-specific option prices are left unchanged for the affected recovery item.
- Invalid/empty recovered IDs are not inserted.
- Missing products are not recreated by this feature.
- Recovered catalog records are created active so they can be used by the catalog after recovery.

## Publishing

Recovery is an explicit Store Master catalog mutation from the Catalog Management dashboard:

1. Load the current Store Master catalog.
2. Read local kiosk transactions.
3. Generate a recovery proposal.
4. Show recovered counts and conflicts.
5. Require administrator confirmation.
6. Save a local recovery backup.
7. Publish with the current Store Master version as the optimistic concurrency guard.
8. Adopt the accepted catalog version locally only after Store Master accepts it.

The existing K24 lost-response reconciliation remains in effect if the publish response is lost after a successful commit.

## Scope protection

This checkpoint does not alter historical transaction snapshots, transaction prices, totals, payment status, EOD local reporting, or XP-58H printer behavior.
