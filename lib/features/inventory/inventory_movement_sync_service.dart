import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';
import 'inventory_movement_models.dart';
import 'inventory_movement_sync_models.dart';
import 'inventory_movement_sync_store.dart';

/// Explicit, inventory-only synchronization of the kiosk movement ledger.
///
/// Local movements remain authoritative for the kiosk. Only successful server
/// acknowledgements are recorded locally. Failed movements remain pending so a
/// later manual retry can safely send them again.
class InventoryMovementSyncService {
  InventoryMovementSyncService({
    InventoryMovementSyncStore? store,
    KioskSettingsRepository? settingsRepository,
  })  : _store = store ?? const InventoryMovementSyncStore(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository();

  static const _rpcName = 'sync_kiosk_inventory_movements';

  final InventoryMovementSyncStore _store;
  final KioskSettingsRepository _settingsRepository;

  Future<InventoryMovementSyncStatus> getStatus(
    Iterable<InventoryMovement> movements,
  ) async {
    final list = movements.toList(growable: false);
    final syncedIds = await _store.loadSyncedIds();
    final synced = list.where((movement) => syncedIds.contains(movement.id)).length;
    final pending = list.length - synced;
    final lastAttemptAt = await _store.lastAttemptAt();
    final lastSuccessAt = await _store.lastSuccessAt();
    final lastError = await _store.lastError();
    final state = !SupabaseConfig.isConfigured
        ? InventoryMovementSyncState.unavailable
        : pending == 0
            ? InventoryMovementSyncState.synced
            : lastError != null
                ? InventoryMovementSyncState.failed
                : InventoryMovementSyncState.pending;

    return InventoryMovementSyncStatus(
      state: state,
      total: list.length,
      synced: synced,
      pending: pending,
      failed: lastError == null ? 0 : 1,
      lastAttemptAt: lastAttemptAt,
      lastSuccessAt: lastSuccessAt,
      lastError: lastError,
    );
  }

  Future<InventoryMovementSyncResult> syncPending(
    Iterable<InventoryMovement> movements,
  ) async {
    final all = movements.toList(growable: false);
    final syncedIds = await _store.loadSyncedIds();
    final pending = all.where((movement) => !syncedIds.contains(movement.id)).toList(growable: false);
    final startedAt = DateTime.now();
    await _store.recordAttempt(at: startedAt);

    if (pending.isEmpty) {
      await _store.recordSuccess(at: DateTime.now());
      return const InventoryMovementSyncResult(
        attempted: 0,
        succeeded: 0,
        failures: [],
      );
    }

    try {
      final settings = await _settingsRepository.load();
      _validateConfiguration(settings);
      final result = await Supabase.instance.client.rpc(
        _rpcName,
        params: {
          'p_store_id': settings.storeId.trim(),
          'p_device_code': settings.deviceId.trim(),
          'p_movements': pending.map(_toRpcPayload).toList(growable: false),
        },
      );
      final acknowledgements = _parseResponse(result, pending);
      final succeededIds = acknowledgements
          .where((item) => item.success)
          .map((item) => item.localMovementId)
          .toList(growable: false);
      await _store.markSynced(succeededIds);

      final failures = acknowledgements
          .where((item) => !item.success)
          .map((item) => InventoryMovementSyncFailure(
                localMovementId: item.localMovementId,
                message: item.message ?? 'Inventory movement was not acknowledged.',
              ))
          .toList(growable: false);
      final syncResult = InventoryMovementSyncResult(
        attempted: pending.length,
        succeeded: succeededIds.length,
        failures: failures,
      );
      if (syncResult.failed == 0) {
        await _store.recordSuccess(at: DateTime.now());
      } else {
        await _store.recordFailure(failures.first.message);
      }
      return syncResult;
    } catch (error) {
      final message = error.toString();
      await _store.recordFailure(message);
      return InventoryMovementSyncResult(
        attempted: pending.length,
        succeeded: 0,
        failures: [
          InventoryMovementSyncFailure(
            localMovementId: pending.first.id,
            message: message,
          ),
        ],
      );
    }
  }

  Map<String, dynamic> _toRpcPayload(InventoryMovement movement) {
    return {
      'localMovementId': movement.id,
      'inventoryItemId': movement.inventoryItemId,
      'quantity': _databaseQuantity(movement),
      'movementType': _databaseMovementType(movement.type),
      'unit': movement.unit,
      'reason': movement.note ?? 'Kiosk inventory movement',
      'occurredAt': movement.occurredAt.toUtc().toIso8601String(),
    };
  }

  num _databaseQuantity(InventoryMovement movement) => movement.type == InventoryMovementType.consumption
      ? -movement.quantity
      : movement.quantity;

  String _databaseMovementType(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.consumption:
        return 'usage';
      case InventoryMovementType.stockIn:
        return 'stock_in';
      case InventoryMovementType.adjustment:
        return 'adjustment';
    }
  }

  List<_Acknowledgement> _parseResponse(
    dynamic response,
    List<InventoryMovement> pending,
  ) {
    if (response is! List) {
      throw const FormatException('Inventory sync returned an invalid response.');
    }
    final expected = pending.map((movement) => movement.id).toSet();
    final results = <String, _Acknowledgement>{};
    for (final raw in response) {
      if (raw is! Map) continue;
      final localId = raw['localMovementId']?.toString().trim() ?? '';
      if (localId.isEmpty || !expected.contains(localId)) continue;
      final status = raw['status']?.toString().toLowerCase();
      final success = status == 'synced' || status == 'already_synced';
      results[localId] = _Acknowledgement(
        localMovementId: localId,
        success: success,
        message: raw['error']?.toString(),
      );
    }
    return pending.map((movement) {
      return results[movement.id] ?? _Acknowledgement(
        localMovementId: movement.id,
        success: false,
        message: 'Inventory sync response did not acknowledge this movement.',
      );
    }).toList(growable: false);
  }

  void _validateConfiguration(KioskSettings settings) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError('Supabase is not configured.');
    }
    final storeId = settings.storeId.trim();
    final deviceCode = settings.deviceId.trim();
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );
    if (!uuidPattern.hasMatch(storeId)) {
      throw StateError('Inventory sync requires a valid Store ID UUID.');
    }
    if (deviceCode.isEmpty) {
      throw StateError('Inventory sync requires a Device / Kiosk Code.');
    }
  }
}

class _Acknowledgement {
  const _Acknowledgement({
    required this.localMovementId,
    required this.success,
    required this.message,
  });

  final String localMovementId;
  final bool success;
  final String? message;
}
