import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('historical category sync updates local items to current product category', () async {
    SharedPreferences.setMockInitialValues({
      'bigger_brew_catalog_categories_v1': jsonEncode([
        {
          'categoryId': 'coffee',
          'name': 'Coffee',
          'subtitle': '',
          'active': true,
        },
        {
          'categoryId': 'merienda',
          'name': 'Merienda',
          'subtitle': '',
          'active': true,
        },
        {
          'categoryId': 'accessories',
          'name': 'Accessories',
          'subtitle': '',
          'active': true,
        },
      ]),
      'bigger_brew_catalog_products_v1': jsonEncode([
        {
          'productId': 'DRINK-001',
          'name': 'Iced Spanish Latte',
          'productType': 'drink',
          'categoryId': 'coffee',
          'active': true,
          'available': true,
          'sizes': [],
          'variants': [],
          'options': [],
        },
        {
          'productId': 'FOOD-001',
          'name': 'Cookies',
          'productType': 'food',
          'categoryId': 'merienda',
          'active': true,
          'available': true,
          'sizes': [],
          'variants': [],
          'options': [],
        },
      ]),
      'bigger_brew_kiosk.orders.v1': [
        jsonEncode({
          'id': 'CATEGORY-001',
          'orderNumber': 'BB-001',
          'createdAt': DateTime(2026, 8, 23, 10).toIso8601String(),
          'orderType': 'Take Out',
          'paymentMethod': 'Cash',
          'paymentStatus': 'paid',
          'status': 'completed',
          'total': 200,
          'items': [
            {
              'productId': 'DRINK-001',
              'productName': 'Iced Spanish Latte',
              'productType': 'drink',
              'category': 'accessories',
              'categoryName': 'Accessories',
              'quantity': 1,
              'unitPrice': 120,
              'total': 120,
              'options': [],
            },
            {
              'productId': 'FOOD-001',
              'productName': 'Cookies',
              'productType': 'food',
              'category': 'accessories',
              'categoryName': 'Accessories',
              'quantity': 1,
              'unitPrice': 80,
              'total': 80,
              'options': [],
            },
          ],
        }),
      ],
    });

    final repository = KioskOrderRepository();

    final preview = await repository.syncHistoricalTransactionCategories(
      dryRun: true,
    );

    expect(preview.updatedOrders, 1);
    expect(preview.updatedItems, 2);

    final prefsBeforeApply = await SharedPreferences.getInstance();
    final rawBeforeApply =
        prefsBeforeApply.getStringList('bigger_brew_kiosk.orders.v1')!.single;
    final beforeItems = (jsonDecode(rawBeforeApply)['items'] as List).cast<Map>();
    expect(beforeItems[0]['category'], 'accessories');
    expect(beforeItems[1]['category'], 'accessories');

    final result = await repository.syncHistoricalTransactionCategories();
    expect(result.updatedOrders, 1);
    expect(result.updatedItems, 2);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bigger_brew_kiosk.orders.v1')!.single;
    final items = (jsonDecode(raw)['items'] as List).cast<Map>();

    expect(items[0]['category'], 'coffee');
    expect(items[0]['categoryName'], 'Coffee');
    expect(items[1]['category'], 'merienda');
    expect(items[1]['categoryName'], 'Merienda');
    expect(items[0]['productName'], 'Iced Spanish Latte');
    expect(items[0]['unitPrice'], 120);
    expect(items[0]['total'], 120);

    final second = await repository.syncHistoricalTransactionCategories(
      dryRun: true,
    );
    expect(second.updatedItems, 0);
    expect(second.updatedOrders, 0);
  });

  test('historical category sync skips cancelled orders and unknown products', () async {
    SharedPreferences.setMockInitialValues({
      'bigger_brew_catalog_categories_v1': jsonEncode([
        {
          'categoryId': 'coffee',
          'name': 'Coffee',
          'subtitle': '',
          'active': true,
        },
        {
          'categoryId': 'accessories',
          'name': 'Accessories',
          'subtitle': '',
          'active': true,
        },
      ]),
      'bigger_brew_catalog_products_v1': jsonEncode([
        {
          'productId': 'DRINK-001',
          'name': 'Iced Spanish Latte',
          'productType': 'drink',
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
          'id': 'CANCELLED',
          'status': 'cancelled',
          'items': [
            {
              'productId': 'DRINK-001',
              'productName': 'Iced Spanish Latte',
              'category': 'accessories',
              'categoryName': 'Accessories',
            },
          ],
        }),
        jsonEncode({
          'id': 'UNKNOWN-PRODUCT',
          'status': 'completed',
          'items': [
            {
              'productId': 'REMOVED-001',
              'productName': 'Removed Product',
              'category': 'accessories',
              'categoryName': 'Accessories',
            },
          ],
        }),
      ],
    });

    final repository = KioskOrderRepository();
    final result = await repository.syncHistoricalTransactionCategories();

    expect(result.updatedOrders, 0);
    expect(result.updatedItems, 0);
    expect(result.skippedItems, 1);

    final prefs = await SharedPreferences.getInstance();
    final rawOrders = prefs.getStringList('bigger_brew_kiosk.orders.v1')!;
    final cancelled = jsonDecode(rawOrders[0]) as Map<String, dynamic>;
    final unknown = jsonDecode(rawOrders[1]) as Map<String, dynamic>;

    expect((cancelled['items'] as List).single['category'], 'accessories');
    expect((unknown['items'] as List).single['category'], 'accessories');
  });
}
