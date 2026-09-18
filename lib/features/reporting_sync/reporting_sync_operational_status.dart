import 'reporting_sync_audit.dart';
import 'reporting_sync_status.dart';

enum ReportingSyncOperationalState {
  noTransactions,
  synced,
  pending,
  failed,
}

/// Read-only operational summary for the manual reporting synchronization UI.
/// Local transaction data remains authoritative; this model only combines
/// local acknowledgement metadata with the most recent local sync audit.
class ReportingSyncOperationalStatus {
  const ReportingSyncOperationalStatus({
    required this.state,
    required this.total,
    required this.pending,
    required this.synced,
    required this.failed,
    required this.lastSyncedAt,
    required this.lastAttemptAt,
    required this.lastError,
  });

  final ReportingSyncOperationalState state;
  final int total;
  final int pending;
  final int synced;
  final int failed;
  final DateTime? lastSyncedAt;
  final DateTime? lastAttemptAt;
  final String? lastError;

  factory ReportingSyncOperationalStatus.from({
    required ReportingSyncProgress progress,
    required ReportingSyncAudit? latestAudit,
  }) {
    final state = progress.total == 0
        ? ReportingSyncOperationalState.noTransactions
        : latestAudit != null && latestAudit.failed > 0
            ? ReportingSyncOperationalState.failed
            : progress.pending == 0
                ? ReportingSyncOperationalState.synced
                : ReportingSyncOperationalState.pending;

    return ReportingSyncOperationalStatus(
      state: state,
      total: progress.total,
      pending: progress.pending,
      synced: progress.synced,
      failed: latestAudit?.failed ?? 0,
      lastSyncedAt: progress.lastSyncedAt,
      lastAttemptAt: latestAudit?.completedAt,
      lastError: latestAudit?.failures.isNotEmpty == true
          ? latestAudit!.failures.first.message
          : null,
    );
  }
}
