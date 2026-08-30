# Bigger Brew Kiosk — K23.4.1 Currency Configuration

## Change
Added a centralized kiosk currency setting and formatter.

Default:
- Code: PHP
- Symbol: ₱
- Name: Philippine Peso

Supported display currencies:
- PHP — ₱ — Philippine Peso
- USD — $ — US Dollar
- SGD — S$ — Singapore Dollar
- AUD — A$ — Australian Dollar
- JPY — ¥ — Japanese Yen

## Behavior
The setting is stored in SharedPreferences and loaded at app startup. Changing the setting updates the application display through the centralized currency notifier.

The currency is display-only. Prices are not converted.

## Unified formatting targets
- Customer cart / checkout
- Order panels / queues / history
- Category and catalog manager prices
- Receipts and reprints
- Bluetooth printer output (currency code for printer-safe ESC/POS output)
- EOD PDF
- EOD Excel export labels

## Validation status
Code changes prepared, but Flutter/Android validation has not been run in this environment.

Required local validation:

```bash
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Then validate currency switching on the Android tablet and confirm XP-58H printing remains unchanged.
