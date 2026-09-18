
/// Describes the relationship between the kiosk's local catalog and the
/// store-level master catalog.
enum CatalogSyncStatus {
  masterUnavailable,
  masterNotInitialized,
  notLinked,
  inSync,
  localChangesPending,
  masterChanged,
}

class CatalogSyncStatusSnapshot {
  const CatalogSyncStatusSnapshot({
    required this.status,
    this.localVersion,
    this.masterVersion,
  });

  final CatalogSyncStatus status;
  final String? localVersion;
  final String? masterVersion;

  String get title {
    switch (status) {
      case CatalogSyncStatus.masterUnavailable:
        return 'MASTER UNAVAILABLE';
      case CatalogSyncStatus.masterNotInitialized:
        return 'MASTER NOT INITIALIZED';
      case CatalogSyncStatus.notLinked:
        return 'NOT LINKED TO MASTER';
      case CatalogSyncStatus.inSync:
        return 'IN SYNC';
      case CatalogSyncStatus.localChangesPending:
        return 'LOCAL CHANGES PENDING';
      case CatalogSyncStatus.masterChanged:
        return 'MASTER CHANGED';
    }
  }

  String get message {
    switch (status) {
      case CatalogSyncStatus.masterUnavailable:
        return 'The store master catalog could not be checked. The current local catalog remains available.';
      case CatalogSyncStatus.masterNotInitialized:
        return 'No store master catalog exists yet. Initialize the master from this kiosk when the local catalog is ready.';
      case CatalogSyncStatus.notLinked:
        return 'This kiosk has no recorded master version. Refresh the catalog before publishing local changes.';
      case CatalogSyncStatus.inSync:
        return 'The kiosk catalog matches the current store master catalog.';
      case CatalogSyncStatus.localChangesPending:
        return 'The kiosk version matches the store master, but local catalog content has changed and has not been published.';
      case CatalogSyncStatus.masterChanged:
        return 'The store master changed after this kiosk last synchronized. Refresh before publishing local changes.';
    }
  }
}

class CatalogSyncStatusResolver {
  const CatalogSyncStatusResolver._();

  static CatalogSyncStatusSnapshot resolve({
    required bool masterAvailable,
    required bool masterExists,
    required String? localVersion,
    required String? masterVersion,
    required bool catalogsMatch,
  }) {
    if (!masterAvailable) {
      return CatalogSyncStatusSnapshot(
        status: CatalogSyncStatus.masterUnavailable,
        localVersion: localVersion,
        masterVersion: masterVersion,
      );
    }

    if (!masterExists) {
      return CatalogSyncStatusSnapshot(
        status: CatalogSyncStatus.masterNotInitialized,
        localVersion: localVersion,
        masterVersion: masterVersion,
      );
    }

    final local = localVersion?.trim() ?? '';
    final master = masterVersion?.trim() ?? '';

    if (local.isEmpty) {
      return CatalogSyncStatusSnapshot(
        status: CatalogSyncStatus.notLinked,
        localVersion: localVersion,
        masterVersion: masterVersion,
      );
    }

    if (local != master) {
      return CatalogSyncStatusSnapshot(
        status: CatalogSyncStatus.masterChanged,
        localVersion: localVersion,
        masterVersion: masterVersion,
      );
    }

    return CatalogSyncStatusSnapshot(
      status: catalogsMatch
          ? CatalogSyncStatus.inSync
          : CatalogSyncStatus.localChangesPending,
      localVersion: localVersion,
      masterVersion: masterVersion,
    );
  }

}
