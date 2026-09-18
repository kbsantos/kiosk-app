import 'reporting_sync_result.dart';

/// Pure reporting-sync reliability rules used by the kiosk workflow.
class ReportingSyncReliability {
  const ReportingSyncReliability._();

  /// A transaction is retryable whenever it was not acknowledged in the
  /// current sync attempt. The local snapshot store remains authoritative;
  /// successful acknowledgements are the only state that can become synced.
  static bool isRetryable(ReportingSyncFailure failure) =>
      failure.externalTransactionId.trim().isNotEmpty;

  /// A partial sync is successful only for the transactions explicitly
  /// acknowledged by the reporting RPC. The remainder must stay pending.
  static int pendingAfterAttempt({
    required int pendingBefore,
    required ReportingSyncResult result,
  }) {
    final remaining = pendingBefore - result.succeeded;
    return remaining < 0 ? 0 : remaining;
  }
}
