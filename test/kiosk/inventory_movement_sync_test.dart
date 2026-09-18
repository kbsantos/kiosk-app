import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_models.dart';
import 'package:bigger_brew_kiosk/features/inventory/inventory_movement_sync_models.dart';

void main() {
  group('Inventory movement sync contract', () {
    test('consumption maps to a negative usage quantity', () {
      final movement = InventoryMovement(
        id: 'consume:order-1:item-0:beans:g',
        inventoryItemId: '00000000-0000-4000-8000-000000000001',
        quantity: 36,
        unit: 'g',
        type: InventoryMovementType.consumption,
        occurredAt: DateTime(2026, 9, 19, 10),
      );

      expect(movement.signedQuantity, -36);
    });

    test('sync result keeps failed movements retryable', () {
      const result = InventoryMovementSyncResult(
        attempted: 3,
        succeeded: 2,
        failures: [
          InventoryMovementSyncFailure(
            localMovementId: 'manual:failed',
            message: 'network unavailable',
          ),
        ],
      );

      expect(result.succeeded, 2);
      expect(result.failed, 1);
      expect(result.pending, 1);
      expect(result.isSuccess, isFalse);
    });

    test('fully acknowledged sync is successful', () {
      const result = InventoryMovementSyncResult(
        attempted: 2,
        succeeded: 2,
        failures: [],
      );

      expect(result.failed, 0);
      expect(result.pending, 0);
      expect(result.isSuccess, isTrue);
    });

    test('sync status exposes pending movements without changing the ledger', () {
      const status = InventoryMovementSyncStatus(
        state: InventoryMovementSyncState.pending,
        total: 5,
        synced: 3,
        pending: 2,
        failed: 0,
        lastAttemptAt: null,
        lastSuccessAt: null,
        lastError: null,
      );

      expect(status.total, 5);
      expect(status.pending, 2);
      expect(status.synced, 3);
    });
  });
}
