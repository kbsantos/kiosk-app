import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_recovery_store_master.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_master_service.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_repository.dart';

class _FakeRepository extends ProductCatalogRepository {
  _FakeRepository(this.catalog, this.bundled, this.backupCatalog);

  ProductCatalog catalog;
  final ProductCatalog bundled;
  ProductCatalog? backupCatalog;
  int backupCalls = 0;
  int saveCalls = 0;
  int clearRecoveryCalls = 0;

  @override
  Future<ProductCatalog> load() async => catalog;

  @override
  Future<ProductCatalog> loadBundledCatalog() async => bundled;

  @override
  Future<ProductCatalog?> loadBackup() async => backupCatalog;

  @override
  Future<void> saveBackup(ProductCatalog catalog) async {
    backupCalls++;
  }

  @override
  Future<void> saveImportRecoveryBackup(ProductCatalog catalog) async {}

  @override
  Future<void> clearImportRecoveryBackup() async { clearRecoveryCalls++; }

  @override
  Future<void> saveCatalog(ProductCatalog catalog,
      {String auditAction = 'Restore catalog snapshot'}) async {
    saveCalls++;
    this.catalog = catalog;
  }
}

class _FakeMasterService extends StoreCatalogMasterService {
  _FakeMasterService(this.catalog) : super();

  ProductCatalog catalog;
  int publishCalls = 0;
  String? expectedVersion;
  bool failPublish = false;

  @override
  Future<ProductCatalog> loadMasterCatalog() async => catalog;

  @override
  Future<ProductCatalog> publishCatalog(ProductCatalog next,
      {String auditAction = 'Publish catalog to store master',
      String? expectedVersion}) async {
    publishCalls++;
    this.expectedVersion = expectedVersion;
    if (failPublish) throw StateError('publish failed');
    catalog = next.copyWith(catalogVersion: 'master-2');
    return catalog;
  }
}

ProductCatalog _catalog({
  String version = 'master-1',
  String categoryName = 'Coffee',
  String productName = 'Latte',
}) => ProductCatalog(
      catalogVersion: version,
      categories: [
        ProductCategory(
          categoryId: 'coffee',
          name: categoryName,
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

void main() {
  test('import publishes the selected catalog to Store Master', () async {
    final local = _catalog();
    final repository = _FakeRepository(local, local, local);
    final master = _FakeMasterService(local);
    final coordinator = CatalogRecoveryStoreMaster(
      repository: repository,
      masterService: master,
    );

    await coordinator.applyImportedCatalog(
      currentLocal: local,
      mergedCatalog: local.copyWith(
        products: [local.products.single.copyWith(name: 'Cafe Latte')],
      ),
    );

    expect(master.publishCalls, 1);
    expect(master.expectedVersion, 'master-1');
    expect(repository.backupCalls, 1);
    expect(repository.saveCalls, 0);
  });

  test('import rejects a stale local catalog before publishing', () async {
    final local = _catalog(version: 'master-1');
    final masterCatalog = _catalog(version: 'master-9', productName: 'New Latte');
    final repository = _FakeRepository(local, local, local);
    final master = _FakeMasterService(masterCatalog);
    final coordinator = CatalogRecoveryStoreMaster(
      repository: repository,
      masterService: master,
    );

    expect(
      () => coordinator.applyImportedCatalog(
        currentLocal: local,
        mergedCatalog: local,
      ),
      throwsA(isA<StateError>()),
    );
    expect(master.publishCalls, 0);
    expect(repository.backupCalls, 0);
  });


  test('rejected import does not leave a misleading rollback point', () async {
    final local = _catalog();
    final repository = _FakeRepository(local, local, local);
    final master = _FakeMasterService(local)..failPublish = true;
    final coordinator = CatalogRecoveryStoreMaster(
      repository: repository,
      masterService: master,
    );

    await expectLater(
      coordinator.applyImportedCatalog(
        currentLocal: local,
        mergedCatalog: local,
      ),
      throwsA(isA<StateError>()),
    );

    expect(repository.clearRecoveryCalls, 1);
  });

  test('backup restore publishes the saved snapshot to Store Master', () async {
    final current = _catalog(productName: 'Current Latte');
    final backup = _catalog(productName: 'Restored Latte');
    final repository = _FakeRepository(current, current, backup);
    final master = _FakeMasterService(_catalog(version: 'master-8'));
    final coordinator = CatalogRecoveryStoreMaster(
      repository: repository,
      masterService: master,
    );

    final restored = await coordinator.restoreBackup();

    expect(restored.products.single.name, 'Restored Latte');
    expect(master.publishCalls, 1);
    expect(master.expectedVersion, 'master-8');
    expect(repository.backupCalls, 1);
  });

  test('reset to bundled catalog publishes the bundled snapshot', () async {
    final current = _catalog(productName: 'Current Latte');
    final bundled = _catalog(productName: 'Bundled Latte');
    final repository = _FakeRepository(current, bundled, current);
    final master = _FakeMasterService(_catalog(version: 'master-5'));
    final coordinator = CatalogRecoveryStoreMaster(
      repository: repository,
      masterService: master,
    );

    final reset = await coordinator.resetToBundled();

    expect(reset.products.single.name, 'Bundled Latte');
    expect(master.publishCalls, 1);
    expect(master.expectedVersion, 'master-5');
    expect(repository.backupCalls, 1);
  });
}
