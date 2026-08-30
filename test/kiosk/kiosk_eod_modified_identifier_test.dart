import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('modified transaction is identifiable from modification fields', () {
    final order = KioskOrder(
      id: '1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 25, 10),
      orderType: 'Take Out',
      items: const [],
      total: 0,
      paymentMethod: 'Cash',
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
      modificationReason: 'Customer requested one less item',
      modifiedAt: DateTime(2026, 8, 25, 10, 5),
    );

    expect(order.modificationReason, isNotNull);
    expect(order.modifiedAt, isNotNull);
  });
}
