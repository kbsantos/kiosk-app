import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/orders/kiosk_order_repository.dart';
import 'reporting_sync_result.dart';
import 'reporting_sync_status.dart';
import 'reporting_sync_status_store.dart';
import 'reporting_transaction_mapper.dart';
import 'reporting_restore_mapper.dart';
import 'reporting_sync_audit.dart';
import 'reporting_sync_operational_status.dart';
import '../kiosk/settings/kiosk_settings_repository.dart';

/// Manual, reporting-only synchronization service.
///
/// Local SharedPreferences remains the kiosk source of truth. This service only
/// reads local [KioskOrder] records and sends their current snapshot to the
/// Supabase `sync_kiosk_transaction` RPC.
class ReportingRestorePreview {
  const ReportingRestorePreview({
    required this.databaseTransactions,
    required this.alreadyLocal,
    required this.missingOrders,
    this.failures = const [],
  });

  final int databaseTransactions;
  final int alreadyLocal;
  final List<KioskOrder> missingOrders;
  final List<ReportingRestoreFailure> failures;

  int get missing => missingOrders.length;
}

class ReportingRestoreResult {
  const ReportingRestoreResult({
    required this.databaseTransactions,
    required this.alreadyLocal,
    required this.restored,
    required this.failed,
    this.failures = const [],
  });

  final int databaseTransactions;
  final int alreadyLocal;
  final int restored;
  final int failed;
  final List<ReportingRestoreFailure> failures;

  bool get isSuccess => failed == 0;

  String get summary =>
      '$restored transaction(s) restored, $alreadyLocal already on the kiosk, '
      '$failed failed.';
}

class ReportingRestoreFailure {
  const ReportingRestoreFailure({
    required this.externalTransactionId,
    required this.message,
  });

  final String externalTransactionId;
  final String message;
}

class ReportingSyncService {
  ReportingSyncService({
    KioskOrderRepository? orderRepository,
    ReportingTransactionMapper? mapper,
    ReportingSyncStatusStore? statusStore,
    KioskSettingsRepository? settingsRepository,
  })  : _orderRepository = orderRepository ?? KioskOrderRepository(),
        _mapper = mapper ?? const ReportingTransactionMapper(),
        _statusStore = statusStore ?? ReportingSyncStatusStore(),
        _settingsRepository = settingsRepository ?? KioskSettingsRepository(),
        _auditStore = ReportingSyncAuditStore();

  static const _rpcName = 'sync_kiosk_transaction';

  final KioskOrderRepository _orderRepository;
  final ReportingTransactionMapper _mapper;
  final ReportingSyncStatusStore _statusStore;
  final KioskSettingsRepository _settingsRepository;
  final ReportingSyncAuditStore _auditStore;

  /// Syncs orders created on the kiosk's local calendar date.
  Future<ReportingSyncResult> syncToday({
    DateTime? date,
    bool includeAlreadySynced = false,
  }) async {
    final targetDate = date ?? DateTime.now();
    final orders = await _orderRepository.getOrdersForDate(targetDate);
    return _syncPendingOrders(orders, includeAlreadySynced: includeAlreadySynced);
  }

  /// Syncs every locally stored kiosk order.
  ///
  /// Existing cloud records are updated through the RPC's UPSERT behavior, so
  /// repeated manual full syncs do not create duplicate transactions.
  Future<ReportingSyncResult> fullSync({
    bool includeAlreadySynced = false,
  }) async {
    final orders = await _orderRepository.getOrders();
    return _syncPendingOrders(orders, includeAlreadySynced: includeAlreadySynced);
  }

  /// Sends every locally stored transaction to reporting.
  ///
  /// This is intentionally a full, idempotent resync for the EOD workflow.
  /// Already-synced transactions are included so the reporting database is
  /// refreshed from the kiosk's complete local transaction history.
  Future<ReportingSyncResult> syncAllTransactions() async {
    final orders = await _orderRepository.getOrders();
    return _syncOrders(orders);
  }

