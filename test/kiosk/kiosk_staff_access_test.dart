import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_staff_access_repository.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_staff_gate.dart';

void main() {
  test('fresh kiosk uses the documented default staff PIN', () {
    expect(KioskStaffAccessRepository.defaultPin, '1234');
  });

  test('staff session lasts 30 minutes and starts locked', () {
    KioskStaffGate.endSession();
    expect(KioskStaffGate.isSessionActive, isFalse);
    expect(KioskStaffGate.sessionDuration, const Duration(minutes: 30));
  });
}
