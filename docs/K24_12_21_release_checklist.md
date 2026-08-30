# Bigger Brew K24.12.21 Release Cleanup

## Confirmed functional areas
- Product management
- Product variants
- Product options/add-ons
- `drinkTemperature` with Iced default
- Historical drink-temperature synchronization
- Today's Transactions
- Transaction modification and reason
- Adding products to existing transactions
- Receipt view/printing
- Barista and Kitchen copies
- Receipt paper spacing/feed
- EOD Daily Sales
- EOD Accessories Daily Summary
- EOD Drink Summary — Cups
- Monthly PDF Report
- Hot/Iced drink cup reporting

## Intentionally paused
- User Roles

## Final local verification
Run on the development machine:
1. `flutter clean`
2. `flutter pub get`
3. `flutter analyze`
4. `flutter test`
5. Build and test the APK on the production tablet.
6. Verify the XP-58H Bluetooth printer and drawer behavior before release.

No database migration is performed by this cleanup checkpoint.
