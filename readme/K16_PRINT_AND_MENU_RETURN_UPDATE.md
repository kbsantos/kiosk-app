# K16 — Direct Print + Return-to-Main-Menu Update

## Checkout printing

- Checkout now attempts `Printing.directPrintPdf()` when the platform exposes direct printing.
- The operating-system default printer is preferred automatically.
- If the kiosk has exactly one available printer, that printer is used automatically.
- If direct printing is unavailable, the existing print dialog is used as a fallback. This is required for Flutter Web/browser printing because browsers do not permit silent printer selection.
- The checkout flow no longer intentionally opens the receipt page as the normal print step.

## Reprint

The `ORDER RECEIVED` dialog now includes:

- `VIEW / REPRINT` — opens the existing receipt printout page for manual reprinting.
- `DONE` — continues the normal customer/employee order flow.

If the initial print is not confirmed, the dialog explicitly tells the operator to use `VIEW / REPRINT`.

## Add-to-order navigation

After an item is successfully added, including:

- drinks with add-ons,
- rice meals with add-ons,
- sized drinks,
- variants,
- products without options,

the category page automatically returns to the BIGGER BREW main menu.

The item remains in the shared cart, so the cart badge/order remains intact.
