/// Local stock-monitoring projection for the kiosk.
///
/// This layer is intentionally non-authoritative: the separate inventory
/// system remains the source of truth for stock balances.
library;

class InventoryStockItem {
  final String inventoryItemId;
  final String name;
  final String unit;
  final num openingQuantity;
  final num reorderLevel;

  const InventoryStockItem({
    required this.inventoryItemId,
    required this.name,
    required this.unit,
    required this.openingQuantity,
    required this.reorderLevel,
  });

  bool get isLowStock => openingQuantity <= reorderLevel;

  Map<String, dynamic> toJson() => {
        'inventoryItemId': inventoryItemId,
        'name': name,
        'unit': unit,
        'openingQuantity': openingQuantity,
        'reorderLevel': reorderLevel,
      };

  factory InventoryStockItem.fromJson(Map<String, dynamic> json) =>
      InventoryStockItem(
        inventoryItemId: json['inventoryItemId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        unit: json['unit']?.toString() ?? '',
        openingQuantity: json['openingQuantity'] as num? ?? 0,
        reorderLevel: json['reorderLevel'] as num? ?? 0,
      );
}

class InventoryStockProjection {
  final InventoryStockItem item;
  final num movementQuantity;

  const InventoryStockProjection({
    required this.item,
    required this.movementQuantity,
  });

  num get currentQuantity => item.openingQuantity + movementQuantity;
  bool get isLowStock => currentQuantity <= item.reorderLevel;
  bool get isNegative => currentQuantity < 0;
}
