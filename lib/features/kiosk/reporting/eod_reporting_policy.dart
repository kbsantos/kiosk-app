/// Documents the local-first EOD reporting boundary.
///
/// Report generation and email use the local kiosk snapshot. Cloud reporting
/// synchronization is a separate, explicit staff action.
class EodReportingPolicy {
  const EodReportingPolicy._();

  static const bool canGenerateLocalPdf = true;
  static const bool requiresSuccessfulSyncForPdf = false;
  static const bool canEmailLocalPdf = true;
  static const bool requiresSuccessfulSyncForEmail = false;
  static const bool isExplicitSyncAction = true;
}
