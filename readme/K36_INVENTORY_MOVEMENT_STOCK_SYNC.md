# K36 — Inventory Movement & Stock Synchronization

K36 establishes the kiosk-side movement contract between completed sales and the separate inventory system.

## Rules
- Consumption is derived only from completed local kiosk orders.
- Cancelled/pending/preparing/ready orders produce no consumption movement.
- Each consumption movement has a deterministic ID based on order/item/ingredient identity.
- Retrying movement generation is idempotent through movement-ID deduplication.
- Stock-in and adjustment movements are explicit and are not inferred from sales.
- Stock summaries apply signed movements to an opening quantity.
- Historical transaction records are not modified.
- The kiosk does not become the authoritative inventory database.
- No background synchronization is introduced in K36.

## Boundary

`Completed local order -> inventory movement facts -> inventory system`

The authoritative inventory system can later consume these movement records through its own synchronization API/database process. No database migration is included in K36 because the exact inventory movement schema is external to the kiosk codebase.
