# K25 — Historical Catalog Snapshot / Versioning

## Purpose

Prevent future catalog changes from silently changing the meaning of an existing kiosk transaction.

## Implementation

- Each newly created `KioskOrder` captures the local Store Master catalog version at checkout.
- The transaction already stores an item-level snapshot of product name/type, category, size, variant, drink temperature, base/unit price, quantity, and selected options.
- The new order-level `catalogVersion` identifies which local catalog version was active when the transaction was created.
- Legacy transactions remain readable and have a null catalog version.
- If catalog metadata cannot be loaded during checkout, checkout is not blocked and the version remains null rather than inventing a version.
- Transaction modification preserves the original order catalog version.
- No current catalog data is consulted when an existing order is deserialized, so historical item snapshots remain independent of later catalog edits.

## Scope protection

This checkpoint does not change the XP-58H Bluetooth printer, checkout pricing, payment flow, EOD local reporting, or Store Master synchronization behavior.

## Verification

K24 was previously validated by the user with the full Flutter test suite and analyzer. K25 source changes were prepared with regression tests. Flutter is not installed in the current execution environment, so K25 itself must be validated with `flutter analyze` and `flutter test` on the development machine before being marked validated.
