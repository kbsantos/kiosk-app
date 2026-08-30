import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kitchen preparation flags are preserved in order JSON', () {
    const product = KioskProduct(
      id: 'hungarian_sausage_egg',
      name: 'Hungarian Sausage w/ Egg',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
      kitchenPrepared: true,
    );
    const option = KioskOption(
      id: 'extra_rice',
      name: 'Extra Rice',
      price: 20,
      kitchenPrepared: true,
    );
    const item = KioskCartItem(
      product: product,
      quantity: 1,
      options: [option],
    );

    final order = KioskOrder(
      id: 'test',
      orderNumber: '1042',
      createdAt: DateTime(2026, 8, 17, 8, 42),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      orderMode: 'Employee',
      status: KioskOrderStatus.completed,
      items: [item],
      total: 105,
    );

    final json = order.toJson();
    final itemJson = (json['items'] as List).single as Map;
    final optionJson = (itemJson['options'] as List).single as Map;

    expect(itemJson['kitchenPrepared'], isTrue);
    expect(optionJson['kitchenPrepared'], isTrue);
  });

  test('product catalog carries kitchen preparation metadata', () {
    final food = CatalogProduct.fromJson({
      'productId': 'hungarian_sausage_egg',
      'name': 'Hungarian Sausage w/ Egg',
      'productType': 'food',
      'categoryId': 'rice_meals',
      'active': true,
      'available': true,
      'kitchenPrepared': true,
      'sizes': const [],
      'variants': const [],
      'options': [
        {
          'optionId': 'extra_rice',
          'name': 'Extra Rice',
          'price': 20,
          'active': true,
          'kitchenPrepared': true,
        },
      ],
    });

    expect(food.kitchenPrepared, isTrue);
    expect(food.options.single.kitchenPrepared, isTrue);
  });
}
