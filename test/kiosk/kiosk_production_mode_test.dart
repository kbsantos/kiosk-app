import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/kiosk/staff/kiosk_staff_gate.dart';

void main() {
  test('production kiosk staff session is locked after explicit exit', () {
    KioskStaffGate.endSession();
    expect(KioskStaffGate.isSessionActive, isFalse);
  });

  test('production kiosk staff session duration remains 30 minutes', () {
    expect(
      KioskStaffGate.sessionDuration,
      const Duration(minutes: 30),
    );
  });
}
