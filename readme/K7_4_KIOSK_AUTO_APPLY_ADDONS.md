# K7.4 — Kiosk Auto-Apply Add-ons

## Purpose

Consume the Store Management `ProductOption.autoApply` setting in the kiosk.

An auto-apply add-on is **selected by default but remains removable by the customer**. It is distinct from a mandatory automatic charge.

## Behavior

- `ProductOption.autoApply` defaults to `false` for backward compatibility.
- The kiosk catalog projection carries `autoApply` into `KioskCatalogOption`.
- If a product has both auto-apply and normal add-ons, the auto-apply options start checked in the add-on sheet.
- The customer can uncheck an auto-apply option before adding the product.
- If every assigned option is auto-apply, the kiosk adds the product directly with those options and does not open an add-on sheet.
- Existing non-auto-apply add-ons remain unchanged.
- The selected order option does not persist `autoApply` as a transaction attribute; it is a catalog configuration used to determine the initial selection.

## Validation

Run:

```bash
flutter analyze
flutter test
```

Manual verification should confirm a Store Master-synced product with `autoApply: true` is preselected in the kiosk and can still be removed.
