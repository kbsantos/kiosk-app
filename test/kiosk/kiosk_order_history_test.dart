import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  KioskOrder makeOrder({
    required String id,
    required KioskOrderStatus status,
    required int total,
    String paymentStatus = 'pending',
  }) {
    return KioskOrder(
      id: id,
      orderNumber: id,
      createdAt: DateTime(2026, 8, 16, 10),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      paymentStatus: paymentStatus,
      status: status,
      items: const [],
      total: total,
    );
  }

  test('completed orders are distinct from active orders', () {
    final orders = [
      makeOrder(
        id: 'BB-001',
        status: KioskOrderStatus.completed,
        total: 59,
      ),
      makeOrder(
        id: 'BB-002',
        status: KioskOrderStatus.preparing,
        total: 89,
      ),
      makeOrder(
        id: 'BB-003',
        status: KioskOrderStatus.cancelled,
        total: 49,
      ),
    ];

    final completed = orders
        .where((order) => order.status == KioskOrderStatus.completed)
        .toList();

    expect(completed.length, 1);
    expect(completed.single.orderNumber, 'BB-001');
    expect(completed.single.total, 59);
  });

  test('completed sales total uses completed order totals only', () {
    final orders = [
      makeOrder(
        id: 'BB-001',
        status: KioskOrderStatus.completed,
        total: 59,
      ),
      makeOrder(
        id: 'BB-002',
        status: KioskOrderStatus.completed,
        total: 89,
      ),
      makeOrder(
        id: 'BB-003',
        status: KioskOrderStatus.preparing,
        total: 149,
      ),
    ];

    final sales = orders
        .where((order) => order.status == KioskOrderStatus.completed)
        .fold<int>(0, (sum, order) => sum + order.total);

    expect(sales, 148);
  });

  test('payment status is tracked separately from order completion', () {
    final order = makeOrder(
      id: 'BB-004',
      status: KioskOrderStatus.completed,
      total: 100,
      paymentStatus: 'pending',
    );

    expect(order.status, KioskOrderStatus.completed);
    expect(order.paymentStatus, 'pending');
  });
}
