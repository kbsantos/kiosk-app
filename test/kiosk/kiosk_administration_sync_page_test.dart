import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bigger_brew_kiosk/features/catalog/catalog_sync_status.dart';
import 'package:bigger_brew_kiosk/features/catalog/store_catalog_sync_service.dart';
import 'package:bigger_brew_kiosk/features/kiosk/administration/kiosk_administration_sync_page.dart';

class _FakeCatalogSyncService extends StoreCatalogSyncService {
  _FakeCatalogSyncService(this.snapshot) : super();

  final CatalogSyncStatusSnapshot snapshot;

  @override
  Future<CatalogSyncStatusSnapshot> loadCatalogSyncStatus() async => snapshot;

  @override
  Future<bool> masterCatalogExists() async => true;
}

void main() {
  testWidgets('administration sync page shows current catalog status', (tester) async {
    final service = _FakeCatalogSyncService(
      const CatalogSyncStatusSnapshot(
        status: CatalogSyncStatus.localChangesPending,
        localVersion: 'db-v2',
        masterVersion: 'db-v2',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: KioskAdministrationSyncPage(catalogSyncService: service),
      ),
    );
    await tester.pump();

    expect(find.text('LOCAL CHANGES PENDING'), findsOneWidget);
    expect(find.text('Kiosk version: db-v2'), findsOneWidget);
    expect(find.text('Master version: db-v2'), findsOneWidget);
    expect(
      find.textContaining('local catalog content has changed'),
      findsOneWidget,
    );
  });
}
