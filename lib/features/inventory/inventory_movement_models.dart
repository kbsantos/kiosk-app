/// Local inventory movement contract used by the kiosk/inventory boundary.
/// The kiosk records movement facts; the inventory system remains responsible
/// for authoritative stock balances and adjustments.
library;

enum InventoryMovementType { consumption, stockIn, adjustment }

class InventoryMovement {
  final String id;
  final String inventoryItemId;
  final num quantity;
  final String unit;
  final InventoryMovementType type;
  final String? sourceOrderId;
  final String? sourceOrderItemKey;
  final DateTime occurredAt;
  final String? note;

  const InventoryMovement({
    required this.id,
    required this.inventoryItemId,
    required this.quantity,
    required this.unit,
    required this.type,
    required this.occurredAt,
    this.sourceOrderId,
    this.sourceOrderItemKey,
    this.note,
  });

  bool get isConsumption => type == InventoryMovementType.consumption;

  num get signedQuantity {
    switch (type) {
      case InventoryMovementType.consumption:
        return -quantity;
      case InventoryMovementType.stockIn:
        return quantity;
      case InventoryMovementType.adjustment:
        return quantity;
    }
  }

  factory InventoryMovement.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? '';
    final type = InventoryMovementType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => throw FormatException('Unknown inventory movement type.'),
    );
    final occurredAt = DateTime.tryParse(json['occurredAt']?.toString() ?? '');
    final quantity = json['quantity'];
    if (occurredAt == null || quantity is! num) {
      throw FormatException('Invalid inventory movement.');
    }
    return InventoryMovement(
      id: json['id']?.toString() ?? '',
      inventoryItemId: json['inventoryItemId']?.toString() ?? '',
      quantity: quantity,
      unit: json['unit']?.toString() ?? '',
      type: type,
      sourceOrderId: json['sourceOrderId']?.toString(),
      sourceOrderItemKey: json['sourceOrderItemKey']?.toString(),
      occurredAt: occurredAt,
      note: json['note']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'inventoryItemId': inventoryItemId,
        'quantity': quantity,
        'unit': unit,
        'type': type.name,
        'sourceOrderId': sourceOrderId,
        'sourceOrderItemKey': sourceOrderItemKey,
        'occurredAt': occurredAt.toIso8601String(),
        'note': note,
      };
}

class InventoryStockSummary {
  final String inventoryItemId;
  final String unit;
  final num openingQuantity;
  final num movementQuantity;

  const InventoryStockSummary({
    required this.inventoryItemId,
    required this.unit,
    required this.openingQuantity,
    required this.movementQuantity,
  });

  num get currentQuantity => openingQuantity + movementQuantity;
}
