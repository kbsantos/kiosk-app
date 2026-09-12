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

  Future<void> markSynced(KioskOrder order, {DateTime? syncedAt}) async {
    final all = await _load();
    all[order.id] = ReportingSyncStatus(
      externalTransactionId: order.id,
      syncedAt: syncedAt ?? DateTime.now(),
      snapshot: snapshotFor(order),
    );
    await _save(all);
  }

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
