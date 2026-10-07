import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('customer name survives local transaction JSON reload', () {
    final order = KioskOrder.fromJson({
      'id': 'order-1',
      'orderNumber': 'BB-001',
      'customerName': 'Kris Santos',
      'createdAt': '2026-10-02T10:00:00.000',
      'orderType': 'Take Out',
      'paymentMethod': 'Cash',
      'status': 'completed',
      'total': 120,
      'items': <dynamic>[],
    });

    expect(order.customerName, 'Kris Santos');
    expect(order.toJson()['customerName'], 'Kris Santos');
  });

  test('blank customer name normalizes to null when reloading', () {
    final order = KioskOrder.fromJson({
      'id': 'order-2',
      'orderNumber': 'BB-002',
      'customerName': '   ',
      'createdAt': '2026-10-02T10:00:00.000',
      'orderType': 'Take Out',
      'paymentMethod': 'Cash',
      'status': 'completed',
      'total': 0,
      'items': <dynamic>[],
    });

    expect(order.customerName, isNull);
  });
}
