import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/kiosk_device_recovery.dart';

void main() {
  test('missing device is not considered verified', () {
    final status = KioskDeviceRecoveryStatus.fromResponse(
      storeId: 'store',
      deviceCode: 'KIOSK-01',
      response: null,
    );

    expect(status.state, KioskDeviceRecoveryState.notFound);
    expect(status.isVerified, isFalse);
  });

  test('inactive device blocks recovery', () {
    final status = KioskDeviceRecoveryStatus.fromResponse(
      storeId: 'store',
      deviceCode: 'KIOSK-01',
      response: {
        'found': true,
        'deviceId': 'device-uuid',
        'isActive': false,
      },
    );

    expect(status.state, KioskDeviceRecoveryState.inactive);
    expect(status.isVerified, isFalse);
  });

  test('active registered device is verified', () {
    final status = KioskDeviceRecoveryStatus.fromResponse(
      storeId: 'store',
      deviceCode: 'KIOSK-01',
      response: {
        'found': true,
        'deviceId': 'device-uuid',
        'isActive': true,
      },
    );

    expect(status.state, KioskDeviceRecoveryState.verified);
    expect(status.deviceUuid, 'device-uuid');
    expect(status.isVerified, isTrue);
  });
}
