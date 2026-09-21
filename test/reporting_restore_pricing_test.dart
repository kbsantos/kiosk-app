import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_service.dart';

void main() {
  test(
    'database restore treats stored final unit price as base plus options',
    () {
      final service = ReportingSyncService();

      final order = service.restoreOrderFromDatabase({
        'external_transaction_id': 'RESTORE-OPTION-001',
        'transaction_date': '2026-09-17T09:45:46.288Z',
        'order_number': 'R-001',
        'order_type': 'Take Out',
        'payment_method': 'Pay at Counter',
        'payment_status': 'paid',
        'order_mode': 'Customer',
        'status': 'completed',
        'total': 85,
        'items': [
          {
            'product_id': 'cheeseburger',
            'product_name': 'Cheese Burger',
            'product_type': 'food',
            'category': 'burgers',
            // Database unit_price is the final unit price, including Takeout.
            'unit_price': 85,
            'quantity': 1,
            'total': 85,
            'options': [
              {
                'option_id': 'takeout_meal',
                'option_name': 'Takeout',
                'price': 5,
                'kitchen_prepared': false,
                'automatic': false,
              },
            ],
          },
        ],
      });

      final item = order.items.single;

      expect(item.product.price, 80);
      expect(item.options.single.price, 5);
      expect(item.unitPrice, 85);
      expect(item.total, 85);
      expect(order.total, 85);
    },
  );

  test(
    'database restore keeps a product without options at its stored unit price',
    () {
      final service = ReportingSyncService();

      final order = service.restoreOrderFromDatabase({
        'external_transaction_id': 'RESTORE-NO-OPTION-001',
        'transaction_date': '2026-09-17T10:00:00Z',
        'order_number': 'R-002',
        'order_type': 'Dine In',
        'payment_method': 'Cash',
        'payment_status': 'paid',
        'order_mode': 'Customer',
        'status': 'completed',
        'total': 85,
        'items': [
          {
            'product_id': 'liempo',
            'product_name': 'Liempo',
            'product_type': 'food',
            'category': 'riceMeals',
            'unit_price': 85,
            'quantity': 1,
            'total': 85,
            'options': [],
          },
        ],
      });

      final item = order.items.single;

      expect(item.product.price, 85);
      expect(item.unitPrice, 85);
      expect(item.total, 85);
      expect(order.total, 85);
    },
  );
}
