# K23.11.2 — Search Clear + Variant List Scroll Fix

## Changes

### Main menu search
- Added a `TextEditingController` to the employee order search field.
- Clear-search now clears both the search state and the visible text field.

### Product variant picker
- The variant picker remains a modal bottom sheet.
- The variant list is now inside a `ListView.separated` with a flexible height.
- The sheet is constrained to 86% of the available screen height.
- This keeps the bottom variants reachable on tablet landscape screens.
- Existing variant selection behavior is unchanged.

## Validation
Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Manual tablet checks
1. Main menu: search for a product, tap X, confirm the text disappears and all products return.
2. Create/use a product with many variants.
3. Open the variant picker in landscape.
4. Scroll the variant list and confirm the bottom variants can be reached and selected.
5. Confirm the selected variant still appears in cart/order/receipt/report flows.
