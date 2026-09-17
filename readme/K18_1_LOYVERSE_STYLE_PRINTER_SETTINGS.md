# K18.1 — XP-58H Printer Settings UX

## Goal

Align the Bigger Brew kiosk printer settings with the provided Loyverse reference while keeping the implementation focused on the XP-58H Bluetooth thermal printer.

## Implemented

- Printer name and model fields (XP-58H).
- Interface selector (Bluetooth / System printer).
- Bluetooth SEARCH flow using paired devices.
- Selected Bluetooth printer and MAC address persistence.
- FORGET printer action.
- 58 mm / 80 mm paper-width setting.
- Advanced printing switches persisted locally.
- Bluetooth TEST PRINT using native ESC/POS text.
- Bluetooth checkout receipt path using ESC/POS when Bluetooth is selected.
- Kitchen-copy printing can be enabled/disabled through Print orders.
- System printer remains available as a fallback/development path.

## XP-58H behavior

The XP-58H is treated as a 58 mm Bluetooth thermal printer. The test print intentionally does not send an automatic cutter command.

## Settings behavior

- **Print receipts and bills**: controls whether an automatic receipt is printed.
- **Automatically print receipt**: controls automatic receipt printing after order creation.
- **Print orders**: controls the kitchen-copy portion of the printed ticket.
- **Print single item per order ticket** and **Group identical items in order tickets** are persisted as printer workflow settings for the next ticket-formatting iteration.

## Validation

Run on the development machine:

```bash
flutter pub get
flutter analyze
flutter test
```

Then pair XP-58H in Android Bluetooth settings and use:

`Staff Mode -> Kiosk Settings -> Receipt Printer -> SEARCH -> XP-58H -> PRINT TEST`

Direct physical printing must be validated on the actual Android kiosk device.
