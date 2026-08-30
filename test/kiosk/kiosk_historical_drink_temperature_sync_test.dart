import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('historical sync fills missing temperatures and preserves matching explicit values',
      () async {
    SharedPreferences.setMockInitialValues({
      'bigger_brew_catalog_products_v1': jsonEncode([
        {
          'productId': 'DRINK-001',
          'name': 'Hot Coffee',
          'productType': 'drink',
          'drinkTemperature': 'iced',
          'categoryId': 'coffee',
          'active': true,
          'available': true,
          'sizes': [],
          'variants': [],
          'options': [],
        },
        {
          'productId': 'DRINK-002',
          'name': 'Iced Coffee',
          'productType': 'drink',
          'drinkTemperature': 'hot',
          'categoryId': 'coffee',
          'active': true,
          'available': true,
          'sizes': [],
          'variants': [],
          'options': [],
        },
      ]),
      'bigger_brew_kiosk.orders.v1': [
        jsonEncode({
          'id': '1',
          'orderNumber': 'BB-001',
          'createdAt': DateTime(2026, 8, 1, 10).toIso8601String(),
          'orderType': 'Take Out',
          'paymentMethod': 'Cash',
          'paymentStatus': 'paid',
          'status': 'completed',
          'total': 100,
          'items': [
            {
              'productId': 'DRINK-001',
              'productName': 'Hot Coffee',
              'productType': 'drink',
              'drinkTemperature': null,
              'category': 'drinks',
              'quantity': 1,
              'unitPrice': 100,
              'total': 100,
              'options': [],
            },
            {
              'productId': 'DRINK-002',
              'productName': 'Iced Coffee',
              'productType': 'drink',
              'drinkTemperature': 'hot',
              'category': 'drinks',
              'quantity': 1,
              'unitPrice': 0,
              'total': 0,
              'options': [],
            },
          ],
        }),
      ],
    });

    final repository = KioskOrderRepository();
    final preview =
        await repository.syncHistoricalDrinkTemperatures(dryRun: true);

    expect(preview.updatedOrders, 1);
    expect(preview.updatedItems, 1);

    // A legacy transaction with a missing stored temperature is exposed by
    // KioskOrder as its legacy compatibility value until the sync is applied.
    // Verify the dry run did not persist anything by checking the raw record.
    final prefsBeforeApply = await SharedPreferences.getInstance();
    final rawBeforeApply =
        prefsBeforeApply.getStringList('bigger_brew_kiosk.orders.v1')!.single;
    final beforeApplyData =
        (jsonDecode(rawBeforeApply)['items'] as List).cast<Map>();
    expect(beforeApplyData[0]['drinkTemperature'], isNull);
    expect(beforeApplyData[1]['drinkTemperature'], 'hot');

    final result = await repository.syncHistoricalDrinkTemperatures();
    expect(result.updatedItems, 1);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bigger_brew_kiosk.orders.v1')!.single;
    final itemData = (jsonDecode(raw)['items'] as List).cast<Map>();
    expect(itemData[0]['drinkTemperature'], 'iced');
    expect(itemData[1]['drinkTemperature'], 'hot');
  });
}
