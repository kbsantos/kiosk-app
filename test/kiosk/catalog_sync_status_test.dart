import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/catalog/catalog_sync_status.dart';

void main() {
  group('CatalogSyncStatusResolver', () {
    test('reports master unavailable when the status check cannot reach master', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: false,
        masterExists: false,
        localVersion: 'db-v1',
        masterVersion: null,
        catalogsMatch: false,
      );

      expect(result.status, CatalogSyncStatus.masterUnavailable);
    });

    test('reports master not initialized when no master exists', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: true,
        masterExists: false,
        localVersion: null,
        masterVersion: null,
        catalogsMatch: false,
      );

      expect(result.status, CatalogSyncStatus.masterNotInitialized);
    });

    test('reports not linked when master exists without a local version', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: true,
        masterExists: true,
        localVersion: null,
        masterVersion: 'db-v2',
        catalogsMatch: false,
      );

      expect(result.status, CatalogSyncStatus.notLinked);
    });

    test('reports in sync when versions and catalog contents match', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: true,
        masterExists: true,
        localVersion: 'db-v2',
        masterVersion: 'db-v2',
        catalogsMatch: true,
      );

      expect(result.status, CatalogSyncStatus.inSync);
    });

    test('reports local changes pending when version matches but contents differ', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: true,
        masterExists: true,
        localVersion: 'db-v2',
        masterVersion: 'db-v2',
        catalogsMatch: false,
      );

      expect(result.status, CatalogSyncStatus.localChangesPending);
    });

    test('reports master changed when synchronized version no longer matches', () {
      final result = CatalogSyncStatusResolver.resolve(
        masterAvailable: true,
        masterExists: true,
        localVersion: 'db-v1',
        masterVersion: 'db-v2',
        catalogsMatch: false,
      );

      expect(result.status, CatalogSyncStatus.masterChanged);
    });
  });
}

