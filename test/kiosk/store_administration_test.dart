import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/store_management/store_administration.dart';

void main() {
  group('K34 store administration', () {
    test('normalizes and validates a store draft', () {
      const draft = StoreAdministrationDraft(
        name: '  Main Store  ',
        code: '  BB-MAIN ',
        address: '  Tarlac  ',
        active: true,
      );
      final normalized = draft.normalized();
      expect(normalized.name, 'Main Store');
      expect(normalized.code, 'BB-MAIN');
      expect(normalized.address, 'Tarlac');
      expect(() => normalized.validate(), returnsNormally);
    });

    test('requires store name and code', () {
      const draft = StoreAdministrationDraft(
        name: '',
        code: '',
        address: '',
        active: true,
      );
      expect(() => draft.validate(), throwsArgumentError);
    });

    test('same store identity cannot be assigned to a different store', () {
      const a = StoreAdministrationRecord(
        id: '1', name: 'Main', code: 'BB-MAIN', address: '', active: true,
      );
      const b = StoreAdministrationRecord(
        id: '2', name: 'Second', code: 'BB-SECOND', address: '', active: true,
      );
      expect(StoreAdministrationRules.hasIdentityConflict(a, b), isFalse);
      expect(
        StoreAdministrationRules.hasIdentityConflict(
          a,
          const StoreAdministrationRecord(
            id: '2', name: 'Second', code: 'BB-MAIN', address: '', active: true,
          ),
        ),
        isTrue,
      );
    });

    test('cannot deactivate a store that still has active devices', () {
      expect(
        StoreAdministrationRules.canDeactivate(
          activeDeviceCount: 1,
          requestedActive: false,
        ),
        isFalse,
      );
      expect(
        StoreAdministrationRules.canDeactivate(
          activeDeviceCount: 0,
          requestedActive: false,
        ),
        isTrue,
      );
    });
  });
}
