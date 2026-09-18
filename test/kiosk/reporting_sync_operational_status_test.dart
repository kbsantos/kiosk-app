import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_operational_status.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_audit.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_status.dart';

void main() {
  ReportingSyncProgress progress({
    required int total,
    required int pending,
    required int synced,
    DateTime? lastSyncedAt,
  }) => ReportingSyncProgress(
        total: total,
        pending: pending,
        synced: synced,
        lastSyncedAt: lastSyncedAt,
      );

  test('reports pending when local transactions have not all synced', () {
    final status = ReportingSyncOperationalStatus.from(
      progress: progress(total: 10, pending: 3, synced: 7),
      latestAudit: null,
    );

    expect(status.state, ReportingSyncOperationalState.pending);
    expect(status.pending, 3);
    expect(status.synced, 7);
  });

  test('reports synced when every local transaction is acknowledged', () {
    final status = ReportingSyncOperationalStatus.from(
      progress: progress(total: 10, pending: 0, synced: 10),
      latestAudit: ReportingSyncAudit(
        id: 'sync-1',
        startedAt: DateTime(2026, 9, 19, 10),
        completedAt: DateTime(2026, 9, 19, 10, 1),
        attempted: 10,
        succeeded: 10,
        failed: 0,
        failures: const [],
      ),
    );

    expect(status.state, ReportingSyncOperationalState.synced);
    expect(status.lastError, isNull);
  });

  test('reports failed when latest audit contains failures', () {
    final status = ReportingSyncOperationalStatus.from(
      progress: progress(total: 10, pending: 2, synced: 8),
      latestAudit: ReportingSyncAudit(
        id: 'sync-2',
        startedAt: DateTime(2026, 9, 19, 10),
        completedAt: DateTime(2026, 9, 19, 10, 1),
        attempted: 4,
        succeeded: 2,
        failed: 2,
        failures: const [
          ReportingSyncAuditFailure(
            externalTransactionId: 'T-1',
            message: 'offline',
          ),
        ],
      ),
    );

    expect(status.state, ReportingSyncOperationalState.failed);
    expect(status.failed, 2);
    expect(status.lastError, 'offline');
  });

  test('reports no transactions when local history is empty', () {
    final status = ReportingSyncOperationalStatus.from(
      progress: progress(total: 0, pending: 0, synced: 0),
      latestAudit: null,
    );

    expect(status.state, ReportingSyncOperationalState.noTransactions);
  });
}
