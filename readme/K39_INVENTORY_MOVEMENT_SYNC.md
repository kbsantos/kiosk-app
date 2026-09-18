# K39 — Inventory Movement Synchronization & Operational Audit

## Status
IMPLEMENTED — Flutter runtime verification pending

## Scope
K39 adds explicit synchronization of the kiosk's local inventory movement ledger to the existing Supabase inventory movement table.

## Contract
- Local `InventoryMovement.id` is the stable kiosk movement identity.
- Supabase creates its own `inventory_movements.id` UUID.
- `kiosk_inventory_movement_sync` maps the local movement ID to the server movement ID.
- A `(store_id, local_movement_id)` unique constraint prevents duplicate server movements.
- Failed movements are not marked locally as synced and remain retryable.
- The sync RPC processes movements individually so one invalid movement does not discard successful movements in the same batch.
- Existing inventory `usage` movement semantics are preserved; kiosk `stockIn` maps to `stock_in`, and adjustments map to `adjustment`.

## Safety boundaries
- The kiosk never writes stock balances directly.
- Checkout is not blocked by inventory synchronization.
- EOD reporting remains independent of inventory synchronization.
- Local movements remain available when offline.
- Synchronization is manual; no background sync is introduced.
- The existing inventory system remains authoritative for inventory balances.

## Administration
Administration Sync now shows inventory movement synchronization status and provides an explicit `SYNC INVENTORY MOVEMENTS` action.

## Supabase migration
`supabase/migrations/20260919_kiosk_inventory_movement_sync.sql`

The migration uses the existing `inventory_movements` contract observed in the project database material: `id`, `store_id`, `inventory_item_id`, `movement_type`, `quantity`, `reason`, `reference_id`, and `created_at`.

## Verification
Run:

```text
flutter analyze
flutter test
```

K38.1 baseline: 217 tests. K39 adds 4 regression tests, so the expected total is 221 tests.
