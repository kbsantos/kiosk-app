import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/models/kiosk_models.dart';
import 'inventory_recipe_models.dart';

class InventoryConsumptionLine {
  final String inventoryItemId;
  final num quantity;
  final String unit;

  const InventoryConsumptionLine({
    required this.inventoryItemId,
    required this.quantity,
    required this.unit,
  });
}

class InventoryConsumptionResult {
  final List<InventoryConsumptionLine> lines;
  final List<String> unresolvedRecipeRefs;

  const InventoryConsumptionResult({
    required this.lines,
    this.unresolvedRecipeRefs = const [],
  });

  num quantityFor(String inventoryItemId, String unit) => lines
      .where((line) => line.inventoryItemId == inventoryItemId && line.unit == unit)
      .fold<num>(0, (sum, line) => sum + line.quantity);
}

class InventoryConsumptionCalculator {
  const InventoryConsumptionCalculator._();

  static InventoryConsumptionResult calculate({
    required List<KioskOrder> orders,
    required List<InventoryRecipe> recipes,
  }) {
    final byRecipeId = <String, InventoryRecipe>{
      for (final recipe in recipes) recipe.recipeId: recipe,
    };
    final lines = <String, InventoryConsumptionLine>{};
    final unresolved = <String>{};

    for (final order in orders) {
      if (order.status != KioskOrderStatus.completed) continue;
      for (final item in order.items) {
        final recipe = _resolveRecipe(item, byRecipeId);
        if (recipe == null) {
          final ref = item.product.recipeRef?.trim();
          if (ref != null && ref.isNotEmpty) unresolved.add(ref);
          continue;
        }
        for (final ingredient in recipe.ingredients) {
          final key = '${ingredient.inventoryItemId}|${ingredient.unit}';
          final current = lines[key];
          lines[key] = InventoryConsumptionLine(
            inventoryItemId: ingredient.inventoryItemId,
            unit: ingredient.unit,
            quantity: (current?.quantity ?? 0) +
                ingredient.quantity * item.quantity,
          );
        }
      }
    }

    return InventoryConsumptionResult(
      lines: List.unmodifiable(lines.values),
      unresolvedRecipeRefs: List.unmodifiable(unresolved),
    );
  }

  static InventoryRecipe? _resolveRecipe(
    KioskCartItem item,
    Map<String, InventoryRecipe> byRecipeId,
  ) {
    final baseRef = item.product.recipeRef?.trim();
    if (baseRef == null || baseRef.isEmpty) return null;

    final scoped = byRecipeId.values.where((recipe) {
      return recipe.productId == item.product.id &&
          (recipe.sizeId == item.size?.id) &&
          (recipe.variantId == item.variant?.id);
    });
    if (scoped.isNotEmpty) return scoped.first;

    final base = byRecipeId[baseRef];
    if (base != null && base.productId == item.product.id && base.isBaseRecipe) {
      return base;
    }
    return null;
  }
}
