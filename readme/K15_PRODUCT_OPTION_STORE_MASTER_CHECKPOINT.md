# K15 Product Option Store Master Checkpoint

## Scope

Migrates the Product Options / Add-ons management flow to Store Master authority.

## Changes

- Product Option Manager reads Store Master first, with local catalog fallback for offline/read-only access.
- Shared option definition add/edit/delete operations publish through `StoreCatalogMasterService.mutateCatalog()`.
- Product-specific option assignment/edit/removal operations publish through Store Master.
- Local kiosk catalog state is replaced only with the catalog accepted by Store Master.
- Product option edits operate on the current Store Master product so unrelated product fields and concurrent option assignments are preserved.
- Shared option deletion checks the current Store Master catalog before removing an option.
- Product option assignments require a corresponding Store Master option definition.
- Assignment uses the current Store Master definition values for name, price, active state, and kitchen-prepared state.

## Regression coverage

`test/kiosk/product_option_store_master_test.dart` covers:

- Shared option mutation through Store Master.
- Product option assignment through Store Master.
- Preservation of current Store Master product changes during shared-option edits.
- Preservation of current product fields and other option assignments during product-option edits.
- Shared option deletion protection while assigned.

## Verification note

The execution environment used to prepare this checkpoint does not contain the Flutter/Dart executables, so `flutter analyze` and `flutter test` could not be executed here. The checkpoint should be verified locally with:

```bash
flutter analyze
flutter test
```
