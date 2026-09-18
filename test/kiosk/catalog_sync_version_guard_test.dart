import 'package:bigger_brew_kiosk/features/catalog/catalog_sync_version_guard.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogSyncVersionGuard', () {
    test('returns the validated kiosk version when versions match', () {
      final version = CatalogSyncVersionGuard.ensureLocalMatchesMaster(
        localVersion: 'db-v1',
        masterVersion: 'db-v1',
      );

      expect(version, 'db-v1');
    });

    test('rejects publish when kiosk has no known master version', () {
      expect(
        () => CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: null,
          masterVersion: 'db-v1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('rejects publish when the store master changed', () {
      expect(
        () => CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: 'db-v1',
          masterVersion: 'db-v2',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Master version: db-v2'),
          ),
        ),
      );
    });

    test('rejects a missing master version', () {
      expect(
        () => CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: 'db-v1',
          masterVersion: null,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'returns a trimmed kiosk version when versions match with whitespace',
      () {
        final version = CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: '  db-v1  ',
          masterVersion: 'db-v1',
        );

        expect(version, 'db-v1');
      },
    );

    test('rejects a catalog payload version that differs from the master', () {
      expect(
        () => CatalogSyncVersionGuard.ensureCatalogVersionMatchesMaster(
          catalogVersion: 'db-v1',
          masterVersion: 'db-v2',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Catalog version: db-v1; master version: db-v2'),
          ),
        ),
      );
    });

    test(
      'returns the normalized master version for a matching catalog payload',
      () {
        final version =
            CatalogSyncVersionGuard.ensureCatalogVersionMatchesMaster(
          catalogVersion: '  db-v2  ',
          masterVersion: 'db-v2',
        );

        expect(version, 'db-v2');
      },
    );

    test('applies the authoritative master version to a catalog snapshot', () {
      final catalog = ProductCatalog(
        catalogVersion: 'local-version',
        categories: const [],
        products: const [],
      );

      final accepted = CatalogSyncVersionGuard.withAuthoritativeVersion(
        catalog,
        'db-v3',
      );

      expect(accepted.catalogVersion, 'db-v3');
      expect(accepted.categories, isEmpty);
      expect(accepted.products, isEmpty);
    });

    test('rejects an empty master version', () {
      expect(
        () => CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: 'db-v1',
          masterVersion: ' ',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
