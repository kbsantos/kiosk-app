import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReportingSyncAuditFailure {
  const ReportingSyncAuditFailure({
    required this.externalTransactionId,
    required this.message,
  });

  final String externalTransactionId;
  final String message;

  Map<String, dynamic> toJson() => {
        'externalTransactionId': externalTransactionId,
        'message': message,
      };

  factory ReportingSyncAuditFailure.fromJson(Map<String, dynamic> json) {
    return ReportingSyncAuditFailure(
      externalTransactionId:
          json['externalTransactionId']?.toString() ?? 'unknown',
      message: json['message']?.toString() ?? 'Unknown sync failure',
    );
  }
}

class ReportingSyncAudit {
  const ReportingSyncAudit({
    required this.id,
    required this.startedAt,
    required this.completedAt,
    required this.attempted,
    required this.succeeded,
    required this.failed,
    required this.failures,
  });

  final String id;
  final DateTime startedAt;
  final DateTime completedAt;
  final int attempted;
  final int succeeded;
  final int failed;
  final List<ReportingSyncAuditFailure> failures;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.toUtc().toIso8601String(),
        'completedAt': completedAt.toUtc().toIso8601String(),
        'attempted': attempted,
        'succeeded': succeeded,
        'failed': failed,
        'failures': failures.map((failure) => failure.toJson()).toList(),
      };

  factory ReportingSyncAudit.fromJson(Map<String, dynamic> json) {
    final rawFailures = json['failures'];
    return ReportingSyncAudit(
      id: json['id']?.toString() ?? 'unknown',
      startedAt: DateTime.parse(json['startedAt'].toString()).toLocal(),
      completedAt: DateTime.parse(json['completedAt'].toString()).toLocal(),
      attempted: (json['attempted'] as num?)?.toInt() ?? 0,
      succeeded: (json['succeeded'] as num?)?.toInt() ?? 0,
      failed: (json['failed'] as num?)?.toInt() ?? 0,
      failures: rawFailures is List
          ? rawFailures
              .whereType<Map>()
              .map(
                (value) => ReportingSyncAuditFailure.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

/// Local audit trail for explicit reporting sync attempts.
///
/// This metadata never changes kiosk transactions. Failed orders remain
/// pending because only successful snapshots are marked synced by the
/// existing ReportingSyncStatusStore.
class ReportingSyncAuditStore {
  ReportingSyncAuditStore({this.maxEntries = 100});

  static const _key = 'bigger_brew_kiosk.reporting_sync_audit.v1';

  final int maxEntries;

  Future<void> record(ReportingSyncAudit audit) async {
    final history = await _load();
    history.insert(0, audit);
    if (history.length > maxEntries) {
      history.removeRange(maxEntries, history.length);
    }
    await _save(history);
  }

  Future<ReportingSyncAudit?> latest() async {
    final history = await _load();
    return history.isEmpty ? null : history.first;
  }

  Future<List<ReportingSyncAudit>> history() async => List.unmodifiable(await _load());

  Future<List<ReportingSyncAudit>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <ReportingSyncAudit>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <ReportingSyncAudit>[];
      return decoded
          .whereType<Map>()
          .map(
            (value) => ReportingSyncAudit.fromJson(
              Map<String, dynamic>.from(value),
            ),
          )
          .toList();
    } catch (_) {
      return <ReportingSyncAudit>[];
    }
  }

  Future<void> _save(List<ReportingSyncAudit> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(history.map((audit) => audit.toJson()).toList()),
    );
  }
}
