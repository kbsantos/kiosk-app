import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_local_master_migration.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';

ProductCatalog _catalog({
  String version = 'db-v1',
  List<CatalogProduct>? products,
}) {
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
    products: products ?? const [
      CatalogProduct(
        productId: 'latte',
        name: 'Latte',
        productType: 'drink',
        categoryId: 'coffee',
        active: true,
        available: true,
        sizes: [],
        variants: [],
        options: [],
      ),
    ],
  );
}

void main() {
  group('CatalogLocalMasterMigration', () {
    test('rejects an empty local catalog before migration', () {
      expect(
        () => CatalogLocalMasterMigration.ensureHasProducts(
          _catalog(products: const []),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('allows a populated local catalog to migrate', () {
      expect(
        () => CatalogLocalMasterMigration.ensureHasProducts(_catalog()),
        returnsNormally,
      );
    });

    test('detects identical catalogs without their version field', () {
      final local = _catalog(version: 'db-v7');
      final master = _catalog(version: 'db-v7');

      expect(
        CatalogLocalMasterMigration.catalogsMatch(local, master),
        isTrue,
      );
    });

    test('detects a catalog content change even when versions match', () {
      final local = _catalog(version: 'db-v7');
      final master = _catalog(version: 'db-v7').copyWith(
        products: [
          local.products.single.copyWith(name: 'Cappuccino'),
        ],
      );

      expect(
        CatalogLocalMasterMigration.catalogsMatch(local, master),
        isFalse,
      );
    });

    test('detects a catalog content change when versions differ', () {
      final local = _catalog(version: 'db-v7');
      final master = _catalog(version: 'db-v8');

      expect(
        CatalogLocalMasterMigration.catalogsMatch(local, master),
        isTrue,
      );
    });
  });
}
