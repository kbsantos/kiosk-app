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
