import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/product_category_assignment.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_master_service.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';

class _FakeCatalogRepository extends ProductCatalogRepository {
  _FakeCatalogRepository(this.catalog);

  ProductCatalog catalog;
  bool saveProductsCalled = false;

  @override
  Future<ProductCatalog> load() async => catalog;

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    saveProductsCalled = true;
    throw StateError('Category assignment must not write directly to local products.');
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

ProductCategory _category(String id, String name) => ProductCategory(
      categoryId: id,
      name: name,
      subtitle: '',
      active: true,
    );

CatalogProduct _product({
  String categoryId = 'coffee',
  String name = 'Latte',
}) => CatalogProduct(
      productId: 'latte',
      name: name,
      productType: 'drink',
      categoryId: categoryId,
      active: true,
      available: true,
      sizes: const [],
      variants: const [],
      options: const [],
    );

ProductCatalog _catalog({
  List<ProductCategory> categories = const [],
  List<CatalogProduct> products = const [],
}) => ProductCatalog(
      catalogVersion: 'master-1',
      categories: categories,
      products: products,
    );

void main() {
  test('category assignment publishes through Store Master instead of local products', () async {
    final repository = _FakeCatalogRepository(_catalog(
      categories: [_category('coffee', 'Coffee'), _category('tea', 'Tea')],
      products: [_product()],
    ));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductCategoryAssignmentController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.assignProduct(controller.products.single, 'tea');

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(master.catalog.products.single.categoryId, 'tea');
    expect(controller.products.single.categoryId, 'tea');
  });

  test('category assignment validates category against the current master catalog', () async {
    final repository = _FakeCatalogRepository(_catalog(
      categories: [_category('coffee', 'Coffee')],
      products: [_product()],
    ));
    final master = _FakeMasterService(_catalog(
      categories: [_category('coffee', 'Coffee'), _category('tea', 'Tea')],
      products: [_product()],
    ));
    final controller = ProductCategoryAssignmentController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.assignProduct(controller.products.single, 'tea');

    expect(master.mutationCalls, 1);
    expect(controller.products.single.categoryId, 'tea');
  });

  test('category assignment rejects a category missing from the current master catalog', () async {
    final repository = _FakeCatalogRepository(_catalog(
      categories: [_category('coffee', 'Coffee')],
      products: [_product()],
    ));
    final master = _FakeMasterService(_catalog(
      categories: [_category('coffee', 'Coffee')],
      products: [_product()],
    ));
    final controller = ProductCategoryAssignmentController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await expectLater(
      controller.assignProduct(controller.products.single, 'missing'),
      throwsA(isA<StateError>()),
    );
    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
  });

  test('category assignment preserves current master product fields instead of stale local product data', () async {
    final repository = _FakeCatalogRepository(_catalog(
      categories: [_category('coffee', 'Coffee'), _category('tea', 'Tea')],
      products: [_product(name: 'Old Latte')],
    ));
    final master = _FakeMasterService(_catalog(
      categories: [_category('coffee', 'Coffee'), _category('tea', 'Tea')],
      products: [_product(name: 'Current Latte')],
    ));
    final controller = ProductCategoryAssignmentController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.assignProduct(_product(name: 'Stale Latte'), 'tea');

    expect(master.catalog.products.single.name, 'Current Latte');
    expect(master.catalog.products.single.categoryId, 'tea');
  });

  test('category assignment rejects a missing product from the current master catalog', () async {
    final localProduct = _product();
    final repository = _FakeCatalogRepository(_catalog(
      categories: [_category('coffee', 'Coffee')],
      products: [localProduct],
    ));
    final master = _FakeMasterService(_catalog(
      categories: [_category('coffee', 'Coffee')],
      products: const [],
    ));
    final controller = ProductCategoryAssignmentController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    // The current master has no products, so the controller's loaded list is
    // intentionally empty. Use the local product object as the stale UI
    // request to verify that the master rejects the missing product.
    await expectLater(
      controller.assignProduct(localProduct, 'coffee'),
      throwsA(isA<StateError>()),
    );
    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
  });
}
