# Reporting Sync

## DB-10A — Local Sync Status Tracking

The kiosk remains offline-first. Local `KioskOrder` records in SharedPreferences
remain the source of truth.

Successful reporting sync acknowledgements are stored separately under:

`bigger_brew_kiosk.reporting_sync_status.v1`

Each acknowledgement stores:

- external transaction ID
- successful sync timestamp
- exact serialized local order snapshot that was synced

### Why snapshots are tracked

An order is considered **synced** only when its current serialized snapshot
matches the snapshot acknowledged by Supabase.

If a staff action later modifies a local transaction, its snapshot changes and
it automatically becomes **pending** again. The next manual sync sends it to
the existing idempotent RPC.

### Safety rules

- DB-10A never modifies kiosk orders.
- DB-10A never modifies checkout or printer code.
- DB-10A has no automatic/background sync.
- Failed transactions remain pending.
- A successful RPC followed by a local metadata failure may retry later; this
  is safe because `sync_kiosk_transaction` is designed to UPSERT by external
  transaction ID.


## DB-10B — Production Manual Sync UI

`ReportingSyncPage` replaces the temporary validation entry in Staff Tools. It provides explicit staff actions for `SYNC PENDING TODAY` and `SYNC ALL PENDING`, plus local sync status for today and all stored transactions. No background sync is enabled.


### Kiosk identity mapping

The kiosk stores:
- `Store ID` = `stores.id` UUID
- `Device / Kiosk Code` = `devices.device_code` text (for example `KIOSK-00`)

Before calling `sync_kiosk_transaction`, the app resolves the active
`devices.id` UUID using the `resolve_kiosk_device` database RPC and the
configured Store ID + Device / Kiosk Code. The kiosk does not directly
SELECT from the RLS-protected `devices` table. The transaction RPC continues
to receive `p_device_id` as the required UUID.


### EOD behavior

The EOD page is local-first. VIEW PDF REPORT reloads the selected date from the
local kiosk repository and does not read from or synchronize the reporting
database. EMAIL PDF also generates its attachment from the same local order
snapshot and does not require cloud synchronization.

Cloud reporting synchronization is an explicit separate `SYNC TO REPORTING`
action on the EOD page. It uses the existing idempotent
`ReportingSyncService.syncAllTransactions()` flow. A sync failure does not
block local PDF generation or email preparation.


### EOD email setting

Kiosk Settings includes an `Enable EOD email` toggle. When disabled, the
EOD page keeps PDF generation available but disables the EMAIL PDF action.


If no EOD report email address is configured in Kiosk Settings, EOD email
buttons are hidden. If an address is configured but `Enable EOD email` is
turned off, the email action remains unavailable.


### Transaction restore

Administration Sync also provides `RESTORE MISSING TRANSACTIONS`. The kiosk
calls `get_kiosk_transactions_for_restore` for its configured Store ID and
Device / Kiosk Code. The database resolves the active `devices.id` and
returns transaction, item, and option snapshots.

The kiosk previews the count before writing anything. After confirmation it
only adds transactions whose `external_transaction_id` is not already stored
locally. Existing local transactions are never overwritten or deleted.


### Restore compatibility

Restore normalizes nullable reporting fields to safe kiosk defaults and
reconstructs size/variant/option snapshots from the reporting rows. The
reporting `external_transaction_id` is used as the local kiosk transaction ID.

## K29 — Reporting sync reliability and audit

Explicit reporting sync attempts now retain a bounded local audit trail. The
existing snapshot acknowledgement remains authoritative: only successful RPC
acknowledgements are marked synced, while failures remain pending for retry.
Partial and repeated syncs are safe because the reporting RPC is idempotent.

A dedicated Supabase `reporting_sync_logs` table and
`record_kiosk_reporting_sync_log` RPC provide server-side batch audit metadata.
Audit writes are best effort and never override the actual transaction sync
result.
