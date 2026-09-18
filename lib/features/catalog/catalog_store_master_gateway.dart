import 'store_catalog_sync_service.dart';

/// Single gateway for catalog replacement actions initiated by the catalog
/// management UI. It deliberately delegates the write/refresh semantics to
/// StoreCatalogSyncService so callers cannot accidentally persist a master
/// catalog directly to the local cache.
class CatalogStoreMasterGateway {
  const CatalogStoreMasterGateway(this._syncService);

  final StoreCatalogSyncService _syncService;

  Future<StoreCatalogSyncResult> refreshFromMaster() {
    return _syncService.refreshFromMaster();
  }
}
