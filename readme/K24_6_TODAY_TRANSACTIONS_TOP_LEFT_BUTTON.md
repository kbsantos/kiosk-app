# K24.6 — Today's Transactions Top-Left Button

## Change
Added a receipt/list icon button to the top-left corner of the customer kiosk main menu.

## Behavior
- Opens **Today's Transactions** (`KioskTransactionViewPage`) directly.
- No Staff PIN/login is required for this shortcut.
- Keeps the kiosk idle timeout paused while the transaction page is open, then restarts it when returning to the customer kiosk.
- The existing Staff Mode and its PIN protection remain unchanged.
- Does not change the existing printer, receipt, checkout, catalog, or transaction logic.

## UI
Tooltip: `TODAY'S TRANSACTIONS`
Icon: `Icons.receipt_long_outlined`
