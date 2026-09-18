import '../../product_catalog/product_catalog_models.dart';

class CatalogSyncVersionGuard {
  const CatalogSyncVersionGuard._();

  static String ensureLocalMatchesMaster({
    required String? localVersion,
    required String? masterVersion,
  }) {
    final master = masterVersion?.trim() ?? '';
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

    return local;
  }

  static ProductCatalog withAuthoritativeVersion(
    ProductCatalog catalog,
    String masterVersion,
  ) {
    final version = ensureCatalogVersionMatchesMaster(
      catalogVersion: masterVersion,
      masterVersion: masterVersion,
    );
    return catalog.copyWith(catalogVersion: version);
  }

  static String ensureCatalogVersionMatchesMaster({
    required String? catalogVersion,
    required String? masterVersion,
  }) {
    final master = masterVersion?.trim() ?? '';
    if (master.isEmpty) {
      throw StateError('The store catalog master has no catalog version.');
    }

    final catalog = catalogVersion?.trim() ?? '';
    if (catalog.isEmpty) {
      throw StateError(
        'The store catalog master returned a catalog without a version.',
      );
    }

    if (catalog != master) {
      throw StateError(
        'The store catalog payload version does not match the master version. '
        'Catalog version: $catalog; master version: $master.',
      );
    }

    return master;
  }
}
