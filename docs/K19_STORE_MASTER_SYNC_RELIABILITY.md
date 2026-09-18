# Kiosk 19 — Store Master Synchronization Reliability

## Scope

Kiosk 19 hardens catalog version integrity without changing ordering, checkout,
transactions, EOD reporting, or Bluetooth printer behavior.

## Changes

- Store Master catalog payload versions are checked against the authoritative
  version returned by `get_store_catalog_version` before the local cache is
  replaced.
- The accepted master version is normalized and used for the local catalog and
  synchronization version cache.
- Initial Store Master bootstrap now applies the newly returned master version
  to the local catalog before saving it. This keeps the catalog object's
  `catalogVersion` and the cached master-version preference aligned.
- Existing optimistic locking in `publish_store_catalog_from_kiosk` remains the
  final concurrency guard.
- Existing offline behavior remains local-first: automatic refresh failures do
  not replace the last known-good operational catalog.

## Regression coverage

`test/kiosk/catalog_sync_version_guard_test.dart` covers:

- matching versions;
- missing kiosk version;
- stale kiosk version;
- missing/empty master version;
- whitespace normalization;
- mismatched Store Master payload version;
- authoritative version application to a catalog snapshot.

## Verification limitation

The execution environment used to prepare this checkpoint does not have the
Flutter/Dart executables installed, so `flutter analyze` and `flutter test`
could not be executed here. Run both commands on the Flutter development
machine before accepting the checkpoint.
