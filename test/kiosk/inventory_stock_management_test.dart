import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_service.dart';

import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_models.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_stock_models.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_stock_service.dart';

void main() {
  group('Inventory stock management contract', () {
    const beans = InventoryStockItem(
      inventoryItemId: 'beans',
      name: 'Coffee Beans',
      unit: 'g',
      openingQuantity: 1000,
      reorderLevel: 250,
    );

    test('projects current stock from opening quantity and signed movements', () {
      final result = InventoryStockService.fromLedger(
        items: const [beans],
        movements: [
          InventoryMovement(
            id: 'consume-1',
            inventoryItemId: 'beans',
            quantity: 300,
            unit: 'g',
            type: InventoryMovementType.consumption,
            occurredAt: DateTime(2026, 9, 19),
          ),
          InventoryMovement(
            id: 'stock-in-1',
            inventoryItemId: 'beans',
            quantity: 100,
            unit: 'g',
            type: InventoryMovementType.stockIn,
            occurredAt: DateTime(2026, 9, 19),
          ),
        ],
      );

      expect(result.single.currentQuantity, 800);
      expect(result.single.isLowStock, isFalse);
    });

    test('flags an item when projected stock reaches reorder level', () {
      final item = const InventoryStockItem(
        inventoryItemId: 'milk',
        name: 'Fresh Milk',
        unit: 'ml',
        openingQuantity: 500,
        reorderLevel: 250,
      );
      final result = InventoryStockService.fromLedger(
        items: [item],
        movements: [
          InventoryMovement(
            id: 'consume-2',
            inventoryItemId: 'milk',
            quantity: 250,
            unit: 'ml',
            type: InventoryMovementType.consumption,
            occurredAt: DateTime(2026, 9, 19),
          ),
        ],
      );

      expect(result.single.currentQuantity, 250);
      expect(result.single.isLowStock, isTrue);
    });

    test('negative projected stock is surfaced rather than hidden', () {
      final result = InventoryStockService.fromLedger(
        items: const [beans],
        movements: [
          InventoryMovement(
            id: 'consume-3',
            inventoryItemId: 'beans',
            quantity: 1200,
            unit: 'g',
            type: InventoryMovementType.consumption,
            occurredAt: DateTime(2026, 9, 19),
          ),
        ],
      );

      expect(result.single.currentQuantity, -200);
      expect(result.single.isNegative, isTrue);
      expect(result.single.isLowStock, isTrue);
    });

    test('stock item low-stock status uses its configured threshold', () {
      expect(beans.isLowStock, isFalse);
      const low = InventoryStockItem(
        inventoryItemId: 'cups',
        name: 'Cups',
        unit: 'pcs',
        openingQuantity: 20,
        reorderLevel: 20,
      );
      expect(low.isLowStock, isTrue);
    });
  });


group('Inventory stock operations contract', () {
  test('stock-in creates a positive manual movement with audit metadata', () {
    final movement = InventoryStockOperations.buildManualMovement(
      inventoryItemId: 'beans',
      unit: 'g',
      quantity: 500,
      type: InventoryMovementType.stockIn,
      reason: 'Supplier delivery',
      reference: 'PO-1001',
      occurredAt: DateTime(2026, 9, 19, 10),
    );

    expect(movement.signedQuantity, 500);
    expect(movement.sourceOrderId, isNull);
    expect(movement.note, contains('Supplier delivery'));
    expect(movement.note, contains('PO-1001'));
  });

  test('adjustment requires a non-zero signed quantity', () {
    expect(
      () => InventoryStockOperations.buildManualMovement(
        inventoryItemId: 'milk',
        unit: 'ml',
        quantity: 0,
        type: InventoryMovementType.adjustment,
        reason: 'Count correction',
        occurredAt: DateTime(2026, 9, 19),
      ),
      throwsArgumentError,
    );
  });

  test('manual movement IDs are deterministic for retry safety', () {
    final first = InventoryStockOperations.buildManualMovement(
      inventoryItemId: 'cups',
      unit: 'pcs',
      quantity: 100,
      type: InventoryMovementType.stockIn,
      reason: 'Delivery',
      reference: 'PO-1',
      occurredAt: DateTime(2026, 9, 19, 11),
    );
    final second = InventoryStockOperations.buildManualMovement(
      inventoryItemId: 'cups',
      unit: 'pcs',
      quantity: 100,
      type: InventoryMovementType.stockIn,
      reason: 'Delivery',
      reference: 'PO-1',
      occurredAt: DateTime(2026, 9, 19, 11),
    );

    expect(first.id, second.id);
  });

  test('ledger preserves the first movement when a duplicate ID is added', () {
    final original = InventoryMovement(
      id: 'manual:1',
      inventoryItemId: 'beans',
      quantity: 100,
      unit: 'g',
      type: InventoryMovementType.stockIn,
      occurredAt: DateTime(2026, 9, 19),
      note: 'original',
    );
    final duplicate = InventoryMovement(
      id: 'manual:1',
      inventoryItemId: 'beans',
      quantity: 999,
      unit: 'g',
      type: InventoryMovementType.stockIn,
      occurredAt: DateTime(2026, 9, 19),
      note: 'duplicate',
    );

    final merged = InventoryMovementLedger.mergeDeduplicated(
      const [],
      [original, duplicate],
    );

    expect(merged, hasLength(1));
    expect(merged.single.quantity, 100);
    expect(merged.single.note, 'original');
  });
});

}