# Milestone — Store Management Transition / Kiosk Cleanup

## Status

Phase 5 cleanup completed after live validation of Store Management catalog publishing, kiosk catalog synchronization, and offline local catalog operation.

## Store Management owns

- Product Catalog administration
- Categories
- Products
- Sizes and variants
- Options / add-ons
- Sales reporting
- Store administration (future)
- Kiosk/device administration (future)

## Kiosk retains

- Local catalog cache
- Automatic master catalog synchronization
- Customer ordering
- Employee Order Mode
- Checkout/payment
- Bluetooth printing
- EOD
- Transaction synchronization
- Transaction restore
- Kiosk settings
- Administration Sync

## Removed from kiosk UI/source

The legacy kiosk-side catalog management screens and the old reporting UI were removed after the Store Management replacement was validated. The reporting synchronization service remains because it is still used by kiosk EOD and Administration Sync.

## Safety rule

Do not remove or replace the local ProductCatalogRepository or StoreCatalogSyncService. The kiosk must continue operating from its last known-good local catalog when the database is unavailable.
