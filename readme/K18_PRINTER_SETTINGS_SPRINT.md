# K18 — Printer Settings Sprint

## Scope

Printer configuration is now part of the kiosk Staff Settings flow.

### Implemented

- Discover printers exposed by the `printing` package.
- Persist a selected printer by platform printer URL plus display name.
- Keep 58mm / 80mm paper-size selection.
- Add a **TEST PRINT** action in Receipt Printer settings.
- Checkout/reprint uses the configured printer when direct printing is available.
- If the configured printer is unavailable, the existing manual print-dialog fallback remains available.
- Receipt PDF width now follows the saved 58mm / 80mm setting.
- First-run compatibility remains: when no printer is configured and exactly one/default printer is available, it may still be used automatically.

## Staff Settings UI

`STAFF MODE → KIOSK SETTINGS → RECEIPT PRINTER`

- Printer selector
- Refresh printers
- Selected printer
- Clear selection
- Paper size
- Test Print

## Validation

The development container used for this checkpoint does not have the Flutter/Dart CLI installed, so `flutter analyze` and Flutter tests could not be executed here. Run these on the development Mac/device:

```bash
flutter analyze
flutter test
```

For physical validation, confirm that the test receipt prints to the selected receipt printer before enabling normal kiosk checkout.
