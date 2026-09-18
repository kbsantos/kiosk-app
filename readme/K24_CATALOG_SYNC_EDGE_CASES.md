# Kiosk 24 — Multi-Kiosk Catalog Sync Edge Cases

## Scope

Hardens the existing Store Master catalog publish flow for concurrent kiosk edits and network interruptions without changing the catalog data model or customer ordering flow.

## Behavior

- Store Master publication continues to use the database RPC's row lock and expected-version check.
- A kiosk with a stale expected version is rejected rather than overwriting newer Store Master content.
- If a publish RPC fails after the database may already have committed, the kiosk re-reads Store Master.
- The kiosk adopts the returned master catalog only when the complete catalog content matches the catalog it attempted to publish.
- If the master content differs, the original publish error is preserved as a genuine conflict.
- If reconciliation is unavailable because the kiosk is still offline, the original publish error is preserved.
- A successful RPC that returns no catalog version is not treated as safely committed.

## Verification

Flutter/Dart execution was not available in the implementation environment. Run `flutter analyze` and `flutter test` on the development machine before treating this checkpoint as validated.
