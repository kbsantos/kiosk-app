# K24.12.5 — Flush Barista/Kitchen Receipt Spacing

## Change
Removed artificial top/bottom PDF page margins from receipt printing. Horizontal 5mm content padding is retained inside the page.

## Scope
- Barista copy PDF/direct printing
- Kitchen copy PDF/direct printing
- Combined customer + Barista + Kitchen PDF path
- Bluetooth ESC/POS production copies remain flush with no blank feed lines between/after copies

## Compatibility fix
- `PdfPageFormat` now uses supported `marginAll: 0` instead of an unsupported `margin` parameter.
- Production padding uses `pw.EdgeInsets`.

## Preserved
- Receipt content
- Variants and add-ons
- Customer receipt behavior
- Cash drawer behavior
- Printer settings and copy flags
