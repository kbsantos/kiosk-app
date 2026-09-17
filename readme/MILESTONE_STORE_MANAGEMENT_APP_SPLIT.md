# Bigger Brew Store Management — Kiosk Boundary Transition

## Status

The customer-facing kiosk is transitioning to a focused operational role. Product Catalog administration and sales Reporting are moving to the separate **Bigger Brew Store Management** Flutter application.

## Kiosk keeps

- Customer ordering
- Employee Order Mode
- Order Queue
- Order History / EOD
- Administration Sync for transaction/reporting maintenance
- Catalog refresh/synchronization from the Supabase Store Master Catalog
- Kiosk Settings
- Printing and existing operational workflows

## Moved to Store Management

- Product Catalog administration
- Categories
- Products
- Sizes and variants
- Options / add-ons
- Product/category assignment
- Catalog validation
- Sales Reporting

## Local catalog cache

The kiosk continues to keep a local operational catalog. Removing the Product Catalog management menu does **not** remove the local catalog or catalog synchronization.

Supabase remains the master catalog and the kiosk downloads a validated copy for local operation.

## Transition safety

The legacy kiosk catalog management source files are intentionally retained in this transition checkpoint for rollback/reference. Only the Staff Mode entry point is removed. They should be deleted in a later cleanup checkpoint after Store Management catalog workflows have been fully validated on the target devices.
