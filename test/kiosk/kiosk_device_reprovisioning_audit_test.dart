import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/kiosk_device_reprovisioning_audit.dart';

void main() {
  test('re-provision audit entry round-trips through JSON', () {
    final original = KioskDeviceReprovisioningAuditEntry(
      createdAt: DateTime(2026, 9, 19, 11, 30),
      previousStoreId: 'store-a',
      previousDeviceCode: 'KIOSK-01',
      targetStoreId: 'store-a',
      targetDeviceCode: 'KIOSK-02',
      catalogRefreshed: true,
    );

    final restored = KioskDeviceReprovisioningAuditEntry.fromJson(
      original.toJson(),
    );

    expect(restored.createdAt, original.createdAt);
    expect(restored.previousDeviceCode, 'KIOSK-01');
    expect(restored.targetDeviceCode, 'KIOSK-02');
    expect(restored.catalogRefreshed, isTrue);
  });
}
