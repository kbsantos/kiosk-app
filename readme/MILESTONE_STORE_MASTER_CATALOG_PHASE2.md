# Bigger Brew — Store Master Catalog Phase 2

## Objective

Make Supabase the database master for catalog administration while keeping the kiosk's local ProductCatalog as its operational cache.

## Implemented

- Added `StoreCatalogMasterService` for database-master catalog reads/writes.
- Catalog administration now loads from the store master instead of starting from local-only overrides.
- Categories, products, sizes, variants, product-category assignments, shared option definitions, and product option assignments publish the complete catalog to the master before the local cache is updated.
- Added `publish_store_catalog_from_kiosk(store_id, device_code, expected_version, catalog)` RPC.
- Publish validates the active store/device pairing and uses optimistic version checking to prevent stale editors from overwriting newer master changes.
- Master replacement is atomic inside the database transaction.
- A successful master write returns a new server-generated catalog version; only then is the local operational catalog updated.
- Catalog loading/refresh validates the master payload before saving it locally.
- Catalog Manager Dashboard now reflects the store master catalog.

## Required deployment step

Run:

`supabase/migrations/20260917_store_master_catalog_phase2_writes.sql`

in the MyCoffeeShop Supabase SQL Editor.

## Operational sequence

1. Administration Sync: initialize the master catalog once if the store does not have one.
2. Catalog Management: open Categories, Products, Sizes & Variants, or Options.
3. The page loads the current store master catalog.
4. A save validates the complete catalog and publishes it through the secure REST/RPC endpoint.
5. Supabase commits the master catalog atomically and increments the master version.
6. The kiosk saves the accepted catalog as its local operational cache.
7. Other kiosks can detect the changed master version and refresh through the Phase 1 catalog sync workflow.

## Safety rules

- Existing transaction sync, EOD, restore, and printer workflows are not changed by this phase.
- Inventory remains a separate system.
- Transaction history is not rewritten when catalog metadata changes.
- A failed master write does not update the local catalog.
- A stale catalog save is rejected instead of silently overwriting a newer master.
- The kiosk identifies itself using the configured Store ID and Kiosk Code; it does not directly read the `devices` table.

## Not yet enabled

Automatic/background catalog refresh is intentionally still not enabled globally. The next phase can enable version checks/refresh at controlled kiosk lifecycle points now that catalog administration writes are database-mastered.
