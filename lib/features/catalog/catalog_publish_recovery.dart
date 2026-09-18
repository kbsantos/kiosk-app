import '../../product_catalog/product_catalog_models.dart';
import 'catalog_local_master_migration.dart';

/// Decides whether a master catalog can safely be adopted after a publish
/// request failed. This covers the case where the database commit succeeded
/// but the kiosk did not receive the RPC response.
class CatalogPublishRecovery {
  const CatalogPublishRecovery._();

  static bool canAdoptMaster(
    ProductCatalog attempted,
    ProductCatalog master,
  ) {
    return CatalogLocalMasterMigration.catalogsMatch(attempted, master);
  }
}
