# Store Master Catalog Management

## Goal
Move catalog administration mutations to a database-master workflow while keeping the kiosk local catalog as the operational cache.

## Global constraints
- Store Master is authoritative for catalog administration mutations.
- Mutations use optimistic version protection and must not overwrite a newer Store Management catalog.
- Local kiosk catalog is updated only after the Store Master write succeeds.
- Existing local-first ordering, checkout, EOD, and XP-58H Bluetooth printer behavior must remain unchanged.
- Existing one-time master initialization and explicit catalog refresh remain available.

## Tasks
1. Move Category Manager mutations to Store Master first and add regression coverage.
2. Move Product Manager mutations to Store Master first and add regression coverage.
3. Move Size/Variant and Product Category Assignment mutations to Store Master first and add regression coverage.
4. Move Product Option Manager mutations to Store Master first and add regression coverage.
5. Verify the full catalog-manager flow and release regression suite.
