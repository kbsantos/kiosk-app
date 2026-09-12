/// Summary of a manual reporting sync attempt.
///
/// This is reporting-only metadata. It never changes the local kiosk orders.
class ReportingSyncResult {
  final int attempted;
  final int succeeded;
  final List<ReportingSyncFailure> failures;

  const ReportingSyncResult({
    required this.attempted,
    required this.succeeded,
    required this.failures,
  });

  int get failed => failures.length;

  bool get isSuccess => failed == 0;

  String get summary =>
      '$succeeded of $attempted transaction${attempted == 1 ? '' : 's'} synced'
      '${failed == 0 ? '' : ' ($failed failed)'}';
}

class ReportingSyncFailure {
  final String externalTransactionId;
  final String orderNumber;
  final String message;

  const ReportingSyncFailure({
    required this.externalTransactionId,
    required this.orderNumber,
    required this.message,
  });
}
