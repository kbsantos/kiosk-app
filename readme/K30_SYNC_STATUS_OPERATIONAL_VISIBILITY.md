# K30 — Sync Status & Operational Visibility

## Scope

K30 adds read-only operational visibility for the manual reporting sync flow.
The kiosk remains local-first: local transaction data is authoritative and cloud
synchronization is explicit/manual.

## Reporting status

The administration sync page now shows:

- total local transactions
- successfully acknowledged snapshots
- pending snapshots
- failed transactions from the latest sync attempt
- last successful sync time
- last sync attempt time
- latest recorded sync error
- a manual retry action for pending transactions
- local reporting sync audit history

The status is derived from the local `ReportingSyncStatusStore` and
`ReportingSyncAuditStore`; it does not require a cloud read.

## Retry behavior

`RETRY PENDING SYNC` invokes the existing idempotent full-sync path with
already-acknowledged snapshots excluded. Failed or changed snapshots therefore
remain eligible for a later manual retry.

## Audit history

`VIEW SYNC HISTORY` displays the locally retained explicit reporting sync audit
entries. It is informational only and does not modify transactions.

## Deliberate non-goals

- No background/automatic synchronization.
- No changes to checkout or payment behavior.
- No changes to EOD local PDF generation.
- No changes to catalog synchronization/version protection.
- No direct modification of historical transactions.
- No claim of live network connectivity is made from local sync metadata.

## Validation

The K30 regression suite adds pure-model coverage for synced, pending, failed,
and empty-transaction states. Flutter validation must be run in the project's
Flutter environment.
