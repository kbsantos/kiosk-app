# Historical Drink Temperature Sync

## Purpose
Synchronize the `drinkTemperature` stored on historical transaction drink
items with the current product catalog. This keeps historical EOD and monthly
drink-cup reporting aligned when a product's catalog temperature changes.

## Resolution rules
1. If the transaction item is a drink and its product still exists in the
   current catalog, the current catalog temperature (`hot` or `iced`) wins.
2. If the catalog does not define a valid temperature, the product defaults to
   `iced`.
3. If the product no longer exists in the catalog, an already-valid historical
   `hot`/`iced` value is preserved. Missing legacy values fall back to `iced`.
4. Meals and accessories are never assigned a drink temperature.

## Why existing values may change
Transactions created after `drinkTemperature` was introduced can contain the
default `iced` value even when the catalog did not explicitly specify Iced.
Because the stored value alone cannot distinguish that default from an explicit
choice, the historical sync treats the current catalog as the source of truth
for the product's drink temperature.

## Safety
Only `drinkTemperature` is changed. The migration does not recalculate or
modify prices, product names, sizes, variants, options, quantities, totals,
payment information, order dates, or other transaction fields.

The operation supports a dry-run preview and is idempotent: once historical
items match the current catalog, running the sync again produces zero updates
until the catalog changes again.
