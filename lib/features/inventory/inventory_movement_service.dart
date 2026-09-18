import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/models/kiosk_models.dart';
import 'inventory_movement_models.dart';
import 'inventory_recipe_models.dart';

class InventoryMovementBuildResult {
  final List<InventoryMovement> movements;
  final List<String> unresolvedRecipeRefs;

  const InventoryMovementBuildResult({
    required this.movements,
    this.unresolvedRecipeRefs = const [],
  });
}

class InventoryMovementService {
  const InventoryMovementService._();

  static InventoryMovementBuildResult buildConsumptionMovements({
    required List<KioskOrder> orders,
    required List<InventoryRecipe> recipes,
  }) {
    final byRecipeId = <String, InventoryRecipe>{
      for (final recipe in recipes) recipe.recipeId: recipe,
    };
    final movements = <InventoryMovement>[];
    final unresolved = <String>{};

    for (final order in orders) {
      if (order.status != KioskOrderStatus.completed) continue;
      for (var itemIndex = 0; itemIndex < order.items.length; itemIndex++) {
        final item = order.items[itemIndex];
        final recipe = _resolveRecipe(item, byRecipeId);
        if (recipe == null) {
          final ref = item.product.recipeRef?.trim();
          if (ref != null && ref.isNotEmpty) unresolved.add(ref);
          continue;
        }
        final itemKey = '${order.id}:$itemIndex';
        for (final ingredient in recipe.ingredients) {
          final id = _movementId(
            orderId: order.id,
            itemKey: itemKey,
            inventoryItemId: ingredient.inventoryItemId,
            unit: ingredient.unit,
          );
          movements.add(InventoryMovement(
            id: id,
            inventoryItemId: ingredient.inventoryItemId,
            quantity: ingredient.quantity * item.quantity,
            unit: ingredient.unit,
            type: InventoryMovementType.consumption,
            sourceOrderId: order.id,
            sourceOrderItemKey: itemKey,
            occurredAt: order.createdAt,
            note: 'Derived from completed kiosk order',
          ));
        }
      }
    }

    return InventoryMovementBuildResult(
      movements: List.unmodifiable(movements),
      unresolvedRecipeRefs: List.unmodifiable(unresolved),
    );
  }

  static String _movementId({
    required String orderId,
    required String itemKey,
    required String inventoryItemId,
    required String unit,
  }) => 'consume:$orderId:$itemKey:$inventoryItemId:$unit';

  static InventoryRecipe? _resolveRecipe(
    KioskCartItem item,
    Map<String, InventoryRecipe> byRecipeId,
  ) {
    final baseRef = item.product.recipeRef?.trim();
    if (baseRef == null || baseRef.isEmpty) return null;

    final scoped = byRecipeId.values.where((recipe) {
      return recipe.productId == item.product.id &&
          recipe.sizeId == item.size?.id &&
          recipe.variantId == item.variant?.id;
    });
    if (scoped.isNotEmpty) return scoped.first;

    final base = byRecipeId[baseRef];
    if (base != null && base.productId == item.product.id && base.isBaseRecipe) {
      return base;
    }
    return null;
  }
}

class InventoryMovementLedger {
  const InventoryMovementLedger._();

  static List<InventoryMovement> mergeDeduplicated(
    Iterable<InventoryMovement> existing,
    Iterable<InventoryMovement> incoming,
  ) {
    final byId = <String, InventoryMovement>{
      for (final movement in existing) movement.id: movement,
    };
    for (final movement in incoming) {
      byId.putIfAbsent(movement.id, () => movement);
    }
    return List.unmodifiable(byId.values);
  }

  static List<InventoryStockSummary> summarize({
    required Iterable<InventoryMovement> movements,
    required Map<String, num> openingQuantities,
  }) {
    final totals = <String, num>{};
    final units = <String, String>{};
    for (final movement in movements) {
      final key = '${movement.inventoryItemId}|${movement.unit}';
      totals[key] = (totals[key] ?? 0) + movement.signedQuantity;
      units[key] = movement.unit;
    }

    final keys = {...totals.keys, ...openingQuantities.keys};
    final result = <InventoryStockSummary>[];
    for (final key in keys) {
      final parts = key.split('|');
      if (parts.length != 2) continue;
      final itemId = parts[0];
      final unit = parts[1];
      result.add(InventoryStockSummary(
        inventoryItemId: itemId,
        unit: units[key] ?? unit,
        openingQuantity: openingQuantities[key] ?? 0,
        movementQuantity: totals[key] ?? 0,
      ));
    }
    return List.unmodifiable(result);
  }
}

class InventoryStockOperations {
  const InventoryStockOperations._();

  static InventoryMovement buildManualMovement({
    required String inventoryItemId,
    required String unit,
    required num quantity,
    required InventoryMovementType type,
    required String reason,
    String? reference,
    required DateTime occurredAt,
  }) {
    final itemId = inventoryItemId.trim();
    final normalizedUnit = unit.trim();
    final normalizedReason = reason.trim();
    final normalizedReference = reference?.trim();
    if (itemId.isEmpty) throw ArgumentError('Inventory item ID is required.');
    if (normalizedUnit.isEmpty) throw ArgumentError('Inventory item unit is required.');
    if (normalizedReason.isEmpty) throw ArgumentError('Movement reason is required.');
    if (quantity == 0) throw ArgumentError('Movement quantity cannot be zero.');
    if (type == InventoryMovementType.consumption) {
      throw ArgumentError('Manual operations cannot create consumption movements.');
    }
    if (type == InventoryMovementType.stockIn && quantity < 0) {
      throw ArgumentError('Stock-in quantity must be positive.');
    }
    final note = normalizedReference == null || normalizedReference.isEmpty
        ? normalizedReason
        : '$normalizedReason • Ref: $normalizedReference';
    final id = _manualMovementId(
      inventoryItemId: itemId,
      unit: normalizedUnit,
      quantity: quantity,
      type: type,
      reason: normalizedReason,
      reference: normalizedReference,
      occurredAt: occurredAt,
    );
    return InventoryMovement(
      id: id,
      inventoryItemId: itemId,
      quantity: quantity,
      unit: normalizedUnit,
      type: type,
      occurredAt: occurredAt,
      note: note,
    );
  }

  static String _manualMovementId({
    required String inventoryItemId,
    required String unit,
    required num quantity,
    required InventoryMovementType type,
    required String reason,
    required String? reference,
    required DateTime occurredAt,
  }) {
    final raw = [
      'manual',
      type.name,
      inventoryItemId,
      unit,
      quantity.toString(),
      reason,
      reference ?? '',
      occurredAt.toIso8601String(),
    ].join('|');
    var hash = 0x811c9dc5;
    for (final codeUnit in raw.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return 'manual:${hash.toRadixString(16).padLeft(8, '0')}';
  }
}
