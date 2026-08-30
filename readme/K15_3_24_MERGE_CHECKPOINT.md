# K15.3.24 — Working Project Merge Checkpoint

Status: MERGED INTO SUPPLIED WORKING KIOSK — runtime verification pending.

The supplied working kiosk ZIP was used as the base. K15.3 catalog-management source was merged into that base, with compatibility adapters retained for the existing staff tools.
## K15.3.24 FIX8 — Category Visibility Sync

- Fixed customer kiosk category rendering so inactive categories are not shown.
- `KioskCatalogData` now projects only `ProductCategory.active == true` categories.
- Kiosk home now renders the categories returned by the active catalog projection instead of all hardcoded `KioskCategory.values`.
- Result: disabling a category such as **Merienda** in Category Manager removes it from the customer kiosk instead of displaying an empty `Coming soon` tile.
- No change to product-level availability behavior.
- Flutter/Dart CLI is not installed in the provided environment, so local `flutter analyze` / `flutter test` remains required.
