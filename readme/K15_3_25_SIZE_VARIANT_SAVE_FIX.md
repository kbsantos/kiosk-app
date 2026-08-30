# K15.3.25 — Size & Variant Save Fix

Updated `lib/features/catalog/product_size_variant_manager.dart`.

## Fixes
- SAVE now validates size/variant forms before closing the dialog.
- Size/variant IDs entered during ADD are normalized to lowercase stable IDs.
- Spaces and punctuation are converted to underscores.
- If the ID is blank during ADD, it is generated from the Name.
- Required name validation is shown directly in the dialog.
- Invalid volume and price values are shown directly in the dialog.
- Negative prices are rejected.
- Duplicate IDs are still rejected by the manager and reported after SAVE.
- Fixed the malformed `showDialog` closing syntax in `_editVariant`.
- Existing checkout and portrait order-icon changes are preserved from K15.3.25 checkout-fix.

Examples:
- `Regular` -> `regular`
- `Go Big` -> `go_big`
- `Go-Bigger` -> `go_bigger`
- blank ID + name `Regular` -> `regular`
