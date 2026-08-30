# K23.9.1 — Option Product Type Health Check Fix

## Issue
Catalog Health Check reported:

`Option uses invalid product type: food`

for valid option definitions such as `one_rice` with `productTypes: ["food"]`.

## Cause
`CatalogValidator` had an empty `if` block and called the validation error outside the condition, so every option product type was reported as invalid — including `drink`, `food`, `accessory`, and `addOn`.

## Fix
The validator now reports `invalid_option_product_type` only when the type is NOT one of:

- `drink`
- `food`
- `accessory`
- `addOn`

## Regression coverage
Added tests confirming:

- `food` is accepted for `one_rice`.
- An unknown product type still produces the expected validation error.

## Validation
Flutter itself was not available in the packaging environment. Run locally:

```bash
flutter pub get
flutter analyze
flutter test
```
