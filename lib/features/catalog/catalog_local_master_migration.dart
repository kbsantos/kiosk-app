import 'dart:convert';

import '../../product_catalog/product_catalog_models.dart';

/// Guards local catalog migrations so an empty or stale operational catalog
/// cannot accidentally become the store master.
class CatalogLocalMasterMigration {
  const CatalogLocalMasterMigration._();

  static void ensureHasProducts(ProductCatalog catalog) {
    if (catalog.products.isEmpty) {
      throw StateError(
        'The local kiosk catalog has no products. Refusing to initialize or '
        'replace the store master with an empty catalog.',
      );
    }
  }

  /// Compares catalog content while deliberately ignoring the synchronization
  /// version. A matching version does not necessarily mean the catalog data
  /// is identical because a local catalog may contain an explicit unsynced
  /// change that still carries the last accepted master version.
  static bool catalogsMatch(ProductCatalog local, ProductCatalog master) {
    final localJson = local.copyWith(catalogVersion: '').toJson();
    final masterJson = master.copyWith(catalogVersion: '').toJson();
    return jsonEncode(localJson) == jsonEncode(masterJson);
  }
}
