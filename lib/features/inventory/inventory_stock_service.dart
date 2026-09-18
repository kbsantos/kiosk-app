import 'inventory_movement_models.dart';
import 'inventory_stock_models.dart';
import 'inventory_stock_repository.dart';

class InventoryStockService {
  final InventoryStockRepository repository;

  const InventoryStockService({this.repository = const InventoryStockRepository()});

  Future<List<InventoryStockProjection>> project({
    required Iterable<InventoryMovement> movements,
  }) async {
    final items = await repository.loadItems();
    final byKey = <String, num>{};
    for (final movement in movements) {
      final key = '${movement.inventoryItemId}|${movement.unit}';
      byKey[key] = (byKey[key] ?? 0) + movement.signedQuantity;
    }
    return items
        .map((item) => InventoryStockProjection(
              item: item,
              movementQuantity: byKey['${item.inventoryItemId}|${item.unit}'] ?? 0,
            ))
        .toList(growable: false);
  }

  static List<InventoryStockProjection> fromLedger({
    required Iterable<InventoryStockItem> items,
    required Iterable<InventoryMovement> movements,
  }) {
    final totals = <String, num>{};
    for (final movement in movements) {
      final key = '${movement.inventoryItemId}|${movement.unit}';
      totals[key] = (totals[key] ?? 0) + movement.signedQuantity;
    }
    return items
        .map((item) => InventoryStockProjection(
              item: item,
              movementQuantity:
                  totals['${item.inventoryItemId}|${item.unit}'] ?? 0,
            ))
        .toList(growable: false);
  }
}
