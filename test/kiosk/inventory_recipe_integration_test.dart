import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/inventory/inventory_recipe_models.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_recipe_validator.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_consumption_calculator.dart';
import 'package:bigger_brew_kiosk/features/kiosk/models/kiosk_models.dart';
import 'package:bigger_brew_kiosk/features/kiosk/orders/kiosk_order.dart';

void main() {
  group('Inventory recipe integration', () {
    const latteRecipe = InventoryRecipe(
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

    test('validates recipe references and ingredient identities', () {
      final result = InventoryRecipeValidator.validate(
        recipes: const [latteRecipe],
        catalogProducts: const [
          CatalogRecipeProductRef(productId: 'prod.latte', recipeRef: 'recipe.latte'),
        ],
        inventoryItemIds: const {'beans', 'milk'},
      );

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('reports missing recipe and inventory references', () {
      final result = InventoryRecipeValidator.validate(
        recipes: const [
          InventoryRecipe(
            recipeId: 'recipe.missing-product',
            productId: 'prod.unknown',
            ingredients: [
              InventoryRecipeIngredient(
                inventoryItemId: 'water',
                quantity: 250,
                unit: 'ml',
              ),
            ],
          ),
        ],
        catalogProducts: const [
          CatalogRecipeProductRef(productId: 'prod.latte', recipeRef: 'recipe.unknown'),
        ],
        inventoryItemIds: const {'beans'},
      );

      expect(result.errors.map((e) => e.code), contains('missing_recipe_reference'));
      expect(result.errors.map((e) => e.code), contains('recipe_product_not_in_catalog'));
      expect(result.errors.map((e) => e.code), contains('missing_inventory_item_reference'));
    });

    test('calculates consumption only for completed orders', () {
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

      final completed = KioskOrder(
        id: 'order.completed',
        orderNumber: '1001',
        createdAt: DateTime(2026, 9, 19, 10),
        orderType: 'Dine In',
        paymentMethod: 'Cash',
        status: KioskOrderStatus.completed,
        items: [item],
        total: 300,
      );
      final cancelled = completed.copyWith(
        status: KioskOrderStatus.cancelled,
      );

      final result = InventoryConsumptionCalculator.calculate(
        orders: [completed, cancelled],
        recipes: const [latteRecipe],
      );

      expect(result.quantityFor('beans', 'g'), 36);
      expect(result.quantityFor('milk', 'ml'), 360);
      expect(result.unresolvedRecipeRefs, isEmpty);
    });

    test('selects a size/variant scoped recipe before the base recipe', () {
      const base = InventoryRecipe(
        recipeId: 'recipe.base',
        productId: 'prod.drink',
        ingredients: [
          InventoryRecipeIngredient(inventoryItemId: 'milk', quantity: 180, unit: 'ml'),
        ],
      );
      const large = InventoryRecipe(
        recipeId: 'recipe.large',
        productId: 'prod.drink',
        sizeId: 'size.large',
        ingredients: [
          InventoryRecipeIngredient(inventoryItemId: 'milk', quantity: 300, unit: 'ml'),
        ],
      );

      final item = KioskCartItem(
        product: const KioskProduct(
          id: 'prod.drink',
          name: 'Drink',
          price: 100,
          category: KioskCategory.milkTea,
          recipeRef: 'recipe.base',
          sizes: [KioskSize(id: 'size.large', name: 'Large', price: 120)],
        ),
        size: const KioskSize(id: 'size.large', name: 'Large', price: 120),
      );
      final order = KioskOrder(
        id: 'order.large',
        orderNumber: '1002',
        createdAt: DateTime(2026, 9, 19, 11),
        orderType: 'Takeout',
        paymentMethod: 'Cash',
        status: KioskOrderStatus.completed,
        items: [item],
        total: 120,
      );

      final result = InventoryConsumptionCalculator.calculate(
        orders: [order],
        recipes: const [base, large],
      );

      expect(result.quantityFor('milk', 'ml'), 300);
      expect(result.unresolvedRecipeRefs, isEmpty);
    });
  });
}
