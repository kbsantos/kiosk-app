# K29 — Reporting Sync Reliability & Audit

K29 hardens the explicit EOD/reporting synchronization flow without changing
local kiosk transaction data.

## Reliability contract

- Local kiosk orders remain the source of truth.
- A transaction becomes synced only after the reporting RPC acknowledges it and
  the local snapshot acknowledgement is recorded.
- Failed transactions remain pending and are retried by the existing pending
  or full-sync actions.
- Partial syncs are safe: only acknowledged transactions become synced.
- Repeated syncs remain safe because `sync_kiosk_transaction` is idempotent.
- A failure writing audit metadata never changes the transaction sync result.

## Audit

Each explicit reporting sync attempt is retained locally under
`bigger_brew_kiosk.reporting_sync_audit.v1`, bounded to the newest 100 attempts.

A Supabase migration adds `reporting_sync_logs` and the
`record_kiosk_reporting_sync_log` RPC. A server audit failure is best effort and
never causes an otherwise successful transaction sync to be reported as failed.

A dedicated reporting table is used rather than assuming the shape of the
existing `sync_logs` table, avoiding an unsafe schema coupling.

## Scope protection

K29 does not add background sync, does not modify historical transactions, and
does not change checkout, payment, printer, local EOD PDF generation, or Store
Master catalog synchronization.
