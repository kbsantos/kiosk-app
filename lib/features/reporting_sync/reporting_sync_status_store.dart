import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../kiosk/orders/kiosk_order.dart';
import 'reporting_sync_status.dart';

/// Local-only reporting synchronization metadata.
///
/// This store deliberately uses a separate SharedPreferences key and never
/// rewrites kiosk orders. The kiosk transaction data remains the source of
/// truth. Only successful cloud acknowledgements are recorded here.
class ReportingSyncStatusStore {
  static const _key = 'bigger_brew_kiosk.reporting_sync_status.v1';

  String snapshotFor(KioskOrder order) => jsonEncode(order.toJson());

  Future<ReportingSyncStatus?> getStatus(String externalTransactionId) async {
    final all = await _load();
    return all[externalTransactionId];
  }

  Future<bool> isCurrentSnapshotSynced(KioskOrder order) async {
    final status = await getStatus(order.id);
    return status != null && status.snapshot == snapshotFor(order);
  }

  /// Loads the status index once so large transaction histories do not repeatedly
  /// decode the same SharedPreferences value for every order.
  Future<Map<String, ReportingSyncStatus>> getStatuses() => _load();

  /// Saves acknowledgements in one write instead of rewriting the full status
  /// index after every uploaded transaction.
  Future<void> markSyncedBatch(
    Iterable<KioskOrder> orders, {
    DateTime? syncedAt,
  }) async {
    final batchTime = syncedAt ?? DateTime.now();
    final all = await _load();
    for (final order in orders) {
      all[order.id] = ReportingSyncStatus(
        externalTransactionId: order.id,
        syncedAt: batchTime,
        snapshot: snapshotFor(order),
      );
    }
    if (orders.isNotEmpty) await _save(all);
  }

  Future<void> markSynced(KioskOrder order, {DateTime? syncedAt}) =>
      markSyncedBatch([order], syncedAt: syncedAt);

  Future<ReportingSyncProgress> getProgress(List<KioskOrder> orders) async {
    final all = await _load();
    var synced = 0;
    DateTime? lastSyncedAt;

    for (final order in orders) {
      final status = all[order.id];
      if (status != null && status.snapshot == snapshotFor(order)) {
        synced++;
        if (lastSyncedAt == null || status.syncedAt.isAfter(lastSyncedAt)) {
          lastSyncedAt = status.syncedAt;
        }
      }
    }

    return ReportingSyncProgress(
      total: orders.length,
      pending: orders.length - synced,
      synced: synced,
      lastSyncedAt: lastSyncedAt,
    );
  }

  /// Removes local acknowledgement metadata for transactions that have been
  /// safely purged from the local transaction archive.
  Future<void> removeStatuses(Iterable<String> transactionIds) async {
    final ids = transactionIds.toSet();
    if (ids.isEmpty) return;
    final all = await _load();
    all.removeWhere((id, _) => ids.contains(id));
    await _save(all);
  }

  Future<Map<String, ReportingSyncStatus>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, ReportingSyncStatus>{};

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final result = <String, ReportingSyncStatus>{};
      decoded.forEach((id, value) {
        if (value is Map) {
          try {
            result[id] = ReportingSyncStatus.fromJson(
              Map<String, dynamic>.from(value),
            );
          } catch (_) {
            // Ignore only malformed sync metadata. Never affect kiosk orders.
          }
        }
      });
      return result;
    } catch (_) {
      return <String, ReportingSyncStatus>{};
    }
  }

  Future<void> _save(Map<String, ReportingSyncStatus> all) async {
    final prefs = await SharedPreferences.getInstance();
    final json = <String, dynamic>{
      for (final entry in all.entries) entry.key: entry.value.toJson(),
    };
    await prefs.setString(_key, jsonEncode(json));
  }
}
