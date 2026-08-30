# K24.12.12 — Monthly Sales PDF Report

## Status
Implemented in the supplied working kiosk codebase.

## Report sections

### Daily Sales
The monthly PDF groups completed transactions by calendar day and reports:

| Date | Drinks | Meals | Accessories | Total |
|---|---:|---:|---:|---:|

- Drinks, meals, and accessories are calculated from the transaction item `productType`.
- The `Total` column uses the completed order total.
- A monthly `TOTAL` row is included.

### Total Drink in Cups

The monthly PDF also reports drink quantities by day:

| Date | Hot 12oz | Iced 12oz | Iced 22oz | Iced 1L | Total |
|---|---:|---:|---:|---:|---:|

- Explicit `drinkTemperature` values are preserved.
- Historical drinks without a stored temperature use the existing compatibility logic:
  - Hot Coffee -> `hot`
  - Other legacy drinks -> `iced`
- Non-drink items are excluded.
- A `TOTAL CUPS` row is included.

## Navigation

The Monthly Report is available from the Order History screen through the **Monthly Report** toolbar button. The currently selected month is used.

## PDF

- A4 landscape.
- PDF preview supports printing and sharing.
- Filename format: `Bigger_Brew_Monthly_YYYY-MM.pdf`.

## Validation

The source change was applied to the supplied ZIP. Flutter validation should be run locally with:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
