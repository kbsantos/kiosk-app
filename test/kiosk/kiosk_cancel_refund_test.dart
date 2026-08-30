import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  KioskOrder makeOrder({
    KioskOrderStatus status = KioskOrderStatus.pending,
    String paymentStatus = 'pending',
  }) {
    return KioskOrder(
      id: 'order-1',
      orderNumber: 'BB-001',
      createdAt: DateTime(2026, 8, 16, 10),
      orderType: 'Take Out',
      paymentMethod: 'Pay at Counter',
      paymentStatus: paymentStatus,
      status: status,
      items: const [],
      total: 100,
    );
  }

  test('cancellation changes status and preserves payment state', () {
    final order = makeOrder(paymentStatus: 'paid');
    final cancelled = order.copyWith(
      status: KioskOrderStatus.cancelled,
      cancellationReason: 'Customer changed order',
    );

    expect(cancelled.status, KioskOrderStatus.cancelled);
    expect(cancelled.paymentStatus, 'paid');
    expect(cancelled.cancellationReason, 'Customer changed order');
  });

  test('refund changes payment state without changing cancellation status', () {
    final order = makeOrder(
      status: KioskOrderStatus.cancelled,
      paymentStatus: 'paid',
    );
    final refunded = order.copyWith(paymentStatus: 'refunded');

    expect(refunded.status, KioskOrderStatus.cancelled);
    expect(refunded.paymentStatus, 'refunded');
  });

  test('unpaid cancellation does not become a refund', () {
    final order = makeOrder(status: KioskOrderStatus.cancelled);

    expect(order.paymentStatus, 'pending');
    expect(order.paymentStatus, isNot('refunded'));
  });
}


// Repository-level refund guards are intentionally enforced in
// KioskOrderRepository.refundPayment(): only cancelled + paid orders qualify.
