import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_transaction_mapper.dart';

void main() {
  test('reporting preserves a custom category after local order reload', () {
    final category = KioskCategory.fromCatalog(
      id: 'custom_drinks',
      title: 'Custom Drinks',
    );
    final order = KioskOrder(
      id: 'category-integrity-001',
      orderNumber: 'BB-CAT-001',
      createdAt: DateTime(2026, 9, 18, 10),
      orderType: 'Take Out',
      paymentMethod: 'Cash',
      status: KioskOrderStatus.completed,
      items: [
        KioskCartItem(
          product: KioskProduct(
            id: 'custom_drink',
            name: 'Custom Drink',
            price: 100,
            category: category,
          ),
        ),
      ],
      total: 100,
    );

    final reloaded = KioskOrder.fromJson(order.toJson());
    final payload = const ReportingTransactionMapper().mapOrder(
      order: reloaded,
      storeId: 'store-001',
      deviceId: 'device-001',
    );

    expect(payload.items.single['product_id'], 'custom_drink');
    expect(payload.items.single['category'], 'custom_drinks');
  });
}
