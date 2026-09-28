import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kiosk catalog loads local catalog before cloud synchronization', () {
    final source = File(
      'lib/features/kiosk/data/kiosk_catalog_data.dart',
    ).readAsStringSync();

    final localLoad = source.indexOf('final catalog = await _repository.load();');
    final backgroundSync = source.indexOf(
      'unawaited(_storeCatalogSync.refreshIfMasterChanged());',
    );

    expect(localLoad, greaterThanOrEqualTo(0));
    expect(backgroundSync, greaterThan(localLoad));
    expect(source, contains("import 'dart:async';"));
  });
}
