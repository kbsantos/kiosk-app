import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_store_master_gateway.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_sync_service.dart';

class _FakeCatalogSyncService extends StoreCatalogSyncService {
  _FakeCatalogSyncService() : super();

  int refreshCalls = 0;
  bool forceSeen = false;

  @override
  Future<StoreCatalogSyncResult> refreshFromMaster({bool force = false}) async {
    refreshCalls++;
    forceSeen = force;
    return const StoreCatalogSyncResult(
      catalogVersion: 'master-2',
      categoryCount: 2,
      productCount: 3,
      optionDefinitionCount: 1,
      updated: true,
    );
  }
}

void main() {
  test('dashboard refresh goes through the catalog sync service', () async {
    final service = _FakeCatalogSyncService();
    final gateway = CatalogStoreMasterGateway(service);

    final result = await gateway.refreshFromMaster();

    expect(service.refreshCalls, 1);
    expect(service.forceSeen, false);
    expect(result.catalogVersion, 'master-2');
  });
}
