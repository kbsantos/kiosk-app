# Bigger Brew Kiosk Supabase

## Reporting kiosk identity

Apply `migrations/20260916_resolve_kiosk_device.sql` before using the
reporting sync from the kiosk.

The kiosk stores:
- Store ID = `stores.id` UUID
- Device / Kiosk Code = `devices.device_code` text

The `resolve_kiosk_device` RPC resolves the active `devices.id` UUID without
granting the kiosk direct SELECT access to the RLS-protected `devices` table.

The existing `sync_kiosk_transaction` RPC remains responsible for writing
the transaction and receives `p_device_id` as the resolved UUID.

## Transaction restore

`get_kiosk_transactions_for_restore(store_id, device_code)` resolves the
active device server-side and returns transaction/item/option snapshots for
that exact Store + Kiosk. The kiosk compares `external_transaction_id` with
its local order IDs and only adds missing transactions. Existing local orders
are never overwritten or deleted.
