# K38 — Inventory Movement & Stock Operations

K38 extends the K37 local inventory projection with controlled manual stock operations.

## Operations
- Stock-in: positive quantity only.
- Adjustment: signed quantity; positive adds stock, negative reduces stock.
- Every manual movement requires a reason and may include a reference.
- Movement IDs are deterministic for retry/duplicate protection.
- Existing movement IDs are never overwritten.
- Local movement history is persisted separately from inventory item configuration.
- Sales-derived consumption remains separate and is not manually created by this UI.

## Stock projection
Current local projected stock is calculated as:

`Opening Quantity + Signed Local Movements`

The kiosk does not write authoritative stock balances to Supabase in K38.
