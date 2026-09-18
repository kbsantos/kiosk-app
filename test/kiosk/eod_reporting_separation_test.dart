import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/reporting/eod_reporting_policy.dart';

void main() {
  test('PDF report is always available from local data without sync', () {
    expect(EodReportingPolicy.canGenerateLocalPdf, isTrue);
    expect(EodReportingPolicy.requiresSuccessfulSyncForPdf, isFalse);
  });

  test('email report uses local data and does not require reporting sync', () {
    expect(EodReportingPolicy.canEmailLocalPdf, isTrue);
    expect(EodReportingPolicy.requiresSuccessfulSyncForEmail, isFalse);
  });

  test('reporting sync remains an explicit separate action', () {
    expect(EodReportingPolicy.isExplicitSyncAction, isTrue);
  });
}