  /// Reads reporting transactions for this kiosk and identifies only those
  /// whose external transaction ID is missing locally. No local data is
  /// changed.
  Future<ReportingRestorePreview> previewMissingTransactions() async {
    final settings = await _settingsRepository.load();
    _validateConfiguration(settings);

    final result = await Supabase.instance.client.rpc(
      'get_kiosk_transactions_for_restore',
      params: {
        'p_store_id': settings.storeId.trim(),
        'p_device_code': settings.deviceId.trim(),
      },
    );

    if (result == null) {
      throw StateError('The reporting database returned no restore payload.');
    }

    final rawTransactions = result is List ? result : const [];
    final localOrders = await _orderRepository.getOrders();
    final localIds = localOrders.map((order) => order.id).toSet();

    var alreadyLocal = 0;
    final failures = <ReportingRestoreFailure>[];
    final missingOrders = <KioskOrder>[];

    for (final raw in rawTransactions) {
      try {
        if (raw is! Map) {
          throw const FormatException('Invalid transaction payload.');
        }

        final json = Map<String, dynamic>.from(raw);
        final externalId =
            json['external_transaction_id']?.toString().trim() ?? '';
        if (externalId.isEmpty) {
          throw const FormatException(
            'Transaction payload is missing external_transaction_id.',
          );
        }

        if (localIds.contains(externalId)) {
          alreadyLocal++;
          continue;
        }

        final order = _restoreOrderFromDatabase(json);
        missingOrders.add(order);
        localIds.add(externalId);
      } catch (error) {
        final id = raw is Map
            ? (raw['id'] ?? raw['external_transaction_id'] ?? 'unknown')
                .toString()
            : 'unknown';
        failures.add(
          ReportingRestoreFailure(
            externalTransactionId: id,
            message: error.toString(),
          ),
        );
      }
    }

    return ReportingRestorePreview(
      databaseTransactions: rawTransactions.length,
      alreadyLocal: alreadyLocal,
      missingOrders: List.unmodifiable(missingOrders),
      failures: List.unmodifiable(failures),
    );
  }

  /// Restores the missing transactions from a previously generated preview.
  /// Existing local transactions are never overwritten.
  Future<ReportingRestoreResult> restoreMissingTransactions(
    ReportingRestorePreview preview,
  ) async {
    final restored = await _orderRepository.restoreOrders(preview.missingOrders);

    return ReportingRestoreResult(
      databaseTransactions: preview.databaseTransactions,
      alreadyLocal: preview.alreadyLocal,
      restored: restored,
      failed: preview.failures.length,
      failures: preview.failures,
    );
  }

  KioskOrder _restoreOrderFromDatabase(Map<String, dynamic> json) =>
      ReportingRestoreMapper.fromDatabasePayload(json);

