import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/kiosk_device_lifecycle.dart';

void main() {
  test('active device is ACTIVE', () {
    final status = KioskDeviceLifecycleStatus.fromResponse(
      storeId: 'store-a',
      deviceCode: 'KIOSK-01',
      response: const {
        'found': true,
        'deviceId': 'uuid-1',
        'isActive': true,
      },
    );

    expect(status.state, KioskDeviceLifecycleState.active);
    expect(status.isOperational, isTrue);
    expect(status.deviceUuid, 'uuid-1');
  });

  test('inactive device is INACTIVE and cannot operate', () {
    final status = KioskDeviceLifecycleStatus.fromResponse(
      storeId: 'store-a',
      deviceCode: 'KIOSK-01',
      response: const {
        'found': true,
        'deviceId': 'uuid-1',
        'isActive': false,
      },
    );

    expect(status.state, KioskDeviceLifecycleState.inactive);
    expect(status.isOperational, isFalse);
  });

  test('unavailable device status is not treated as inactive', () {
    final status = KioskDeviceLifecycleStatus(
      state: KioskDeviceLifecycleState.unavailable,
      storeId: 'store-a',
      deviceCode: 'KIOSK-01',
    );

    expect(status.isOperational, isFalse);
    expect(status.title, 'DEVICE STATUS UNAVAILABLE');
  });

  test('missing device is NOT REGISTERED', () {
    final status = KioskDeviceLifecycleStatus.fromResponse(
      storeId: 'store-a',
      deviceCode: 'KIOSK-99',
      response: null,
    );

    expect(status.state, KioskDeviceLifecycleState.notFound);
    expect(status.isOperational, isFalse);
  });

  test('lifecycle audit event round-trips through JSON', () {
    final original = KioskDeviceLifecycleAuditEntry(
      createdAt: DateTime(2026, 9, 19, 12, 30),
      storeId: 'store-a',
      deviceCode: 'KIOSK-01',
      state: KioskDeviceLifecycleState.active,
      deviceUuid: 'uuid-1',
    );

    final restored = KioskDeviceLifecycleAuditEntry.fromJson(original.toJson());

    expect(restored.createdAt, original.createdAt);
    expect(restored.storeId, 'store-a');
    expect(restored.deviceCode, 'KIOSK-01');
    expect(restored.state, KioskDeviceLifecycleState.active);
    expect(restored.deviceUuid, 'uuid-1');
  });
}
