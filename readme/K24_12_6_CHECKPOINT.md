# K24.12.6 — Barista/Kitchen Bottom Feed

## Change
Added a small trailing feed after Barista/Kitchen production copies so thermal receipt paper advances far enough for a clean tear/cut.

## PDF printing
- Added `_productionBottomFeedMm = 8.0`.
- Dynamic PDF page height includes the 8 mm production bottom feed when Barista or Kitchen content is present.
- Added an 8 mm trailing `SizedBox` after production copies.
- Customer-only receipts are unchanged.

## Bluetooth / ESC-POS printing
- Production copies now end with three newline feeds instead of one.
- Customer-only printing remains at one newline.

## Scope
Because the shared `KioskReceiptPrinter.printOrder()` and `KioskBluetoothPrinter.printOrder()` paths are used by checkout and Today's Transactions copy printing, the change applies to all affected Barista/Kitchen print instances.

## Preserved
- No changes to receipt content.
- No changes to variants/options.
- No changes to customer receipt spacing.
- No changes to cash drawer behavior.
