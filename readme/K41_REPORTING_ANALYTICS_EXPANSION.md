# K41 — Reporting & Analytics Expansion

K41 extends the local kiosk sales dashboard without changing the local-first architecture.

## Included

- Daily sales buckets.
- Monday-based weekly sales buckets.
- Monthly sales totals.
- Current-period vs immediately preceding equal-length period sales comparison.
- Percentage change with an explicit zero-baseline rule.
- `THIS MONTH` reporting preset.
- Copyable CSV-style report data for external spreadsheet/reporting use.

## Reporting boundary

The dashboard aggregates persisted local kiosk transaction snapshots and completed orders only. It does not query or mutate Supabase. Cross-store and cross-device analytics remain a reporting-database responsibility.

## Validation

K40.2 was the validated baseline with 225 tests passing and no analyzer issues. Flutter verification for K41 must be run in the developer environment before K41 is marked validated.
