import 'package:flutter_test/flutter_test.dart';
import 'package:bigger_brew_kiosk/features/reporting_sync/kiosk_device_reprovisioning.dart';

void main() {
  test('cannot start reprovisioning until target identity is verified', () {
    final plan = KioskDeviceReprovisionPlan(
      currentStoreId: 'store-a',
      currentDeviceCode: 'KIOSK-01',
      targetStoreId: 'store-a',
      targetDeviceCode: 'KIOSK-02',
    );

    expect(plan.canApply(KioskDeviceRecoveryState.notFound), isFalse);
    expect(plan.canApply(KioskDeviceRecoveryState.inactive), isFalse);
    expect(plan.canApply(KioskDeviceRecoveryState.verified), isTrue);
  });

  test('same device is not treated as a replacement', () {
    final plan = KioskDeviceReprovisionPlan(
      currentStoreId: 'store-a',
      currentDeviceCode: 'KIOSK-01',
      targetStoreId: 'store-a',
      targetDeviceCode: 'KIOSK-01',
    );

    expect(plan.isReplacement, isFalse);
  });

  test('replacement target must be non-empty and normalized', () {
    final plan = KioskDeviceReprovisionPlan(
      currentStoreId: ' store-a ',
      currentDeviceCode: ' KIOSK-01 ',
      targetStoreId: ' store-b ',
      targetDeviceCode: ' KIOSK-02 ',
    );

    expect(plan.normalizedTargetStoreId, 'store-b');
    expect(plan.normalizedTargetDeviceCode, 'KIOSK-02');
    expect(plan.isReplacement, isTrue);
  });
}
