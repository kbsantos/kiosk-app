# K40.1 — Advanced Sales Reporting Dashboard Compile Fix

Based on validated K39.

Fixes the K40 compile error by restoring the dashboard's local currency helper:
`String _peso(num value) => KioskCurrency.format(value);`

The existing `KioskCurrency` import is therefore used and is retained.

No dashboard calculation, data source, reporting, checkout, EOD, catalog, inventory, or printer behavior was changed.

Validation required on a Flutter environment:
- `flutter analyze`
- `flutter test`
