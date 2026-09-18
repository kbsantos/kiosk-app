import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_reliability.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/reporting_sync_result.dart';

void main() {
  test('failed transaction remains retryable', () {
    const failure = ReportingSyncFailure(
      externalTransactionId: 'T-100',
      orderNumber: 'BB-100',
      message: 'offline',
    );

    expect(ReportingSyncReliability.isRetryable(failure), isTrue);
  });

  test('partial sync leaves unacknowledged transactions pending', () {
    const result = ReportingSyncResult(
      attempted: 5,
      succeeded: 3,
      failures: [
        ReportingSyncFailure(
          externalTransactionId: 'T-4',
          orderNumber: 'BB-4',
          message: 'timeout',
        ),
        ReportingSyncFailure(
          externalTransactionId: 'T-5',
          orderNumber: 'BB-5',
          message: 'offline',
        ),
      ],
    );

    expect(
      ReportingSyncReliability.pendingAfterAttempt(
        pendingBefore: 5,
        result: result,
      ),
      2,
    );
  });

  test('retry does not create a negative pending count', () {
    const result = ReportingSyncResult(
      attempted: 2,
      succeeded: 2,
      failures: [],
    );

    expect(
      ReportingSyncReliability.pendingAfterAttempt(
        pendingBefore: 1,
        result: result,
      ),
      0,
    );
  });
}
