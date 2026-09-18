import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/product_option_manager.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_master_service.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';

class _FakeCatalogRepository extends ProductCatalogRepository {
  _FakeCatalogRepository(this.catalog);

  ProductCatalog catalog;
  bool saveDefinitionsCalled = false;
  bool saveProductsCalled = false;

  @override
  Future<ProductCatalog> load() async => catalog;

  @override
  Future<void> saveOptionDefinitions(
    List<CatalogOptionDefinition> definitions,
  ) async {
    saveDefinitionsCalled = true;
    throw StateError('Option Manager must not write definitions directly.');
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    saveProductsCalled = true;
    throw StateError('Option Manager must not write products directly.');
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

CatalogProduct _product({List<ProductOption> options = const []}) =>
    CatalogProduct(
      productId: 'cheeseburger',
      name: 'Cheeseburger',
      productType: 'food',
      categoryId: 'food',
      active: true,
      available: true,
      sizes: const [],
      variants: const [],
      options: options,
    );

ProductCatalog _catalog({
  List<CatalogOptionDefinition> definitions = const [],
  List<CatalogProduct> products = const [],
}) => ProductCatalog(
      catalogVersion: 'master-1',
      categories: const [
        ProductCategory(
          categoryId: 'food',
          name: 'Food',
          subtitle: '',
          active: true,
        ),
      ],
      optionDefinitions: definitions,
      products: products,
    );

void main() {
  test('shared option save publishes through Store Master', () async {
    final option = const CatalogOptionDefinition(
      optionId: 'takeout',
      name: 'Takeout',
      productTypes: ['food'],
      price: 5,
      active: true,
      kitchenPrepared: true,
    );
    final repository = _FakeCatalogRepository(_catalog());
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.addDefinition(option);

    expect(master.mutationCalls, 1);
    expect(repository.saveDefinitionsCalled, isFalse);
    expect(controller.definitions.single.price, 5);
    expect(controller.definitions.single.active, isTrue);
    expect(controller.definitions.single.kitchenPrepared, isTrue);
  });

  test('product option assignment publishes through Store Master', () async {
    final product = _product();
    final option = const ProductOption(
      optionId: 'takeout',
      name: 'Takeout',
      price: 5,
      active: true,
      kitchenPrepared: true,
    );
    final repository = _FakeCatalogRepository(_catalog(
      definitions: const [CatalogOptionDefinition(
        optionId: 'takeout',
        name: 'Takeout',
        productTypes: ['food'],
        price: 5,
        active: true,
      )],
      products: [product],
    ));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await controller.addProductOption(product, option);

    expect(master.mutationCalls, 1);
    expect(repository.saveProductsCalled, isFalse);
    expect(controller.products.single.options.single.price, 5);
    expect(controller.products.single.options.single.kitchenPrepared, isTrue);
  });

  test('shared option edit preserves current master product changes', () async {
    final option = const CatalogOptionDefinition(
      optionId: 'takeout',
      name: 'Takeout',
      productTypes: ['food'],
      price: 5,
      active: true,
    );
    final repository = _FakeCatalogRepository(_catalog(
      definitions: [option],
      products: [_product()],
    ));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    master.catalog = master.catalog.copyWith(
      products: [master.catalog.products.single.copyWith(
        name: 'Cheeseburger Special',
        price: 150,
        description: 'New master description',
      )],
    );

    await controller.updateDefinition(option.copyWith(
      price: 10,
      active: false,
      kitchenPrepared: true,
    ));

    expect(master.catalog.products.single.name, 'Cheeseburger Special');
    expect(master.catalog.products.single.price, 150);
    expect(master.catalog.products.single.description, 'New master description');
    expect(master.catalog.optionDefinitions.single.price, 10);
    expect(master.catalog.optionDefinitions.single.active, isFalse);
    expect(master.catalog.optionDefinitions.single.kitchenPrepared, isTrue);
  });

  test('product option edit only changes option fields on current master product', () async {
    final option = const ProductOption(
      optionId: 'takeout',
      name: 'Takeout',
      price: 5,
      active: true,
    );
    final product = _product(options: [option]);
    final definition = const CatalogOptionDefinition(
      optionId: 'takeout',
      name: 'Takeout',
      productTypes: ['food'],
      price: 5,
      active: true,
    );
    final repository = _FakeCatalogRepository(_catalog(
      definitions: [definition],
      products: [product],
    ));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    master.catalog = master.catalog.copyWith(
      products: [master.catalog.products.single.copyWith(
        name: 'Cheeseburger Special',
        price: 155,
        variants: const [ProductVariant(
          variantId: 'double',
          name: 'Double',
          price: 30,
          active: true,
        )],
      )],
    );

    await controller.updateProductOption(product, option.copyWith(
      price: 8,
      active: false,
      kitchenPrepared: true,
    ));

    final saved = master.catalog.products.single;
    expect(saved.name, 'Cheeseburger Special');
    expect(saved.price, 155);
    expect(saved.variants.single.variantId, 'double');
    expect(saved.options.single.price, 8);
    expect(saved.options.single.active, isFalse);
    expect(saved.options.single.kitchenPrepared, isTrue);
  });

  test('product option edit preserves another current master assignment', () async {
    final first = const ProductOption(
      optionId: 'takeout',
      name: 'Takeout',
      price: 5,
      active: true,
    );
    final second = const ProductOption(
      optionId: 'sauce',
      name: 'Sauce',
      price: 3,
      active: true,
    );
    final product = _product(options: [first]);
    final repository = _FakeCatalogRepository(_catalog(
      definitions: const [
        CatalogOptionDefinition(
          optionId: 'takeout',
          name: 'Takeout',
          productTypes: ['food'],
          price: 5,
          active: true,
        ),
        CatalogOptionDefinition(
          optionId: 'sauce',
          name: 'Sauce',
          productTypes: ['food'],
          price: 3,
          active: true,
        ),
      ],
      products: [product],
    ));
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    master.catalog = master.catalog.copyWith(
      products: [master.catalog.products.single.copyWith(
        options: [first, second],
      )],
    );

    await controller.updateProductOption(
      product,
      first.copyWith(price: 8),
    );

    expect(master.catalog.products.single.options, hasLength(2));
    expect(master.catalog.products.single.options[0].price, 8);
    expect(master.catalog.products.single.options[1].optionId, 'sauce');
  });

  test('shared option deletion remains blocked while assigned', () async {
    final option = const CatalogOptionDefinition(
      optionId: 'takeout',
      name: 'Takeout',
      productTypes: ['food'],
      price: 5,
      active: true,
    );
    final product = _product(options: const [
      ProductOption(
        optionId: 'takeout',
        name: 'Takeout',
        price: 5,
        active: true,
      ),
    ]);
    final repository = _FakeCatalogRepository(
      _catalog(definitions: [option], products: [product]),
    );
    final master = _FakeMasterService(repository.catalog);
    final controller = ProductOptionManagerController(
      repository: repository,
      masterService: master,
    );
    await controller.load();

    await expectLater(
      controller.deleteDefinition('takeout'),
      throwsA(isA<StateError>()),
    );
    // mutateCatalog is invoked to obtain the current master snapshot, but
    // the deletion is rejected inside the mutation before anything is
    // published. Verify the catalog remains unchanged.
    expect(master.mutationCalls, 1);
    expect(master.catalog.optionDefinitions, hasLength(1));
    expect(master.catalog.optionDefinitions.single.optionId, 'takeout');
  });
}
