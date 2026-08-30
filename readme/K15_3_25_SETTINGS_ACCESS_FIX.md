# K15.3.25 — Settings Access / Responsive Kiosk Fix

## Changes

- Restored the last-known-working hidden staff entry point:
  - Tap `BIGGER BREW` in the main header 5 times within 4 seconds.
  - Opens the current `KioskStaffGate` PIN dialog.
  - Default staff PIN remains `1234` on a fresh kiosk.
  - Opens `KioskStaffToolsPage` after successful authentication.
- Preserved the current Staff Tools navigation to:
  - Order Queue
  - Order History / EOD
  - Product Catalog
  - Kiosk Settings
- Kiosk Settings changes refresh the customer-facing kiosk when staff mode is exited.
- Preserved responsive menu behavior:
  - Landscape/tablet: 2 category columns.
  - Portrait: 2 category columns.
  - Portrait with cart items: order panel appears below the menu.
- Preserved store-open/store-closed behavior.
- Customer idle timeout is paused during staff authentication/staff mode and restarted when returning to customer kiosk.

## Verification on the kiosk

1. Launch the app.
2. Tap `BIGGER BREW` 5 times quickly.
3. Enter the staff PIN.
4. Open `KIOSK SETTINGS`.
5. Verify Store Status, Store Identity, Order Mode, Receipt Printer and Staff Access load.
6. Change a setting and return to the customer kiosk.
7. Verify the customer screen reflects the changed setting.
