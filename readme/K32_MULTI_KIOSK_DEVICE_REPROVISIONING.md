# K32 — Multi-Kiosk Device Replacement / Re-Provisioning

## Scope

K32 adds a controlled local re-provisioning workflow for a replacement kiosk.
The replacement device must already be registered and active in Store
Management.

## Workflow

1. Open Administration Sync.
2. Verify the replacement Store ID and Device / Kiosk Code.
3. The kiosk checks the target against `devices` using the existing read-only
   recovery RPC.
4. Only an active registered target can be applied.
5. The local reporting identity is updated to the verified target.
6. The remembered catalog master version is cleared so the replacement kiosk
   cannot publish a stale local catalog.
7. The kiosk attempts a forced refresh from Store Master.
8. If the refresh fails, the new identity remains but catalog publishing stays
   protected until a successful refresh establishes a current master version.

## Safety boundaries

- No `devices` records are created, deleted, or modified by the kiosk.
- The old device is not automatically deactivated. Store Management owns that
  lifecycle operation.
- No local transactions are deleted or restored.
- No reporting transactions are reassigned.
- Catalog recovery and transaction recovery remain separate workflows.
- Historical transaction snapshots remain unchanged.

## Tests

K32 adds pure tests for replacement-plan validation and requires the normal
Flutter analyzer/test suite before becoming a validated checkpoint.
