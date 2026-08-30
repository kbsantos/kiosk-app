# K18 Bluetooth Printer Setup Checkpoint

## Target hardware

- Printer: XP-58H
- Paper: 58mm
- Intended connection: Bluetooth thermal / ESC-POS

## Implemented in this checkpoint

- Added `print_bluetooth_thermal: ^1.2.2` dependency.
- Added `KioskBluetoothPrinter` service.
- Added paired Bluetooth printer loading.
- Added Bluetooth enabled/permission status handling.
- Added Bluetooth printer selection and connection.
- Persisted Bluetooth printer name/address.
- Added saved printer connection type (`bluetooth` or `system`).
- Added connection check and clear controls in Kiosk Settings.
- Changed the default kiosk receipt paper size from 80mm to 58mm for the XP-58H.
- Kept the existing system/PDF printer implementation intact.

## Important setup requirement

The XP-58H must first be paired with the kiosk device using the device's Bluetooth settings. The app currently reads paired printers; it does not perform general Bluetooth discovery.

## Not yet implemented

- ESC/POS receipt byte generation for the actual order receipt.
- Direct Bluetooth receipt printing during checkout.
- Bluetooth reprint path.
- Physical XP-58H test print.
- Automatic reconnect during checkout.

Those are the next K18 implementation steps.
