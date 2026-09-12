import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../kiosk/orders/kiosk_order.dart';
import '../kiosk/orders/kiosk_order_repository.dart';
import 'reporting_sync_result.dart';
import 'reporting_sync_status.dart';
import 'reporting_sync_status_store.dart';
import 'reporting_transaction_mapper.dart';

/// Manual, reporting-only synchronization service.
///
/// Local SharedPreferences remains the kiosk source of truth. This service only
/// reads local [KioskOrder] records and sends their current snapshot to the
/// Supabase `sync_kiosk_transaction` RPC.
class ReportingSyncService {
  ReportingSyncService({
    KioskOrderRepository? orderRepository,
    ReportingTransactionMapper? mapper,
    ReportingSyncStatusStore? statusStore,
  })  : _orderRepository = orderRepository ?? KioskOrderRepository(),
        _mapper = mapper ?? const ReportingTransactionMapper(),
        _statusStore = statusStore ?? ReportingSyncStatusStore();

  static const _rpcName = 'sync_kiosk_transaction';

  final KioskOrderRepository _orderRepository;
  final ReportingTransactionMapper _mapper;
  final ReportingSyncStatusStore _statusStore;

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
    _validateConfiguration();

    var succeeded = 0;
    final failures = <ReportingSyncFailure>[];

    for (final order in orders) {
      try {
        final payload = _mapper.mapOrder(
          order: order,
          storeId: SupabaseConfig.storeId,
          deviceId: SupabaseConfig.deviceId,
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

    return ReportingSyncResult(
      attempted: orders.length,
      succeeded: succeeded,
      failures: List.unmodifiable(failures),
    );
  }

  void _validateConfiguration() {
    if (!SupabaseConfig.isConfigured) {
      throw StateError(
        'Supabase is not configured. Check SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY).',
      );
    }

    if (SupabaseConfig.storeId.isEmpty || SupabaseConfig.deviceId.isEmpty) {
      throw StateError(
        'Reporting sync is not configured. Check SUPABASE_STORE_ID and '
        'SUPABASE_DEVICE_ID.',
      );
    }
  }
}