  /// Returns local reporting sync progress without changing any kiosk order.
  Future<ReportingSyncProgress> getTodayProgress({DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final orders = await _orderRepository.getOrdersForDate(targetDate);
    return _statusStore.getProgress(orders);
  }

  Future<ReportingSyncProgress> getFullProgress() async {
    final orders = await _orderRepository.getOrders();
    return _statusStore.getProgress(orders);
  }

  /// Returns the combined local reporting sync status and latest audit entry.
  Future<ReportingSyncOperationalStatus> getOperationalStatus() async {
    final orders = await _orderRepository.getOrders();
    final progress = await _statusStore.getProgress(orders);
    final latestAudit = await _auditStore.latest();
    return ReportingSyncOperationalStatus.from(
      progress: progress,
      latestAudit: latestAudit,
    );
  }

  /// Returns the local audit history for the explicit reporting sync action.
  Future<List<ReportingSyncAudit>> getAuditHistory() => _auditStore.history();

  Future<ReportingSyncResult> _syncPendingOrders(
    List<KioskOrder> orders, {
    required bool includeAlreadySynced,
  }) async {
    final toSync = <KioskOrder>[];
    for (final order in orders) {
      final alreadySynced =
          await _statusStore.isCurrentSnapshotSynced(order);
      if (includeAlreadySynced || !alreadySynced) {
        toSync.add(order);
      }
    }
    return _syncOrders(toSync);
  }

  Future<ReportingSyncResult> _syncOrders(List<KioskOrder> orders) async {
    final settings = await _settingsRepository.load();
    _validateConfiguration(settings);

    final startedAt = DateTime.now();
    var succeeded = 0;
    final failures = <ReportingSyncFailure>[];

    for (final order in orders) {
      try {
        final deviceId = await _resolveDeviceUuid(
          storeId: settings.storeId.trim(),
          deviceCode: settings.deviceId.trim(),
        );

        final payload = _mapper.mapOrder(
          order: order,
          storeId: settings.storeId.trim(),
          deviceId: deviceId,
        );

        await Supabase.instance.client.rpc(
          _rpcName,
          params: payload.toRpcParams(),
        );

        // Record the acknowledgement separately from the order itself. If
        // this metadata write fails, the next manual sync safely retries the
        // RPC because the database operation is idempotent.
        await _statusStore.markSynced(order);
        succeeded++;
      } catch (error) {
        failures.add(
          ReportingSyncFailure(
            externalTransactionId: order.id,
            orderNumber: order.orderNumber,
            message: error.toString(),
          ),
        );
      }
    }

    final result = ReportingSyncResult(
      attempted: orders.length,
      succeeded: succeeded,
      failures: List.unmodifiable(failures),
    );

    await _recordAudit(
      startedAt: startedAt,
      result: result,
      settings: settings,
    );

    return result;
  }

  Future<void> _recordAudit({
    required DateTime startedAt,
    required ReportingSyncResult result,
    required KioskSettings settings,
  }) async {
    final completedAt = DateTime.now();
    final audit = ReportingSyncAudit(
      id: 'sync-${completedAt.toUtc().microsecondsSinceEpoch}',
      startedAt: startedAt,
      completedAt: completedAt,
      attempted: result.attempted,
      succeeded: result.succeeded,
      failed: result.failed,
      failures: result.failures
          .map(
            (failure) => ReportingSyncAuditFailure(
              externalTransactionId: failure.externalTransactionId,
              message: failure.message,
            ),
          )
          .toList(growable: false),
    );

    try {
      await _auditStore.record(audit);
    } catch (_) {
      // Audit metadata must never turn a completed reporting sync into a
      // failure. The transaction RPC result remains authoritative.
    }

    try {
      await Supabase.instance.client.rpc(
        'record_kiosk_reporting_sync_log',
        params: {
          'p_store_id': settings.storeId.trim(),
          'p_device_code': settings.deviceId.trim(),
          'p_started_at': startedAt.toUtc().toIso8601String(),
          'p_completed_at': completedAt.toUtc().toIso8601String(),
          'p_attempted': result.attempted,
          'p_succeeded': result.succeeded,
          'p_failed': result.failed,
          'p_failures': result.failures
              .map(
                (failure) => {
                  'externalTransactionId': failure.externalTransactionId,
                  'orderNumber': failure.orderNumber,
                  'message': failure.message,
                },
              )
              .toList(growable: false),
        },
      );
    } catch (_) {
      // Server-side audit is best effort. Never hide or reverse the actual
      // transaction synchronization result because an audit write failed.
    }
  }

  Future<String> _resolveDeviceUuid({
    required String storeId,
    required String deviceCode,
  }) async {
    // The devices table is protected by RLS. Resolve the kiosk through a
    // narrowly scoped SECURITY DEFINER RPC instead of selecting the table
    // directly with the kiosk's public Supabase client.
    final result = await Supabase.instance.client.rpc(
      'resolve_kiosk_device',
      params: {
        'p_store_id': storeId,
        'p_device_code': deviceCode,
      },
    );

    final id = result?.toString().trim();
    if (id == null || id.isEmpty) {
      throw StateError(
        'No active kiosk device was found for Store ID '
        '$storeId and Device / Kiosk Code $deviceCode. '
        'Create or activate this device in the Supabase devices table.',
      );
    }

    return id;
  }

  void _validateConfiguration(KioskSettings settings) {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY).',
      );
    }

    final storeId = settings.storeId.trim();
    final deviceId = settings.deviceId.trim();
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-'
      r'[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    );

    if (!uuidPattern.hasMatch(storeId)) {
      throw StateError(
        'Reporting sync is not configured. Set a valid Store ID UUID '
        'in Kiosk Settings.',
      );
    }

    if (deviceId.isEmpty) {
      throw StateError(
        'Reporting sync is not configured. Set the Device / Kiosk Code '
        'in Kiosk Settings.',
      );
    }
  }
}
