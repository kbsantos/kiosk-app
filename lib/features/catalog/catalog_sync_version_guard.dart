class CatalogSyncVersionGuard {
  const CatalogSyncVersionGuard._();

  static void ensureLocalMatchesMaster({
    required String? localVersion,
    required String masterVersion,
  }) {
    final master = masterVersion.trim();
    if (master.isEmpty) {
      throw StateError('The store catalog master has no catalog version.');
    }

    final local = localVersion?.trim() ?? '';
    if (local.isEmpty) {
      throw StateError(
        'This kiosk is not linked to the current store master catalog. '
        'Refresh the product catalog before publishing local changes.',
      );
    }

    if (local != master) {
      throw StateError(
        'The store master catalog changed after this kiosk last synchronized. '
        'Refresh the product catalog before publishing local changes. '
        'Master version: $master; kiosk version: $local.',
      );
    }
  }
}
