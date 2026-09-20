import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  final category = KioskCategory.fromCatalog(
    id: 'snacks',
    title: 'Snacks',
    icon: '🍟',
  );
  const variant = KioskVariant(
    id: 'cheese',
    name: 'Cheese',
    price: 95,
  );
  final product = KioskProduct(
    id: 'french_fries',
    name: 'French Fries',
    category: category,
    price: 90,
    variants: [variant],
  );

  test('displayLabel includes selected variant and options', () {
    final item = KioskCartItem(
      product: product,
      variant: variant,
      options: [
        KioskOption(id: 'ketchup', name: 'Ketchup', price: 5),
      ],
    );

    expect(item.displayLabel, 'French Fries — Cheese — Ketchup');
  });

  test('selected variant survives order JSON round trip', () {
    final item = KioskCartItem(
      product: product,
      variant: variant,
    );
    final order = KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-0001',
      createdAt: DateTime(2026, 8, 23, 10),
      orderType: 'Dine In',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      items: [item],
      total: item.total,
    );

    final restored = KioskOrder.fromJson(order.toJson());
    expect(restored.items.single.variant?.id, 'cheese');
    expect(restored.items.single.variant?.name, 'Cheese');
    expect(restored.items.single.displayLabel, 'French Fries — Cheese');
  });
}
