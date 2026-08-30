import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  KioskOrder makeOrder({
    String paymentStatus = 'pending',
    KioskOrderStatus status = KioskOrderStatus.completed,
  }) {
    return KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 16, 10),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      paymentStatus: paymentStatus,
      orderMode: 'Employee',
      status: status,
      items: const [],
      total: 100,
    );
  }

  test('payment status can be changed without changing order status', () {
    final order = makeOrder();
    final paid = order.copyWith(paymentStatus: 'paid');

    expect(order.status, KioskOrderStatus.completed);
    expect(paid.status, KioskOrderStatus.completed);
    expect(order.paymentStatus, 'pending');
    expect(paid.paymentStatus, 'paid');
  });

  test('a paid order remains paid when status changes', () {
    final order = makeOrder(paymentStatus: 'paid');
    final ready = order.copyWith(status: KioskOrderStatus.ready);

    expect(ready.paymentStatus, 'paid');
    expect(ready.status, KioskOrderStatus.ready);
  });


  test('employee order mode can represent paid and completed immediately', () {
    final order = makeOrder(
      paymentStatus: 'paid',
      status: KioskOrderStatus.completed,
    );
    expect(order.paymentStatus, 'paid');
    expect(order.status, KioskOrderStatus.completed);
    expect(order.orderMode, 'Employee');
  });
}
