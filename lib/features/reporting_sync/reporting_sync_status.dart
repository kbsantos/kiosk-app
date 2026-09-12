class ReportingSyncStatus {
  const ReportingSyncStatus({
    required this.externalTransactionId,
    required this.syncedAt,
    required this.snapshot,
  });

  final String externalTransactionId;
  final DateTime syncedAt;

  /// Exact local order snapshot that was successfully acknowledged by the
  /// reporting RPC. If the local order later changes, its current snapshot no
  /// longer matches and it automatically becomes pending again.
  final String snapshot;

  Map<String, dynamic> toJson() => {
        'externalTransactionId': externalTransactionId,
        'syncedAt': syncedAt.toUtc().toIso8601String(),
        'snapshot': snapshot,
      };

  factory ReportingSyncStatus.fromJson(Map<String, dynamic> json) {
    return ReportingSyncStatus(
      externalTransactionId: json['externalTransactionId'] as String,
      syncedAt: DateTime.parse(json['syncedAt'] as String).toLocal(),
      snapshot: json['snapshot'] as String,
    );
  }
}

class ReportingSyncProgress {
  const ReportingSyncProgress({
    required this.total,
    required this.pending,
    required this.synced,
    this.lastSyncedAt,
  });

  final int total;
  final int pending;
  final int synced;
  final DateTime? lastSyncedAt;
}
