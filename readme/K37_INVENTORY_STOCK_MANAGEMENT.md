# K37 — Inventory Stock Management & Low-Stock Monitoring

K37 adds a kiosk-side stock-monitoring projection without making the kiosk the authoritative inventory system.

## Scope

- Local inventory item configuration: ID, name, unit, opening quantity, reorder level.
- Projected stock uses the K36 movement ledger: opening quantity + signed movements.
- Low-stock state is true when projected quantity is at or below the reorder level.
- Negative projected stock is surfaced for investigation; it is not silently clamped to zero.
- The staff inventory page is manager-only.
- No direct writes to the Supabase inventory tables are introduced because their authoritative schema is not established in the kiosk repository.
- No background synchronization is introduced.

## Boundary

The separate inventory system remains authoritative for real stock. K37 is a local operational projection and low-stock visibility layer only.
