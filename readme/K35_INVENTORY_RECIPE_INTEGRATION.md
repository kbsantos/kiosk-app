# K35 — Inventory ↔ Catalog ↔ Recipe Integration

K35 establishes a kiosk-side integration contract for the separate inventory/recipe system.

## Ownership

- The Product Catalog owns commercial product identity and the optional `recipeRef`.
- The external Recipe/Inventory system owns recipe definitions and inventory item master data.
- The kiosk does not import Recipe Guide application classes or become an inventory system.
- Completed local kiosk orders are the source for expected consumption calculations.

## Scope

- Validate catalog `recipeRef` values against supplied recipe definitions.
- Validate recipe ingredient inventory references and quantities.
- Support base recipes and size/variant-scoped recipes.
- Calculate expected consumption for completed orders only.
- Ignore cancelled, pending, preparing, and ready orders.
- Keep unresolved recipe references visible instead of silently consuming inventory.

## Not included

- Direct inventory stock mutation.
- Automatic/background inventory synchronization.
- Changes to historical transaction amounts.
- Recipe Guide application dependencies.
