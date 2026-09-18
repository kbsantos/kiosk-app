/// Models for explicit kiosk-to-inventory movement synchronization.
library;

enum InventoryMovementSyncState { synced, pending, failed, unavailable }

class InventoryMovementSyncResult {
  const InventoryMovementSyncResult({
    required this.attempted,
    required this.succeeded,
    required this.failures,
  });

  final int attempted;
  final int succeeded;
  final List<InventoryMovementSyncFailure> failures;

  int get failed => failures.length;
  bool get isSuccess => failed == 0;
  int get pending => attempted - succeeded;
}

class InventoryMovementSyncFailure {
  const InventoryMovementSyncFailure({
    required this.localMovementId,
    required this.message,
  });

  final String localMovementId;
  final String message;
}

class InventoryMovementSyncStatus {
  const InventoryMovementSyncStatus({
    required this.state,
    required this.total,
    required this.synced,
    required this.pending,
    required this.failed,
    required this.lastAttemptAt,
    required this.lastSuccessAt,
    required this.lastError,
  });

  final InventoryMovementSyncState state;
  final int total;
  final int synced;
  final int pending;
  final int failed;
  final DateTime? lastAttemptAt;
  final DateTime? lastSuccessAt;
  final String? lastError;
}
