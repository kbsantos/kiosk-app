import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/data/kiosk_menu_data.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';

void main() {
  group('Bigger Brew Kiosk clean baseline', () {
    test('contains the core kiosk categories', () {
      expect(KioskCategory.values, contains(KioskCategory.milkTea));
      expect(KioskCategory.values, contains(KioskCategory.riceMeals));
      expect(KioskCategory.values, contains(KioskCategory.accessories));
      expect(KioskCategory.values, contains(KioskCategory.addOns));
    });

    test('contains the nine Rice Meals', () {
      expect(KioskMenuData.riceMeals, hasLength(9));
    });

    test('contains the three Rice Meal add-ons', () {
      expect(KioskMenuData.riceMealAddOns, hasLength(3));
    });

    test('cart calculates product and add-on totals', () {
      const product = KioskProduct(
        id: 'test',
        name: 'Test Meal',
        price: 85,
        category: KioskCategory.riceMeals,
      );
      const addOn = KioskOption(
        id: 'egg',
        name: 'Egg',
        price: 15,
      );

      final cart = KioskCart();
      cart.add(product, options: const [addOn]);

      expect(cart.itemCount, 1);
      expect(cart.total, 100);

      cart.increment(0);
      expect(cart.itemCount, 2);
      expect(cart.total, 200);

      cart.decrement(0);
      expect(cart.itemCount, 1);
      expect(cart.total, 100);
    });

    test('unpriced products cannot be added', () {
      const product = KioskProduct(
        id: 'dark_chocolate',
        name: 'Dark Chocolate',
        price: null,
        category: KioskCategory.milkTea,
      );

      final cart = KioskCart();
      cart.add(product);

      expect(cart.itemCount, 0);
      expect(cart.total, 0);
    });

    test('neutral catalog has stable product IDs', () {
      final file = File(
        'assets/catalog/product_catalog.v4.commercial.json',
      );
      final catalog = jsonDecode(file.readAsStringSync())
          as Map<String, dynamic>;
      final products = catalog['products'] as List<dynamic>;
      final ids = products
          .map((e) => (e as Map<String, dynamic>)['productId'] as String)
          .toList();

      expect(ids.length, 77);
      expect(ids.toSet().length, ids.length);
    });
  });
}
