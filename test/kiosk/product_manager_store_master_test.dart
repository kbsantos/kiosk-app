import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/product_manager.dart';
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
    throw StateError('Product Manager must not write directly to local products.');
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

CatalogProduct _product({String name = 'Latte'}) => CatalogProduct(
      productId: 'latte',
      name: name,
      productType: 'drink',
      categoryId: 'coffee',
      active: true,
      available: true,
      sizes: const [],
      variants: const [],
      options: const [],
    );

ProductCatalog _catalog({List<CatalogProduct> products = const []}) =>
    ProductCatalog(
      catalogVersion: 'master-1',
      categories: const [
        ProductCategory(
          categoryId: 'coffee',
          name: 'Coffee',
          subtitle: '',
          active: true,
        ),
      ],
      products: products,
    );

void main() {
  test('product save publishes through Store Master instead of local products',
      () async {
    final repository = _FakeCatalogRepository(_catalog(products: [_product()]));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.save(_product(name: 'Cafe Latte'));

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products.single.name, 'Cafe Latte');
    expect(master.catalog.products.single.name, 'Cafe Latte');
  });

  test('product add publishes through Store Master instead of local products',
      () async {
    final repository = _FakeCatalogRepository(_catalog());
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.add(_product());

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products.single.productId, 'latte');
  });

  test('product delete publishes through Store Master instead of local products',
      () async {
    final repository = _FakeCatalogRepository(_catalog(products: [_product()]));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.delete(controller.products.single);

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products, isEmpty);
    expect(master.catalog.products, isEmpty);
  });
}
