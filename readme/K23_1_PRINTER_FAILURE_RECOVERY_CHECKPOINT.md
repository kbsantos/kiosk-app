# K23.1 — Printer Failure & Recovery

## Status

Development complete; validation pending on the developer Mac and Android tablet.

## Changes

- Orders remain saved even when receipt printing is not confirmed.
- Bluetooth-configured printing no longer falls through to the system print dialog when the configured Bluetooth printer fails. This keeps the kiosk in a recoverable state.
- The order confirmation dialog now clearly reports printer failure.
- Added **RETRY PRINT** for failed Bluetooth printing.
- Retry uses the existing `KioskReceiptPrinter` / `KioskBluetoothPrinter` implementation and does not create another order.
- Retry shows a progress state while attempting to print.
- Existing **VIEW / REPRINT** remains available.
- System/direct-printer configurations retain their existing print-dialog fallback behavior.
- XP-58H Bluetooth connection, ESC/POS generation, 58mm receipt format, and printer setup were not replaced.

## Required validation

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then on the Samsung SM-P615:

1. Disconnect/power off the XP-58H.
2. Place an order.
3. Confirm the order is saved and the failure message appears.
4. Power/connect the XP-58H.
5. Tap **RETRY PRINT**.
6. Confirm the same order prints successfully.
7. Confirm no duplicate order is created.
8. Confirm Customer / Barista / Kitchen copies remain unchanged.

## Baseline protection

The K22.2 stable tablet release remains the rollback baseline until K23.1 is physically validated.
