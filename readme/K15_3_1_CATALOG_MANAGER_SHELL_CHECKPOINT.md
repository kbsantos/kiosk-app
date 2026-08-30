# K15.3.1 — Catalog Manager Shell Checkpoint

## Status
Implemented the K15.3.1 Catalog Management shell.

## Changes
- Added `KioskCatalogManagerPage` under `lib/features/kiosk/staff/`.
- Added catalog overview cards for active categories, active products, available products, and options.
- Added management entry points for Categories, Products, Options & Add-ons, and Catalog Safety.
- Connected the Staff Tools `PRODUCT CATALOG` entry to the new Catalog Management page.
- Existing product browser remains available from the Products/BROWSE action.
- Added a widget test for the manager shell.

## Safety
- No catalog mutation is performed in K15.3.1.
- No customer ordering flow was changed.
- Existing commercial catalog remains the source of truth.
- Category/product editors are intentionally deferred to K15.3.2+.

## Verification
Flutter CLI is not available in this packaging environment, so `flutter analyze` and `flutter test` must be run in the user's local Flutter project.

Recommended commands:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```
