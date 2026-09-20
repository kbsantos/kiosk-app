import 'package:bigger_brew_kiosk/features/catalog/catalog_sync_version_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CatalogSyncVersionGuard', () {
    test('allows publish when kiosk and master versions match', () {
      expect(
        () => CatalogSyncVersionGuard.ensureLocalMatchesMaster(
          localVersion: 'db-v1',
          masterVersion: 'db-v1',
        ),
        returnsNormally,
      );
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
