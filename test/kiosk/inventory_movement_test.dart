import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_models.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_service.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_recipe_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  group('Inventory movement synchronization contract', () {
    const recipe = InventoryRecipe(
      recipeId: 'recipe.latte',
      productId: 'prod.latte',
      ingredients: [
        InventoryRecipeIngredient(
          inventoryItemId: 'beans',
          quantity: 18,
          unit: 'g',
        ),
        InventoryRecipeIngredient(
          inventoryItemId: 'milk',
          quantity: 180,
          unit: 'ml',
        ),
      ],
    );

    KioskOrder order({KioskOrderStatus status = KioskOrderStatus.completed}) {
      final item = KioskCartItem(
        product: const KioskProduct(
          id: 'prod.latte',
          name: 'Latte',
          price: 150,
          category: KioskCategory.coffee,
          recipeRef: 'recipe.latte',
        ),
        quantity: 2,
      );
      return KioskOrder(
        id: 'order-1',
        orderNumber: '1001',
        createdAt: DateTime(2026, 9, 19, 10),
        orderType: 'Takeout',
        paymentMethod: 'Cash',
        status: status,
        items: [item],
        total: 300,
      );
    }

    test('creates deterministic consumption movements only for completed orders', () {
      final result = InventoryMovementService.buildConsumptionMovements(
        orders: [order(), order(status: KioskOrderStatus.cancelled)],
        recipes: const [recipe],
      );

      expect(result.unresolvedRecipeRefs, isEmpty);
      expect(result.movements, hasLength(2));
      expect(result.movements.map((m) => m.id).toSet(), hasLength(2));
      expect(
        result.movements
            .firstWhere((m) => m.inventoryItemId == 'beans')
            .quantity,
        36,
      );
    });

    test('deduplicates retries without doubling consumption', () {
      final built = InventoryMovementService.buildConsumptionMovements(
        orders: [order()],
        recipes: const [recipe],
      ).movements;
      final merged = InventoryMovementLedger.mergeDeduplicated(
        built,
        built,
      );

      expect(merged, hasLength(2));
      expect(merged.map((m) => m.id).toSet(), hasLength(2));
    });

    test('stock summary applies signed consumption against opening stock', () {
      final movements = InventoryMovementService.buildConsumptionMovements(
        orders: [order()],
        recipes: const [recipe],
      ).movements;
      final summary = InventoryMovementLedger.summarize(
        movements: movements,
        openingQuantities: const {
          'beans|g': 100,
          'milk|ml': 1000,
        },
      );

      final beans = summary.firstWhere((x) => x.inventoryItemId == 'beans');
      final milk = summary.firstWhere((x) => x.inventoryItemId == 'milk');
      expect(beans.currentQuantity, 64);
      expect(milk.currentQuantity, 640);
    });

    test('preserves explicit stock-in and adjustment as positive movements', () {
      final movements = [
        InventoryMovement(
          id: 'stock-in-1',
          inventoryItemId: 'cups',
          quantity: 50,
          unit: 'pcs',
          type: InventoryMovementType.stockIn,
          occurredAt: DateTime(2026, 9, 19),
        ),
        InventoryMovement(
          id: 'adjust-1',
          inventoryItemId: 'cups',
          quantity: 5,
          unit: 'pcs',
          type: InventoryMovementType.adjustment,
          occurredAt: DateTime(2026, 9, 19),
        ),
      ];

      final summary = InventoryMovementLedger.summarize(
        movements: movements,
        openingQuantities: const {'cups|pcs': 10},
      );

      expect(summary.single.currentQuantity, 65);
    });
  });
}
