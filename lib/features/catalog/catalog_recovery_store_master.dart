import '../../product_catalog/product_catalog_models.dart';
import '../../product_catalog/product_catalog_repository.dart';
import 'store_catalog_master_service.dart';

/// Coordinates catalog recovery/import actions so they cannot create a local
/// catalog that is out of sync with the Store Master.
class CatalogRecoveryStoreMaster {
  CatalogRecoveryStoreMaster({
    ProductCatalogRepository? repository,
    StoreCatalogMasterService? masterService,
  })  : _repository = repository ?? const ProductCatalogRepository(),
        _masterService = masterService ?? StoreCatalogMasterService();

  final ProductCatalogRepository _repository;
  final StoreCatalogMasterService _masterService;

  /// Applies an import that was previewed against [currentLocal]. The local
  /// version must still match Store Master before the imported merge is
  /// published; otherwise the caller must refresh/review the import again.
  Future<ProductCatalog> applyImportedCatalog({
    required ProductCatalog currentLocal,
    required ProductCatalog mergedCatalog,
  }) async {
    final master = await _masterService.loadMasterCatalog();
    if (currentLocal.catalogVersion.trim() != master.catalogVersion.trim()) {
      throw StateError(
        'The Store Master catalog changed while this import was being reviewed. '
        'Refresh the catalog and review the import again.',
      );
    }

    await _repository.saveImportRecoveryBackup(currentLocal);
    await _repository.saveBackup(currentLocal);
    try {
      return await _masterService.publishCatalog(
        mergedCatalog,
        expectedVersion: master.catalogVersion,
        auditAction: 'Selective catalog import',
      );
    } catch (_) {
      // The recovery point represents the last accepted import, so do not
      // leave a misleading rollback point when Store Master rejects it.
      await _repository.clearImportRecoveryBackup();
      rethrow;
    }
  }

  /// Explicitly restores a saved snapshot to Store Master. This is a
  /// deliberate catalog mutation, not a local-only override.
  Future<ProductCatalog> restoreBackup() async {
    final backup = await _repository.loadBackup();
    if (backup == null) {
      throw StateError('No catalog backup is available.');
    }
    return restoreSnapshot(
      backup,
      auditAction: 'Restore catalog backup to store master',
    );
  }

  /// Restores an arbitrary validated snapshot (for example, clipboard or the
  /// last-import recovery point) to the current Store Master version.
  Future<ProductCatalog> restoreSnapshot(
    ProductCatalog snapshot, {
    String auditAction = 'Restore catalog snapshot to store master',
  }) async {
    final current = await _repository.load();
    final master = await _masterService.loadMasterCatalog();
    await _repository.saveBackup(current);
    return _masterService.publishCatalog(
      snapshot,
      expectedVersion: master.catalogVersion,
      auditAction: auditAction,
    );
  }

  Future<ProductCatalog> rollbackLastImport(ProductCatalog recovery) async {
    final current = await _repository.load();
    final master = await _masterService.loadMasterCatalog();
    await _repository.saveBackup(current);
    final restored = await _masterService.publishCatalog(
      recovery,
      expectedVersion: master.catalogVersion,
      auditAction: 'Rollback last catalog import to store master',
    );
    await _repository.clearImportRecoveryBackup();
    return restored;
  }

  Future<ProductCatalog> resetToBundled() async {
    final bundled = await _repository.loadBundledCatalog();
    return restoreSnapshot(
      bundled,
      auditAction: 'Reset to bundled catalog in store master',
    );
  }
}
