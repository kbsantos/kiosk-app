import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/product_size_variant_manager.dart';
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
    throw StateError('Size/Variant Manager must not write directly to local products.');
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

CatalogProduct _product({List<ProductSize> sizes = const [], List<ProductVariant> variants = const []}) =>
    CatalogProduct(
      productId: 'latte',
      name: 'Latte',
      productType: 'drink',
      categoryId: 'coffee',
      active: true,
      available: true,
      sizes: sizes,
      variants: variants,
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
  test('size save publishes through Store Master instead of local products', () async {
    final size = const ProductSize(
      sizeId: 'large',
      name: 'Large',
      price: 20,
    );
    final repository = _FakeCatalogRepository(
      _catalog(products: [_product(sizes: [size])]),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductSizeVariantManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.updateSize(
      controller.products.single,
      size.copyWith(price: 25),
    );

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products.single.sizes.single.price, 25);
    expect(master.catalog.products.single.sizes.single.price, 25);
  });

  test('variant save publishes through Store Master instead of local products', () async {
    final variant = const ProductVariant(
      variantId: 'oat',
      name: 'Oat Milk',
      price: 15,
      active: true,
    );
    final repository = _FakeCatalogRepository(
      _catalog(products: [_product(variants: [variant])]),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductSizeVariantManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.updateVariant(
      controller.products.single,
      variant.copyWith(price: 18),
    );

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products.single.variants.single.price, 18);
    expect(master.catalog.products.single.variants.single.price, 18);
  });

  test('variant edit only changes the variant fields on the current Store Master product', () async {
    final variant = const ProductVariant(
      variantId: 'oat',
      name: 'Oat Milk',
      price: 15,
      active: true,
    );
    final repository = _FakeCatalogRepository(
      _catalog(products: [_product(variants: [variant])]),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductSizeVariantManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    // Simulate a newer master edit made after this manager loaded the product.
    final currentMasterProduct = master.catalog.products.single.copyWith(
      name: 'Latte Special',
      description: 'Master description',
      price: 150,
      options: const [
        ProductOption(
          optionId: 'syrup',
          name: 'Vanilla Syrup',
          price: 10,
          active: true,
        ),
      ],
    );
    master.catalog = master.catalog.copyWith(products: [currentMasterProduct]);

    await controller.updateVariant(
      controller.products.single,
      variant.copyWith(price: 18, active: false),
    );

    final saved = master.catalog.products.single;
    expect(saved.name, 'Latte Special');
    expect(saved.description, 'Master description');
    expect(saved.price, 150);
    expect(saved.options.single.optionId, 'syrup');
    expect(saved.variants.single.price, 18);
    expect(saved.variants.single.active, isFalse);
  });
}
