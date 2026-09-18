import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_local_master_migration.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_publish_recovery.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

ProductCatalog _catalog({String version = 'db-v1', String productName = 'Latte'}) {
  return ProductCatalog(
    catalogVersion: version,
    categories: const [
      ProductCategory(
        categoryId: 'coffee',
        name: 'Coffee',
        subtitle: '',
        active: true,
      ),
    ],
    products: [
      CatalogProduct(
        productId: 'latte',
        name: productName,
        productType: 'drink',
        categoryId: 'coffee',
        active: true,
        available: true,
        sizes: const [],
        variants: const [],
        options: const [],
      ),
    ],
  );
}

void main() {
  group('CatalogPublishRecovery', () {
    test('adopts master when publish response was lost after an identical commit', () {
      final attempted = _catalog(version: 'db-v7');
      final master = _catalog(version: 'db-v8');

      expect(
        CatalogPublishRecovery.canAdoptMaster(attempted, master),
        isTrue,
      );
      expect(CatalogLocalMasterMigration.catalogsMatch(attempted, master), isTrue);
    });

    test('does not adopt a different master after a failed publish', () {
      final attempted = _catalog(version: 'db-v7');
      final master = _catalog(version: 'db-v8', productName: 'Cappuccino');

      expect(
        CatalogPublishRecovery.canAdoptMaster(attempted, master),
        isFalse,
      );
    });
  });
}
