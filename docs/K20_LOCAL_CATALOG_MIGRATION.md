# Kiosk 20 — Existing Local Catalog → Store Master Migration

## Scope

Protect migration of an existing local kiosk catalog into Store Master. The kiosk remains local-first for operations, while Store Master is authoritative for catalog synchronization.

## Safety rules

- A local catalog with zero products cannot initialize or replace Store Master.
- Existing Store Master versioning and optimistic concurrency remain authoritative.
- A local catalog with a known matching master version can publish explicit local changes.
- If local and master catalog content is already identical, the explicit sync is treated as a no-op and does not create an unnecessary master write.
- A failed master operation does not change the local operational catalog.

## Complete catalog payload

The migration uses the existing `ProductCatalog.toJson()` contract, preserving categories, products, sizes, variants, option definitions, and product-option assignments together with product metadata and pricing.

## Database defense in depth

`20260918_store_master_catalog_migration_safety.sql` updates the bootstrap RPC to reject malformed payloads, unsupported schema versions, catalogs without categories, and catalogs without products before any rows are inserted.
