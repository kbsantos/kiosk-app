import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_restore_mapper.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  test('restores the camelCase database payload shape', () {
    final order = ReportingRestoreMapper.fromDatabasePayload({
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

    expect(order.id, 'RESTORE-001');
    expect(order.orderNumber, 'BB-009');
    expect(order.status.value, 'completed');
    expect(order.items.single.product.id, 'iced_americano');
    expect(order.items.single.product.name, 'Iced Americano');
    expect(order.items.single.size?.id, 'regular');
    expect(order.items.single.size?.price, 59);
    expect(order.items.single.options.single.id, 'espresso');
    expect(order.items.single.options.single.price, 20);
    expect(order.items.single.unitPrice, 79);
    expect(order.items.single.total, 79);
  });

  test('restores legacy snake_case database payloads', () {
    final order = ReportingRestoreMapper.fromDatabasePayload({
      'external_transaction_id': 'RESTORE-LEGACY',
      'order_number': 'BB-010',
      'transaction_date': '2026-09-16T11:00:00.000Z',
      'payment_method': 'Cash',
      'status': 'completed',
      'total': 50,
      'items': [
        {
          'product_id': 'liempo',
          'product_name': 'Liempo',
          'product_type': 'food',
          'category': 'rice_meals',
          'quantity': 1,
          'unit_price': 50,
          'total': 50,
          'options': [],
        },
      ],
    });

    expect(order.id, 'RESTORE-LEGACY');
    expect(order.orderNumber, 'BB-010');
    expect(order.paymentMethod, 'Cash');
    expect(order.items.single.product.id, 'liempo');
    expect(order.items.single.product.name, 'Liempo');
    expect(order.items.single.unitPrice, 50);
  });
}
