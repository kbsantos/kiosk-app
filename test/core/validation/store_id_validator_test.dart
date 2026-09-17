import 'package:bigger_brew_kiosk/core/validation/store_id_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validId = '716d49cc-6a6d-4ad9-9b20-4b581f87987e';

  test('accepts the configured Store ID', () {
    expect(StoreIdValidator.isValid(validId), isTrue);
  });

  test('removes invisible Unicode characters', () {
    expect(
      StoreIdValidator.isValid('716d49cc-\u200b6a6d-4ad9-9b20-4b581f87987e'),
      isTrue,
    );
  });

  test('normalizes common Unicode dashes', () {
    expect(
      StoreIdValidator.isValid('716d49cc–6a6d-4ad9-9b20-4b581f87987e'),
      isTrue,
    );
  });

  test('rejects malformed Store IDs', () {
    expect(StoreIdValidator.isValid('716d49cc-6a6d-4ad9-9b20'), isFalse);
    expect(StoreIdValidator.isValid('not-a-uuid'), isFalse);
  });
}
