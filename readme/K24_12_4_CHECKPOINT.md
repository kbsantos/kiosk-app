# Bigger Brew Kiosk — K24.12.4 Checkpoint

## Change
Compact Barista and Kitchen receipt printing across all affected print paths.

## Scope
- PDF receipt generation in `lib/features/kiosk/pages/kiosk_receipt_printer.dart`
- Bluetooth ESC/POS receipt generation in `lib/features/kiosk/pages/kiosk_bluetooth_printer.dart`

## Behavior
- Removes blank feed lines before Barista and Kitchen copies on Bluetooth printing.
- Removes blank feed lines after Barista and Kitchen copies on Bluetooth printing.
- Uses content-driven PDF height for production-only copies instead of a fixed 70mm base.
- Production-only PDF copies have zero vertical page margin; horizontal 5mm margins are retained.
- Combined customer + production PDF keeps the customer receipt's existing 5mm page margin.
- Removes trailing item padding on the final Barista/Kitchen item so there is no artificial bottom gap.
- Keeps the separator lines and receipt content intact.
- Customer receipt content, variants, options/add-ons, settings flags, cash drawer behavior, and printer routing are unchanged.

## Verification
Flutter SDK is not available in the build environment used for this checkpoint. Run on the development Mac:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
```
