import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/category_manager.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_master_service.dart';

class _FakeCatalogRepository extends ProductCatalogRepository {
  _FakeCatalogRepository(this.catalog);

  ProductCatalog catalog;
  bool saveCategoriesCalled = false;

  @override
  Future<ProductCatalog> load() async => catalog;

  @override
  Future<void> saveCategories(List<ProductCategory> categories) async {
    saveCategoriesCalled = true;
    throw StateError('Category Manager must not write directly to local categories.');
  }

}


class _FakeMasterService extends StoreCatalogMasterService {
  _FakeMasterService(this.catalog) : super();

  ProductCatalog catalog;
  int mutationCalls = 0;

  @override
  Future<ProductCatalog> loadMasterCatalog() async => catalog;

  @override
  Future<ProductCatalog> mutateCatalog(
    ProductCatalog Function(ProductCatalog catalog) mutation, {
    String auditAction = 'Update store master catalog',
  }) async {
    mutationCalls++;
    catalog = mutation(catalog).copyWith(catalogVersion: 'master-2');
    return catalog;
  }
}

void main() {
  test('category save does not bypass Store Master with a local category write', () async {
    final repository = _FakeCatalogRepository(
      const ProductCatalog(
        catalogVersion: 'master-1',
        categories: [
          ProductCategory(
            categoryId: 'coffee',
            name: 'Coffee',
            subtitle: '',
            active: true,
          ),
        ],
        products: [],
      ),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = CategoryManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.save(
      const ProductCategory(
        categoryId: 'coffee',
        name: 'Coffee & Espresso',
        subtitle: '',
        active: true,
      ),
    );

    expect(master.mutationCalls, 1);
    expect(repository.saveCategoriesCalled, isFalse);
    expect(controller.categories.single.name, 'Coffee & Espresso');
    expect(controller.categories, master.catalog.categories);
  });


  test('category add publishes against the master catalog', () async {
    final repository = _FakeCatalogRepository(
      const ProductCatalog(
        catalogVersion: 'master-1',
        categories: [],
        products: [],
      ),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = CategoryManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.add(
      categoryId: 'coffee',
      name: 'Coffee',
      subtitle: 'Espresso drinks',
    );

    expect(master.mutationCalls, 1);
    expect(controller.categories.single.categoryId, 'coffee');
    expect(repository.saveCategoriesCalled, isFalse);
  });

  test('category delete validates product references from the master catalog', () async {
    final repository = _FakeCatalogRepository(
      const ProductCatalog(
        catalogVersion: 'master-1',
        categories: [
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
      ),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = CategoryManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await expectLater(
      controller.delete(controller.categories.single),
      throwsA(isA<StateError>()),
    );

    expect(master.mutationCalls, 1);
    expect(controller.categories.single.categoryId, 'coffee');
    expect(repository.saveCategoriesCalled, isFalse);
  });
}

