# K24.12 — Modify Transaction Order Details

## Change
The Modify Transaction dialog now allows staff to change:
- Order Type: Take Out / Dine In
- Payment: GCash / Cash / Others

The selected values are saved with the transaction and remain available to receipts, transaction views, and reports because they are stored on the KioskOrder.

## Existing behavior preserved
- Product quantity editing
- Remove products
- Add products
- Existing variants and options
- Modification reason/audit fields
- Post-save confirmation
- Today's Transactions and MODIFIED indicator
- Customer receipt / Barista / Kitchen printing flows

## Compatibility
Historical payment values outside GCash/Cash/Others are displayed as Others in the edit control rather than causing an invalid SegmentedButton selection. Historical order types other than Dine In default to Take Out in the editor.
