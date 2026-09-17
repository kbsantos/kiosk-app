# Bigger Brew Kiosk — K15.2 Catalog Manager

## Status
Implemented — Catalog Browser UI.

## Added
- Staff Mode -> Product Catalog entry.
- Catalog loading through ProductCatalogRepository.
- Product search by name, product ID, or SKU.
- Category filter.
- Active-only filter.
- Product count.
- Active/available/kitchen-prepared status chips.
- Price/size summary.
- Reload catalog action.
- Safe placeholder for K15.3 editing; K15.2 does not mutate catalog data.
- Unit tests for catalog filtering.

## Architecture
The Product Catalog remains the source of truth. KioskCatalogData already loads the catalog through ProductCatalogRepository, and the adapter projects catalog products into the customer kiosk.

## Next
K15.3 — Add/Edit Product.

## K15.2.1 Hotfix — Catalog Load Compatibility

### Issue
The kiosk failed during catalog load with:
`FormatException: Product classic_milktea references unknown category milk_tea.`

### Root cause
The bundled commercial catalog contained valid product `categoryId` values but the `categories` array was missing. The repository validator correctly rejected those product references.

### Fix
- Added the explicit 13-category catalog definition to `assets/catalog/product_catalog.v4.commercial.json`.
- Added backward-compatible category derivation in `ProductCatalog.fromJson()` for older/local catalogs that omit `categories`.
- Added a regression test covering a legacy catalog with no categories array.
- No customer ordering, recipe, pricing, or staff workflow behavior was changed.

### Verification
Flutter CLI is not installed in this environment, so `flutter test` / `flutter analyze` could not be executed here. JSON structure and source changes were inspected locally.
