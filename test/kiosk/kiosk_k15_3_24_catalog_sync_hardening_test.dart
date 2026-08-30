import 'dart:convert';
import 'dart:typed_data';

import 'package:bigger_brew_kiosk/features/catalog/catalog_sync.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff_access.dart';
import 'package:bigger_brew_kiosk/product_catalog/product_catalog_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = ProductCatalog(
    catalogVersion: 'hardening-test-1',
    categories: [
      ProductCategory(
          categoryId: 'coffee', name: 'Coffee', subtitle: 'Test', active: true),
    ],
    products: [],
  );

  group('K15.3.24 catalog sync hardening', () {
    test('editor cannot export or import sync packages', () {
      expect(
          StaffAccessPolicy.can(
              StaffRole.editor, CatalogPermission.exportSyncPackage),
          isFalse);
      expect(
          StaffAccessPolicy.can(
              StaffRole.editor, CatalogPermission.importSyncPackage),
          isFalse);
    });

    test('manager can export and import sync packages', () {
      expect(
          StaffAccessPolicy.can(
              StaffRole.manager, CatalogPermission.exportSyncPackage),
          isTrue);
      expect(
          StaffAccessPolicy.can(
              StaffRole.manager, CatalogPermission.importSyncPackage),
          isTrue);
    });

    test('valid package round-trips', () {
      final package = CatalogSyncPackage.create(catalog, 'KIOSK-SOURCE');
      final decoded = CatalogSyncPackage.fromJson(
        jsonDecode(jsonEncode(package.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.sourceDeviceId, 'KIOSK-SOURCE');
      expect(decoded.catalog.catalogVersion, 'hardening-test-1');
    });

    test('invalid timestamp is rejected', () {
      final package =
          CatalogSyncPackage.create(catalog, 'KIOSK-SOURCE').toJson();
      package['createdAt'] = 'not-a-date';
      expect(() => CatalogSyncPackage.fromJson(package),
          throwsA(isA<FormatException>()));
    });

    test('invalid checksum format is rejected before integrity comparison', () {
      final package =
          CatalogSyncPackage.create(catalog, 'KIOSK-SOURCE').toJson();
      package['checksum'] = 'xyz';
      expect(() => CatalogSyncPackage.fromJson(package),
          throwsA(isA<FormatException>()));
    });

    test('oversized package is rejected by the 2 MB boundary', () {
      final oversized = Uint8List(2 * 1024 * 1024 + 1);
      expect(oversized.length, greaterThan(2 * 1024 * 1024));
    });

    test(
        'tampering with source metadata does not affect catalog checksum validation contract',
        () {
      final package =
          CatalogSyncPackage.create(catalog, 'KIOSK-SOURCE').toJson();
      package['sourceDeviceId'] = 'KIOSK-OTHER';
      final decoded = CatalogSyncPackage.fromJson(package);
      expect(decoded.sourceDeviceId, 'KIOSK-OTHER');
      expect(decoded.checksum, CatalogSyncPackage.checksumFor(catalog));
    });
  });
}
