import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('copyWith changes only the order status', () {
    const product = KioskProduct(
      id: 'classic_milktea',
      name: 'Classic Milktea',
      price: 29,
      category: KioskCategory.milkTea,
      productType: 'drink',
    );

    final order = KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 16),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      paymentStatus: 'pending',
      status: KioskOrderStatus.pending,
      items: [],
      total: 29,
    );

    final updated = order.copyWith(
      status: KioskOrderStatus.preparing,
    );

    expect(updated.status, KioskOrderStatus.preparing);
    expect(updated.orderNumber, order.orderNumber);
    expect(updated.orderType, order.orderType);
    expect(updated.paymentMethod, order.paymentMethod);
    expect(updated.paymentStatus, order.paymentStatus);
    expect(updated.total, order.total);
    expect(product.name, 'Classic Milktea');
  });
}
