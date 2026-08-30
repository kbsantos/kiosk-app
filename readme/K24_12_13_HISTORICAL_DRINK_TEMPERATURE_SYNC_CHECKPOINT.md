# K24.12.13 — Historical Drink Temperature Synchronization

## Status
Implemented on top of the supplied K24.12.12 monthly-report codebase.

## Purpose
Historical transactions created before `drinkTemperature` was stored can be synchronized with the current Product Catalog so EOD and Monthly Drink Summary reports can classify cups consistently.

## Synchronization rules

- Only transaction items with `productType = drink` are considered.
- Existing explicit `drinkTemperature = hot` or `iced` values are preserved.
- Missing or invalid historical temperatures are filled from the current catalog product matched by `productId`.
- If the current catalog has no valid `hot`/`iced` value, the application default `iced` is persisted.
- Product prices, names, sizes, variants, options, and other historical transaction snapshots are not replaced by current catalog values.
- The migration is idempotent; running it again does not change already synchronized values.

## Staff access

Staff Mode now includes:

**SYNC HISTORICAL DRINKS**

The action first performs a dry-run preview showing how many historical drink items/orders need updating. Staff can then confirm the synchronization.

## Data safety

The migration edits only the stored `drinkTemperature` field in affected transaction item JSON. It does not recalculate order totals or rewrite historical pricing.

## Validation

Flutter CLI was not available in the build environment used to prepare this ZIP, so `flutter analyze` / `flutter test` could not be executed here. Run locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
