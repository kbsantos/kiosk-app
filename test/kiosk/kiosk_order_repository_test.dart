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
}
