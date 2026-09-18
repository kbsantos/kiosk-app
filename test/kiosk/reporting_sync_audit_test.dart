import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_audit.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('records a completed sync attempt and preserves the result', () async {
    final store = ReportingSyncAuditStore();
    final startedAt = DateTime(2026, 9, 19, 11);
    final completedAt = DateTime(2026, 9, 19, 11, 1);

    await store.record(
      ReportingSyncAudit(
        id: 'attempt-1',
        startedAt: startedAt,
        completedAt: completedAt,
        attempted: 5,
        succeeded: 5,
        failed: 0,
        failures: const [],
      ),
    );

    final latest = await store.latest();
    expect(latest, isNotNull);
    expect(latest!.id, 'attempt-1');
    expect(latest.attempted, 5);
    expect(latest.succeeded, 5);
    expect(latest.failed, 0);
  });

  test('failed and partial attempts are retained for retry visibility', () async {
    final store = ReportingSyncAuditStore();

    await store.record(
      ReportingSyncAudit(
        id: 'attempt-1',
        startedAt: DateTime(2026, 9, 19, 11),
        completedAt: DateTime(2026, 9, 19, 11, 1),
        attempted: 3,
        succeeded: 1,
        failed: 2,
        failures: const [
          ReportingSyncAuditFailure(
            externalTransactionId: 'T-2',
            message: 'offline',
          ),
          ReportingSyncAuditFailure(
            externalTransactionId: 'T-3',
            message: 'timeout',
          ),
        ],
      ),
    );

    final latest = await store.latest();
    expect(latest!.failed, 2);
    expect(latest.failures.map((e) => e.externalTransactionId),
        containsAll(<String>['T-2', 'T-3']));
  });

  test('audit history is bounded and newest attempt is returned', () async {
    final store = ReportingSyncAuditStore(maxEntries: 2);

    for (var i = 1; i <= 3; i++) {
      await store.record(
        ReportingSyncAudit(
          id: 'attempt-$i',
          startedAt: DateTime(2026, 9, 19, 11, i),
          completedAt: DateTime(2026, 9, 19, 11, i, 1),
          attempted: i,
          succeeded: i,
          failed: 0,
          failures: const [],
        ),
      );
    }

    final history = await store.history();
    expect(history, hasLength(2));
    expect(history.first.id, 'attempt-3');
    expect((await store.latest())!.id, 'attempt-3');
  });
}
