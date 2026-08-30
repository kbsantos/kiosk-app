# K15.3.25 Order Icon / Portrait Fix

## Changes

- Removed the inline `KioskOrderPanel` from the portrait `KioskHomePage`.
- The portrait home screen now keeps the full menu visible and scrollable.
- The kiosk menu remains limited to 2 columns in tablet portrait and landscape.
- The AppBar shopping-cart/order icon opens `KioskCartPage`.
- Added `YOUR ORDER` tooltip to the order icon.
- Preserved the cart item-count badge.
- Preserved the 5-tap `BIGGER BREW` staff access flow.
- Removed the now-unused home-page `KioskOrderPanel` import and checkout helper.

## Test

1. Launch the kiosk.
2. Add a product.
3. Confirm the menu remains visible with no order panel at the bottom.
4. Confirm the cart icon shows the item-count badge.
5. Tap the cart icon.
6. Confirm `YOUR ORDER` opens and the added product is listed.
7. Confirm quantity +/- and delete controls work.
