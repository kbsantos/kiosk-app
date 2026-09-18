import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('order snapshot preserves size, options, and total', () {
    const product = KioskProduct(
      id: 'iced_americano',
      name: 'Iced Americano',
      price: null,
      category: KioskCategory.coffee,
      sizes: [
        KioskSize(
          id: 'regular',
          name: 'Regular',
          displayVolume: '12oz',
          price: 39,
        ),
      ],
    );

    final size = product.sizes.single;
    final item = KioskCartItem(
      product: product,
      size: size,
      options: const [
        KioskOption(
          id: 'espresso_shot',
          name: 'Espresso Shot',
          price: 20,
        ),
      ],
    );

    final order = KioskOrder(
      id: 'test-id',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 16, 9),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      status: KioskOrderStatus.pending,
      items: [item],
      total: item.total,
    );

    final restored = KioskOrder.fromJson(
      jsonDecode(jsonEncode(order.toJson())) as Map<String, dynamic>,
    );

    expect(restored.orderNumber, 'BB-001');
    expect(restored.items.single.size?.displayVolume, '12oz');
    expect(restored.items.single.options.single.name, 'Espresso Shot');
    expect(restored.total, 59);
    expect(restored.orderMode, 'Customer');
  });

  test('reporting restore snapshot reconstructs transaction items and options', () {
    final restored = KioskOrder.fromJson({
      'id': 'RESTORE-001',
      'orderNumber': 'BB-009',
      'createdAt': '2026-09-16T10:00:00.000Z',
      'orderType': 'Take Out',
      'paymentMethod': 'Pay at Counter',
      'paymentStatus': 'paid',
      'orderMode': 'Customer',
      'status': 'completed',
      'total': 79,
      'items': [
        {
          'productId': 'iced_americano',
          'productName': 'Iced Americano',
          'productType': 'drink',
          'drinkTemperature': 'iced',
          'category': 'coffee',
          'kitchenPrepared': false,
          'size': {
            'id': 'regular',
            'name': 'Regular',
            'volumeMl': 355,
            'displayVolume': '12oz',
            'price': 59,
          },
          'variant': null,
          'quantity': 1,
          'unitPrice': 79,
          'total': 79,
          'options': [
            {
              'id': 'espresso',
              'name': 'Espresso Shot',
              'price': 20,
              'kitchenPrepared': false,
            },
          ],
        },
      ],
    });

    expect(restored.id, 'RESTORE-001');
    expect(restored.status, KioskOrderStatus.completed);
    expect(restored.items.single.size?.id, 'regular');
    expect(restored.items.single.options.single.price, 20);
    expect(restored.items.single.total, 79);
  });

  test('order snapshot keeps base price separate from option prices', () {
    const product = KioskProduct(
      id: 'liempo',
      name: 'Liempo',
      price: 85,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );
    const option = KioskOption(
      id: 'one_rice',
      name: 'One Rice',
      price: 20,
    );

    final item = KioskCartItem(
      product: product,
      options: const [option],
    );
    final order = KioskOrder(
      id: 'pricing-roundtrip',
      orderNumber: 'BB-PR-001',
      createdAt: DateTime(2026, 9, 18, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      status: KioskOrderStatus.completed,
      items: [item],
      total: 105,
    );

    final encoded = order.toJson();
    expect(encoded['items'].single['basePrice'], 85);
    expect(encoded['items'].single['unitPrice'], 105);

    final once = KioskOrder.fromJson(encoded);
    final twice = KioskOrder.fromJson(once.toJson());
    final thrice = KioskOrder.fromJson(twice.toJson());

    expect(once.items.single.unitPrice, 105);
    expect(twice.items.single.unitPrice, 105);
    expect(thrice.items.single.unitPrice, 105);
    expect(thrice.items.single.product.price, 85);
  });

  test('legacy snapshot derives base price once instead of re-adding options', () {
    final legacy = KioskOrder.fromJson({
      'id': 'legacy-pricing',
      'orderNumber': 'BB-PR-LEGACY',
      'createdAt': '2026-09-17T10:00:00.000Z',
      'orderType': 'Take Out',
      'paymentMethod': 'Cash',
      'status': 'completed',
      'total': 105,
      'items': [
        {
          'productId': 'liempo',
          'productName': 'Liempo',
          'productType': 'food',
          'category': 'rice_meals',
          'quantity': 1,
          'unitPrice': 105,
          'total': 105,
          'options': [
            {
              'id': 'one_rice',
              'name': 'One Rice',
              'price': 20,
              'kitchenPrepared': true,
            },
          ],
        },
      ],
    });

    expect(legacy.items.single.product.price, 85);
    expect(legacy.items.single.unitPrice, 105);
    expect(legacy.items.single.total, 105);
  });

}
