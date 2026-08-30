# K24.12.11 — Legacy Drink Temperature Compatibility

## Purpose
Keep the new `drinkTemperature` field consistent with historical transactions that were saved before the field existed.

## Behavior
- Explicit `hot` remains `hot`.
- Explicit `iced` remains `iced`.
- Legacy drink records with no stored temperature are inferred as:
  - `hot` for the existing Hot Coffee identifiers (`Hot Coffee` name/group, `hot_coffee` group ID, or `hot_` product ID).
  - `iced` for other legacy drinks, matching the new default.
- Non-drink products remain `null`.

## Important
This does not change the stored catalog or rewrite every historical order on startup. The compatibility value is applied while historical orders are loaded, so EOD/monthly reports and transaction views can use one consistent `drinkTemperature` value. Existing explicit values are never overwritten.
