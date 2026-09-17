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

## Store master catalog

Apply `migrations/20260916_store_master_catalog.sql` to create the store-level
master catalog for categories, products, sizes, variants, option definitions,
and product option assignments.

The kiosk uses `get_store_catalog_version` and `get_store_catalog` to pull the
master catalog. `initialize_store_catalog_from_kiosk` is a one-time bootstrap
operation that is accepted only when the store has no master catalog yet.

The kiosk's local `ProductCatalog` remains the operational copy. Catalog
administration will be migrated to database-master writes before automatic
background refresh is enabled.

## REST reporting API — Phase 1

Apply `migrations/20260917_rest_reporting_api_phase1.sql` to enable the
store-scoped Supabase PostgREST reporting API. See
`readme/BIGGER_BREW_REST_API_PHASE1.md` for endpoint and authentication details.

The migration exposes read-only reporting endpoints and four reporting views.
It does not expose Store Master Catalog tables and does not change the existing
kiosk transaction sync RPCs.

## Store Master Catalog Phase 2

Catalog administration writes are database-mastered through:

`20260917_store_master_catalog_phase2_writes.sql`

The kiosk identifies itself with Store ID + active Kiosk Code and publishes the complete catalog through `publish_store_catalog_from_kiosk`. The RPC uses optimistic version checking and atomically replaces the store catalog. The local kiosk catalog is updated only after the master write succeeds.
