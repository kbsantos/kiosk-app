import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('transaction modification fields survive JSON round trip', () {
    final product = KioskProduct(
      id: 'fries',
      name: 'French Fries',
      price: 95,
      category: KioskCategory.riceMeals,
      productType: 'food',
    );
    final order = KioskOrder(
      id: '1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 25, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      modificationReason: 'Customer requested one less serving',
      modifiedAt: DateTime(2026, 8, 25, 10, 5),
      items: [KioskCartItem(product: product, quantity: 1)],
      total: 95,
    );

    final restored = KioskOrder.fromJson(order.toJson());
    expect(restored.modificationReason, 'Customer requested one less serving');
    expect(restored.modifiedAt, order.modifiedAt);
  });

  test('transaction order details can be changed with copyWith', () {
    final product = KioskProduct(
      id: 'drink',
      name: 'Iced Coffee',
      price: 78,
      category: KioskCategory.coffee,
      productType: 'drink',
    );
    final order = KioskOrder(
      id: '2',
      orderNumber: 'BB-002',
      createdAt: DateTime(2026, 8, 27, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      status: KioskOrderStatus.completed,
      items: [KioskCartItem(product: product)],
      total: 78,
    );

    final updated = order.copyWith(
      orderType: 'Dine In',
      paymentMethod: 'GCash',
    );

    expect(updated.orderType, 'Dine In');
    expect(updated.paymentMethod, 'GCash');
    expect(updated.items, order.items);
    expect(updated.total, order.total);
  });
}
