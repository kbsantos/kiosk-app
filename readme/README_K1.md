# Bigger Brew Kiosk — Sprint K1 Base

This is the clean K1 baseline.

## K1 scope

- Customer-facing kiosk home
- Category grid
- Product cards
- Basic product selection
- Cart
- Quantity controls
- Rice Meals
- Rice Meal add-ons

## Categories

- Milk Tea
- Fruit Tea
- Coffee
- Chocolate
- Rice Meals
- Burgers
- Merienda
- Add-ons

Only Rice Meals are populated in K1.

Existing RecipeRepository/MenuRepository integration is intentionally **not included**. That belongs to Sprint K2.

## Rice Meals

- Hungarian Sausage w/ Egg — ₱85
- Liempo — ₱85
- Lechon Kawali — ₱85
- Sisig — ₱85
- Fried Chicken — ₱80
- Bacon & Egg — ₱80
- Spam & Egg — ₱80
- Burger Steak — ₱70
- Chicken Pastil — ₱70

## Rice Meal Add-ons

- Extra Rice — ₱20
- Garlic Mayo Dip — ₱10
- Egg — ₱15

## Launching the kiosk

```dart
import 'package:bigger_brew_barista/features/kiosk/kiosk_page.dart';

Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const KioskHomePage(),
  ),
);
```

## Next sprint

Sprint K2 will connect the kiosk to the existing Bigger Brew menu/repository system.


## Historical baseline note

This document describes the original K1 foundation and is retained as historical documentation. The current kiosk has progressed beyond K1 and now includes checkout, local order persistence, payment status, staff access, printing, End-of-Day reporting, Excel export, and Employee Order Mode with a 30-minute staff session. See the main `README.md` for the current implementation status.
