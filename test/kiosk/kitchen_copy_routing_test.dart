import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';
import 'package:bigger_brew_kiosk/features/kiosk/printing/kiosk_production_copy_rules.dart';

void main() {
  const category = KioskCategory.coffee;

  KioskProduct product({
    required String id,
    required String name,
    required String productType,
    bool kitchenPrepared = false,
  }) {
    return KioskProduct(
      id: id,
      name: name,
      price: 100,
      category: category,
      productType: productType,
      kitchenPrepared: kitchenPrepared,
    );
  }

  KioskOrder orderWith(List<KioskCartItem> items) {
    return KioskOrder(
      id: 'test-order',
      orderNumber: 'BB-TEST',
      createdAt: DateTime(2026, 10, 8),
      orderType: 'Dine In',
      paymentMethod: 'Cash',
      status: KioskOrderStatus.pending,
      items: items,
      total: items.fold(0, (sum, item) => sum + item.total),
    );
  }

  test(
    'drink with a non-kitchen Pearl add-on stays off the kitchen copy',
    () {
      final drink = KioskCartItem(
        product: product(
          id: 'drink',
          name: 'Cheesecake',
          productType: 'drink',
        ),
        options: const [
          KioskOption(
            id: 'pearl',
            name: 'Pearl',
            price: 20,
            automatic: false,
            kitchenPrepared: false,
          ),
        ],
      );

      final meal = KioskCartItem(
        product: product(
          id: 'meal',
          name: 'Chicken Pasta',
          productType: 'food',
          kitchenPrepared: true,
        ),
      );

      final kitchenItems =
          KioskProductionCopyRules.kitchenItems(orderWith([meal, drink]));

      expect(kitchenItems, contains(meal));
      expect(kitchenItems, isNot(contains(drink)));
    },
  );

  test(
    'a non-kitchen product is routed to the kitchen when its selected add-on is kitchen-prepared',
    () {
      final drink = KioskCartItem(
        product: product(
          id: 'drink',
          name: 'Cheesecake',
          productType: 'drink',
        ),
        options: const [
          KioskOption(
            id: 'extra',
            name: 'Kitchen Extra',
            price: 20,
            automatic: false,
            kitchenPrepared: true,
          ),
        ],
      );

      final kitchenItems =
          KioskProductionCopyRules.kitchenItems(orderWith([drink]));

      expect(kitchenItems, contains(drink));
    },
  );
}
