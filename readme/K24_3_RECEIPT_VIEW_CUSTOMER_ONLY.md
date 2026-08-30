# K24.3 — Receipt View / Print Customer Copy Only

## Change
The receipt view and its PRINT action now show/print only the customer receipt.

Barista and Kitchen production details/copies are no longer displayed on the receipt view and are not included when using the receipt page PRINT button.

## Preserved behavior
The checkout confirmation modal's dedicated **PRINT BARISTA** and **PRINT KITCHEN** actions remain unchanged. Those actions explicitly request their respective production copy.

The printer/PDF builder still supports customer, barista, and kitchen copies for explicit callers.

## Validation
Run:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then verify:
1. Open a completed order's receipt view.
2. Confirm no BARISTA COPY or KITCHEN COPY appears.
3. Tap PRINT from the receipt view.
4. Confirm only the customer receipt is sent/generated.
5. From checkout confirmation, verify PRINT BARISTA and PRINT KITCHEN still work when applicable.
