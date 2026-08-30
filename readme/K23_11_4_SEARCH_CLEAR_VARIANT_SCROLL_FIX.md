# K23.11.4 — Search Clear + Variant Scroll Fix

## Changes

- Fixed the employee-order search clear button so it explicitly resets the
  visible `TextEditingController` value as well as the filter state.
- Preserved live product/category search behavior.
- Preserved the landscape-friendly scrollable product variant picker.
- Fixed the unmatched closing parenthesis in the rice-meal add-on sheet that
  caused `flutter analyze` to report an `expected_token` error around the
  `_ProductVariantSheet` declaration.
- No printer/Bluetooth/ESC-POS code was changed.

## Validation

Flutter CLI is not installed in this execution environment, so `flutter analyze`
and `flutter test` could not be executed here. Run them locally before building:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```
