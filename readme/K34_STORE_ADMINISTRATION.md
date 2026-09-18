# K34 — Store Administration

## Baseline
K34 starts from the validated K32.3/K33 lineage and preserves the kiosk local-first architecture.

## Added
- Manager-only Store Administration entry from Staff Mode.
- Store list loaded from the authoritative `stores` table.
- Store name/address editing and active/inactive state.
- New store creation.
- Active-device safety guard: a store with active kiosk devices cannot be deactivated from this workflow.
- Store administration audit rows in `store_administration_audit`.
- Pure validation/rules tests for normalization, identity conflicts, and deactivation safety.

## Authority boundaries
- `stores` remains authoritative for store records.
- `devices` remains authoritative for kiosk/device lifecycle.
- Catalog remains authoritative in Store Master.
- Local kiosk transactions are never modified by Store Administration.
- Store Administration does not publish or overwrite catalogs.
- Store Administration does not restore transactions.

## Supabase
Apply:
`supabase/migrations/20260919_store_administration_audit.sql`

The migration only creates the audit table. The existing `stores` and `devices` tables remain the source tables.

## Important schema assumption
The existing `stores` table is expected to expose `name`, `address`, and `is_active` columns. The application already references `stores.id` and `devices.store_id` throughout the sync/recovery architecture. If the live Store table uses different display/address column names, the service mapping should be adjusted to the live schema before production deployment.

## Verification
Flutter/Dart is not installed in the build environment used to package this checkpoint, so Flutter verification is pending local execution.
