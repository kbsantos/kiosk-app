import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  test('drink cart items default to 100% sugar', () {
    final product = KioskProduct(
      id: 'drink-1',
      name: 'Test Drink',
      price: 100,
      category: KioskCategory.coffee,
      productType: 'drink',
    );

    final cart = KioskCart();
    cart.add(product);

    expect(cart.items.single.sugarLevel, 100);
  });

  test('non-drinks do not receive a sugar level', () {
    final product = KioskProduct(
      id: 'food-1',
      name: 'Test Food',
      price: 100,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );

    final cart = KioskCart();
    cart.add(product);

    expect(cart.items.single.sugarLevel, isNull);
  });
}
